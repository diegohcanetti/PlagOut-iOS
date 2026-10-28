import Foundation
import Testing
@testable import PlagOutCore

/// Respuestas armadas a mano para el cliente: se registran por prueba y se consumen en orden.
final class ProtocoloFalso: URLProtocol, @unchecked Sendable {
    struct Respuesta {
        let codigo: Int
        let cuerpo: String
        var cabeceras: [String: String] = [:]
    }

    nonisolated(unsafe) static var respuestas: [Respuesta] = []
    nonisolated(unsafe) static var pedidos: [URLRequest] = []
    static let cerrojo = NSLock()

    static func preparar(_ respuestas: [Respuesta]) {
        cerrojo.withLock {
            self.respuestas = respuestas
            pedidos = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let respuesta: Respuesta? = Self.cerrojo.withLock {
            var pedido = request
            // URLSession pasa el cuerpo como stream: se copia para poder revisarlo.
            if pedido.httpBody == nil, let stream = request.httpBodyStream {
                stream.open()
                var datos = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let leidos = stream.read(&buffer, maxLength: buffer.count)
                    if leidos <= 0 { break }
                    datos.append(buffer, count: leidos)
                }
                stream.close()
                pedido.httpBody = datos
            }
            Self.pedidos.append(pedido)
            return Self.respuestas.isEmpty ? nil : Self.respuestas.removeFirst()
        }
        guard let respuesta else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let http = HTTPURLResponse(url: request.url!, statusCode: respuesta.codigo, httpVersion: nil, headerFields: respuesta.cabeceras)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(respuesta.cuerpo.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

actor SesionFalsa: ProveedorDeSesion {
    var token: String?
    var renovado: String?
    var renovaciones = 0

    init(token: String?, renovado: String? = nil) {
        self.token = token
        self.renovado = renovado
    }

    func tokenDeAcceso() -> String? { token }

    func renovarSesion() -> Bool {
        renovaciones += 1
        guard let renovado else { return false }
        token = renovado
        return true
    }
}

final class Eventos: @unchecked Sendable {
    private let cerrojo = NSLock()
    private var lista: [EventoSesion] = []
    var todos: [EventoSesion] { cerrojo.withLock { lista } }
    func anotar(_ evento: EventoSesion) { cerrojo.withLock { lista.append(evento) } }
}

// Las pruebas comparten el protocolo falso: van en serie.
@Suite(.serialized)
struct RedTests {
    func api(_ sesion: SesionFalsa, eventos: Eventos = Eventos()) -> PlagOutAPI {
        let configuracion = URLSessionConfiguration.ephemeral
        configuracion.protocolClasses = [ProtocoloFalso.self]
        let cliente = APIClient(
            base: URL(string: "https://backend.test")!,
            proveedor: sesion,
            sesion: URLSession(configuration: configuracion),
            alEvento: { eventos.anotar($0) }
        )
        return PlagOutAPI(cliente: cliente)
    }

    @Test func mandaElTokenYLeeLaRespuesta() async throws {
        ProtocoloFalso.preparar([.init(codigo: 200, cuerpo: String(decoding: try fixture("usuario"), as: UTF8.self))])
        let usuario = try await api(SesionFalsa(token: "t1")).usuarioActual()
        #expect(usuario.nombre == "Ana")
        let pedido = try #require(ProtocoloFalso.pedidos.first)
        #expect(pedido.value(forHTTPHeaderField: "Authorization") == "Bearer t1")
        #expect(pedido.url?.absoluteString == "https://backend.test/usuarios/me")
    }

    @Test func un401RenuevaLaSesionUnaVezYReintenta() async throws {
        ProtocoloFalso.preparar([
            .init(codigo: 401, cuerpo: #"{"detail":"invalid_token"}"#),
            .init(codigo: 200, cuerpo: "[]"),
        ])
        let sesion = SesionFalsa(token: "viejo", renovado: "nuevo")
        let eventos = Eventos()
        #expect(try await api(sesion, eventos: eventos).notificaciones().isEmpty)
        #expect(await sesion.renovaciones == 1)
        #expect(ProtocoloFalso.pedidos.last?.value(forHTTPHeaderField: "Authorization") == "Bearer nuevo")
        #expect(eventos.todos.isEmpty)
    }

    @Test func siNoSePuedeRenovarAvisaQueLaSesionExpiro() async throws {
        ProtocoloFalso.preparar([.init(codigo: 401, cuerpo: "{}")])
        let eventos = Eventos()
        let error = await #expect(throws: ErrorBackend.self) {
            try await api(SesionFalsa(token: "viejo"), eventos: eventos).notificaciones()
        }
        #expect(error?.mensaje == ErrorBackend.mensajeSesionExpirada)
        #expect(eventos.todos == [.expirada])
    }

    @Test func sinTokenUn401NoIntentaRenovar() async throws {
        ProtocoloFalso.preparar([.init(codigo: 401, cuerpo: "{}")])
        let sesion = SesionFalsa(token: nil, renovado: "nuevo")
        let eventos = Eventos()
        _ = await #expect(throws: ErrorBackend.self) { try await api(sesion, eventos: eventos).usuarioActual() }
        #expect(await sesion.renovaciones == 0)
        #expect(eventos.todos.isEmpty)
    }

    @Test func cuentaSuspendida() async throws {
        ProtocoloFalso.preparar([.init(codigo: 403, cuerpo: #"{"detail":"cuenta_suspendida"}"#)])
        let eventos = Eventos()
        let error = await #expect(throws: ErrorBackend.self) { try await api(SesionFalsa(token: "t"), eventos: eventos).monitoreos() }
        #expect(error?.mensaje == ErrorBackend.mensajeCuentaSuspendida)
        #expect(eventos.todos == [.cuentaSuspendida])
    }

    @Test func sinConexion() async throws {
        ProtocoloFalso.preparar([])
        let error = await #expect(throws: ErrorBackend.self) { try await api(SesionFalsa(token: "t")).terrenos() }
        #expect(error == .sinConexion)
    }

    @Test func traeTodasLasPaginasSinRepetidos() async throws {
        func pagina(_ ids: [Int], total: Int) -> ProtocoloFalso.Respuesta {
            let items = ids.map { #"{"id":\#($0),"terreno_nombre":"T\#($0)","terreno_latitud":-34,"terreno_longitud":-60,"terreno_area":1}"# }
            return .init(codigo: 200, cuerpo: #"{"items":[\#(items.joined(separator: ","))],"total":\#(total)}"#)
        }
        ProtocoloFalso.preparar([pagina(Array(1...20), total: 25), pagina([20, 21, 22, 23, 24], total: 25)])
        let terrenos = try await api(SesionFalsa(token: "t")).terrenos()
        #expect(terrenos.map(\.id) == Array(1...24))
        let consultas = ProtocoloFalso.pedidos.map { $0.url!.query! }
        #expect(consultas == ["limit=20&offset=0", "limit=100&offset=20"])
    }

    @Test func elPatchDeTratamientoLlevaLosNull() async throws {
        let tratamiento = String(decoding: try fixture("tratamientos"), as: UTF8.self)
        let primero = String(tratamiento.drop(while: { $0 != "{" }).prefix(while: { $0 != "}" })) + "}"
        ProtocoloFalso.preparar([.init(codigo: 200, cuerpo: primero)])
        _ = try await api(SesionFalsa(token: "t")).actualizarTratamiento(id: 7, cambios: ["conteo_despues": .nulo])
        let pedido = try #require(ProtocoloFalso.pedidos.first)
        #expect(pedido.httpMethod == "PATCH")
        #expect(String(decoding: pedido.httpBody ?? Data(), as: UTF8.self) == #"{"conteo_despues":null}"#)
    }

    @Test func elMapaPideCeldaEnLosDosNiveles() async throws {
        ProtocoloFalso.preparar([.init(codigo: 200, cuerpo: String(decoding: try fixture("mapa_reportes"), as: UTF8.self))])
        let area = PlagOutAPI.AreaMapa(sur: -40, oeste: -66, norte: -28, este: -56)
        _ = try await api(SesionFalsa(token: "t")).reportesMapa(area: area, zoom: 9, nivel: "reportes")
        let consulta = try #require(ProtocoloFalso.pedidos.first?.url?.query)
        #expect(consulta.contains("celda_grados=0.17578125"))
        #expect(consulta.contains("limite=500"))
    }
}

struct ErrorBackendTests {
    @Test func traduceElDetallePorPantalla() {
        let error = ErrorBackend.deRespuesta(codigo: 400, cuerpo: Data(#"{"detail":"report pest not compatible"}"#.utf8), porDetalle: Errores.reporte)
        #expect(error.mensaje == "La plaga no afecta a este cultivo.")
    }

    @Test func losErroresDeValidacionVanPorCampo() throws {
        let error = ErrorBackend.deRespuesta(codigo: 422, cuerpo: try fixture("error_422"))
        #expect(error.mensaje == "La fecha de siembra no puede ser futura.")
        #expect(error.campos["area_hectareas"] == "Revisá las hectáreas: está fuera del rango permitido.")
    }

    @Test func mensajesPorCodigo() {
        #expect(ErrorBackend.deRespuesta(codigo: 429, cuerpo: Data(#"{"error":"Rate limit"}"#.utf8), retryAfterSegundos: 30).mensaje
            == "Demasiados intentos, probá de nuevo en 30 segundos.")
        #expect(ErrorBackend.deRespuesta(codigo: 404, cuerpo: Data()).mensaje == "No encontramos lo que buscabas. Puede que ya no exista.")
        #expect(ErrorBackend.deRespuesta(codigo: 500, cuerpo: Data("<html>".utf8)).mensaje == ErrorBackend.mensajeGenerico)
        #expect(ErrorBackend.deRespuesta(codigo: 500, cuerpo: Data(), porCodigo: Errores.archivarCicloPorCodigo).mensaje
            == "No se pudo finalizar el ciclo. Intentá de nuevo.")
    }
}

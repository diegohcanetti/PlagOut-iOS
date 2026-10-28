import Foundation

/// La sesión de Supabase vista desde la red. La implementa la app con `supabase-swift`; los
/// tests usan una falsa.
public protocol ProveedorDeSesion: Sendable {
    /// El access token vigente, o nil sin sesión. El SDK lo renueva solo antes de que venza.
    func tokenDeAcceso() async -> String?
    /// Fuerza una renovación; false si la sesión ya no sirve.
    func renovarSesion() async -> Bool
}

/// Lo que la app tiene que resolver fuera de la pantalla que hizo el pedido.
public enum EventoSesion: Sendable, Equatable {
    /// 401 que no se arregla renovando: hay que volver al login.
    case expirada
    /// 403 `cuenta_suspendida`.
    case cuentaSuspendida
}

public enum MetodoHTTP: String, Sendable {
    case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE"
}

public struct Solicitud: Sendable {
    public var metodo: MetodoHTTP
    public var ruta: String
    public var consulta: [URLQueryItem]
    public var cuerpo: Data?

    public init(_ metodo: MetodoHTTP, _ ruta: String, consulta: [String: CustomStringConvertible?] = [:], cuerpo: Data? = nil) {
        self.metodo = metodo
        self.ruta = ruta
        // Orden fijo: los tests comparan URLs y el backend no distingue.
        self.consulta = consulta.keys.sorted().compactMap { clave in
            consulta[clave]!.map { URLQueryItem(name: clave, value: $0.description) }
        }
        self.cuerpo = cuerpo
    }
}

public enum JSON {
    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    /// Un cuerpo con null explícitos, para los PATCH que "deshacen" un campo.
    public static func conNulos(_ campos: [String: ValorJSON]) -> Data {
        let objeto = campos.mapValues(\.comoObjeto)
        return try! JSONSerialization.data(withJSONObject: objeto, options: [.sortedKeys])
    }
}

public enum ValorJSON: Equatable, Sendable {
    case texto(String)
    case numero(Double)
    case booleano(Bool)
    case nulo

    var comoObjeto: Any {
        switch self {
        case .texto(let t): t
        case .numero(let n): n
        case .booleano(let b): b
        case .nulo: NSNull()
        }
    }
}

public final class APIClient: Sendable {
    public let base: URL
    private let sesion: URLSession
    private let proveedor: ProveedorDeSesion
    private let alEvento: @Sendable (EventoSesion) -> Void

    public init(
        base: URL,
        proveedor: ProveedorDeSesion,
        sesion: URLSession = .shared,
        alEvento: @escaping @Sendable (EventoSesion) -> Void = { _ in }
    ) {
        self.base = base
        self.proveedor = proveedor
        self.sesion = sesion
        self.alEvento = alEvento
    }

    /// Pide y decodifica. Cualquier falla sale como `ErrorBackend` con el mensaje para mostrar.
    public func pedir<T: Decodable>(
        _ solicitud: Solicitud,
        como: T.Type = T.self,
        porDetalle: [String: String] = [:],
        porCodigo: [Int: String] = [:]
    ) async throws(ErrorBackend) -> T {
        let datos = try await enviar(solicitud, porDetalle: porDetalle, porCodigo: porCodigo)
        do {
            return try JSON.decoder.decode(T.self, from: datos)
        } catch {
            throw ErrorBackend.generico
        }
    }

    /// Para los pedidos cuya respuesta no interesa (borrados).
    public func ejecutar(
        _ solicitud: Solicitud,
        porDetalle: [String: String] = [:],
        porCodigo: [Int: String] = [:]
    ) async throws(ErrorBackend) {
        _ = try await enviar(solicitud, porDetalle: porDetalle, porCodigo: porCodigo)
    }

    func enviar(_ solicitud: Solicitud, porDetalle: [String: String], porCodigo: [Int: String]) async throws(ErrorBackend) -> Data {
        var token = await proveedor.tokenDeAcceso()
        var (datos, respuesta) = try await intentar(solicitud, token: token)

        // Sin token el 401 es esperable (no hay sesión): no hay nada que renovar.
        if respuesta.statusCode == 401, token != nil {
            if await proveedor.renovarSesion() {
                token = await proveedor.tokenDeAcceso()
                (datos, respuesta) = try await intentar(solicitud, token: token)
            }
            if respuesta.statusCode == 401 { alEvento(.expirada) }
        }
        if (200..<300).contains(respuesta.statusCode) { return datos }

        let error = ErrorBackend.deRespuesta(
            codigo: respuesta.statusCode,
            cuerpo: datos,
            retryAfterSegundos: respuesta.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) },
            porDetalle: porDetalle,
            porCodigo: porCodigo
        )
        if respuesta.statusCode == 403, error.detalle == ErrorBackend.detalleCuentaSuspendida {
            alEvento(.cuentaSuspendida)
        }
        throw error
    }

    private func intentar(_ solicitud: Solicitud, token: String?) async throws(ErrorBackend) -> (Data, HTTPURLResponse) {
        var componentes = URLComponents(url: base.appending(path: solicitud.ruta), resolvingAgainstBaseURL: false)!
        if !solicitud.consulta.isEmpty { componentes.queryItems = solicitud.consulta }
        var pedido = URLRequest(url: componentes.url!, timeoutInterval: 30)
        pedido.httpMethod = solicitud.metodo.rawValue
        pedido.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let cuerpo = solicitud.cuerpo {
            pedido.httpBody = cuerpo
            pedido.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        do {
            let (datos, respuesta) = try await sesion.data(for: pedido)
            guard let http = respuesta as? HTTPURLResponse else { throw ErrorBackend.generico }
            return (datos, http)
        } catch let error as ErrorBackend {
            throw error
        } catch is CancellationError {
            throw ErrorBackend(mensaje: ErrorBackend.mensajeGenerico, detalle: "cancelado")
        } catch {
            throw ErrorBackend.sinConexion
        }
    }
}

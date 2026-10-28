import Foundation

/// Los endpoints que usa el productor, con los mismos nombres de ruta que `GDDService.kt`.
public struct PlagOutAPI: Sendable {
    public let cliente: APIClient

    public init(cliente: APIClient) { self.cliente = cliente }

    /// Primera página corta para mostrar algo rápido; las siguientes, grandes (`Paginacion.kt`).
    static let paginaInicial = 20
    static let paginaSiguiente = 100
    /// Máximo que acepta el backend en los catálogos.
    static let paginaCatalogo = 100

    // MARK: Terrenos, plantaciones y catálogos

    public func terrenos() async throws(ErrorBackend) -> [Terreno] {
        try await todasLasPaginas("/terrenos")
    }

    public func crearTerreno(_ terreno: NuevoTerreno) async throws(ErrorBackend) -> Terreno {
        try await cliente.pedir(Solicitud(.post, "/terrenos", cuerpo: cuerpo(terreno)), como: TerrenoCreado.self).comoTerreno
    }

    public func actualizarTerreno(id: Int, _ cambios: CambiosTerreno) async throws(ErrorBackend) -> Terreno {
        try await cliente.pedir(Solicitud(.patch, "/terrenos/\(id)", cuerpo: cuerpo(cambios)))
    }

    public func eliminarTerreno(id: Int) async throws(ErrorBackend) {
        try await cliente.ejecutar(Solicitud(.delete, "/terrenos/\(id)"))
    }

    public func plantaciones() async throws(ErrorBackend) -> [Plantacion] {
        try await todasLasPaginas("/plantaciones")
    }

    public func crearPlantacion(_ plantacion: NuevaPlantacion) async throws(ErrorBackend) -> PlantacionCreada {
        try await cliente.pedir(Solicitud(.post, "/plantaciones", cuerpo: cuerpo(plantacion)))
    }

    public func actualizarPlantacion(id: Int, _ cambios: CambiosPlantacion) async throws(ErrorBackend) -> Plantacion {
        try await cliente.pedir(Solicitud(.patch, "/plantaciones/\(id)", cuerpo: cuerpo(cambios)))
    }

    public func eliminarPlantacion(id: Int) async throws(ErrorBackend) {
        try await cliente.ejecutar(Solicitud(.delete, "/plantaciones/\(id)"))
    }

    public func cultivos() async throws(ErrorBackend) -> [Cultivo] { try await catalogo("/cultivos") }
    public func plagas() async throws(ErrorBackend) -> [Plaga] { try await catalogo("/plagas") }
    public func cargos() async throws(ErrorBackend) -> [Cargo] { try await catalogo("/cargos") }

    // MARK: Monitoreos, ciclos, biofix y tratamientos

    public func monitoreos() async throws(ErrorBackend) -> [Monitoreo] {
        try await todasLasPaginas("/monitoreos")
    }

    public func monitoreo(id: Int) async throws(ErrorBackend) -> Monitoreo {
        try await cliente.pedir(Solicitud(.get, "/monitoreos/\(id)"))
    }

    public func crearMonitoreo(_ monitoreo: NuevoMonitoreo, porDetalle: [String: String] = [:]) async throws(ErrorBackend) -> Monitoreo {
        try await cliente.pedir(Solicitud(.post, "/monitoreos", cuerpo: cuerpo(monitoreo)), porDetalle: porDetalle)
    }

    public func actualizarMonitoreo(id: Int, _ cambios: CambiosMonitoreo) async throws(ErrorBackend) -> Monitoreo {
        try await cliente.pedir(Solicitud(.patch, "/monitoreos/\(id)", cuerpo: cuerpo(cambios)))
    }

    public func eliminarMonitoreo(id: Int) async throws(ErrorBackend) {
        try await cliente.ejecutar(Solicitud(.delete, "/monitoreos/\(id)"))
    }

    public func registrarBiofix(monitoreoId: Int, _ biofix: SolicitudBiofix, porDetalle: [String: String] = [:]) async throws(ErrorBackend) -> ResultadoBiofix {
        try await cliente.pedir(Solicitud(.post, "/monitoreos/\(monitoreoId)/observaciones", cuerpo: cuerpo(biofix)), porDetalle: porDetalle)
    }

    public func ciclo(id: Int) async throws(ErrorBackend) -> CicloGDD {
        try await cliente.pedir(Solicitud(.get, "/ciclos/\(id)"))
    }

    public func archivarCiclo(id: Int) async throws(ErrorBackend) -> CicloGDD {
        try await cliente.pedir(
            Solicitud(.post, "/ciclos/\(id)/archivar"),
            porDetalle: Errores.archivarCiclo,
            porCodigo: Errores.archivarCicloPorCodigo
        )
    }

    public func tratamientos(monitoreoId: Int) async throws(ErrorBackend) -> [Tratamiento] {
        try await cliente.pedir(Solicitud(.get, "/monitoreos/\(monitoreoId)/tratamientos"), porDetalle: Errores.tratamiento)
    }

    public func registrarTratamiento(monitoreoId: Int, _ tratamiento: SolicitudTratamiento) async throws(ErrorBackend) -> Tratamiento {
        try await cliente.pedir(
            Solicitud(.post, "/monitoreos/\(monitoreoId)/tratamientos", cuerpo: cuerpo(tratamiento)),
            porDetalle: Errores.tratamiento
        )
    }

    /// `cambios` lleva solo lo que cambió, con null explícito para deshacer un campo.
    public func actualizarTratamiento(id: Int, cambios: [String: ValorJSON]) async throws(ErrorBackend) -> Tratamiento {
        try await cliente.pedir(Solicitud(.patch, "/tratamientos/\(id)", cuerpo: JSON.conNulos(cambios)), porDetalle: Errores.tratamiento)
    }

    public func eliminarTratamiento(id: Int) async throws(ErrorBackend) {
        try await cliente.ejecutar(Solicitud(.delete, "/tratamientos/\(id)"), porDetalle: Errores.tratamiento)
    }

    public func prediccion(id: Int) async throws(ErrorBackend) -> Prediccion {
        try await cliente.pedir(Solicitud(.get, "/api/v1/predicciones/\(id)"))
    }

    public func confirmarPrediccion(id: Int, _ confirmacion: ConfirmacionPrediccion, porDetalle: [String: String] = [:]) async throws(ErrorBackend) -> PrediccionConfirmada {
        try await cliente.pedir(Solicitud(.post, "/api/v1/predicciones/\(id)/confirmacion", cuerpo: cuerpo(confirmacion)), porDetalle: porDetalle)
    }

    // MARK: Reportes

    public func crearReporte(_ reporte: NuevoReporte) async throws(ErrorBackend) -> ReporteCreado {
        try await cliente.pedir(Solicitud(.post, "/reportes", cuerpo: cuerpo(reporte)), porDetalle: Errores.reporte)
    }

    public func reporte(id: Int) async throws(ErrorBackend) -> Reporte {
        try await cliente.pedir(Solicitud(.get, "/reportes/\(id)"))
    }

    public func eliminarReporte(id: Int) async throws(ErrorBackend) {
        try await cliente.ejecutar(Solicitud(.delete, "/reportes/\(id)"))
    }

    public struct FiltroReportes: Sendable, Equatable {
        public var fechaDesde: DiaCalendario?
        public var fechaHasta: DiaCalendario?
        public var distanciaKm: Int?
        public var severidad: Severidad?
        public var terrenoId: Int?
        public var plagaId: Int?

        public init(fechaDesde: DiaCalendario? = nil, fechaHasta: DiaCalendario? = nil, distanciaKm: Int? = nil,
                    severidad: Severidad? = nil, terrenoId: Int? = nil, plagaId: Int? = nil) {
            self.fechaDesde = fechaDesde
            self.fechaHasta = fechaHasta
            self.distanciaKm = distanciaKm
            self.severidad = severidad
            self.terrenoId = terrenoId
            self.plagaId = plagaId
        }

        var consulta: [String: CustomStringConvertible?] {
            [
                "fecha_desde": fechaDesde, "fecha_hasta": fechaHasta, "distancia_km": distanciaKm,
                "severidad": severidad?.rawValue, "terreno_id": terrenoId, "plaga_id": plagaId,
            ]
        }
    }

    public func reportes(ambito: AmbitoReportes, filtro: FiltroReportes = .init(), limite: Int = 20, desde: Int = 0) async throws(ErrorBackend) -> Pagina<Reporte> {
        var consulta = filtro.consulta
        consulta["ambito"] = ambito.rawValue
        consulta["limit"] = limite
        consulta["offset"] = desde
        return try await cliente.pedir(Solicitud(.get, "/reportes", consulta: consulta))
    }

    public func resumenReportes(ambito: AmbitoReportes, filtro: FiltroReportes = .init()) async throws(ErrorBackend) -> ConteoReportes {
        var consulta = filtro.consulta
        consulta["ambito"] = ambito.rawValue
        return try await cliente.pedir(Solicitud(.get, "/reportes/resumen", consulta: consulta))
    }

    public struct AreaMapa: Sendable, Equatable {
        public let sur: Double, oeste: Double, norte: Double, este: Double

        public init(sur: Double, oeste: Double, norte: Double, este: Double) {
            self.sur = sur
            self.oeste = oeste
            self.norte = norte
            self.este = este
        }
    }

    /// Mapa de reportes. Con zoom lejano conviene pedir `grupos`; el backend exige `celda_grados`
    /// en los dos niveles (ver `celdaGrados(zoom:)`).
    public func reportesMapa(
        area: AreaMapa, zoom: Int, nivel: String, ambito: String? = nil,
        radioKm: Int? = nil, dias: Int? = nil, severidad: Severidad? = nil, plaga: String? = nil, cultivo: String? = nil
    ) async throws(ErrorBackend) -> ReportesMapa {
        let consulta: [String: CustomStringConvertible?] = [
            "sur": area.sur, "oeste": area.oeste, "norte": area.norte, "este": area.este,
            "zoom": zoom, "nivel": nivel, "celda_grados": Self.celdaGrados(zoom: zoom),
            "limite": nivel == "reportes" ? 500 : nil, "ambito": ambito, "radio_km": radioKm,
            "dias": dias, "severidad": severidad?.rawValue, "plaga": plaga, "cultivo": cultivo,
        ]
        return try await cliente.pedir(Solicitud(.get, "/mapa/reportes", consulta: consulta))
    }

    /// El lado de una celda de agrupamiento en grados para un zoom: unos 64 px de pantalla, como
    /// `celdaGradosParaZoom` de Android.
    public static func celdaGrados(zoom: Int, ladoPx: Double = 64) -> Double {
        360.0 / (256.0 * pow(2.0, Double(zoom))) * ladoPx
    }

    // MARK: Usuario y notificaciones

    public func usuarioActual() async throws(ErrorBackend) -> Usuario {
        try await cliente.pedir(Solicitud(.get, "/usuarios/me"))
    }

    public func crearUsuario(_ usuario: NuevoUsuario) async throws(ErrorBackend) -> UsuarioCreado {
        try await cliente.pedir(Solicitud(.post, "/usuarios", cuerpo: cuerpo(usuario)), porDetalle: Errores.perfil)
    }

    public func actualizarUsuario(_ cambios: CambiosUsuario) async throws(ErrorBackend) -> Usuario {
        try await cliente.pedir(Solicitud(.patch, "/usuarios/me", cuerpo: cuerpo(cambios)), porDetalle: Errores.perfil)
    }

    public func eliminarCuenta() async throws(ErrorBackend) -> BajaDeCuenta {
        try await cliente.pedir(Solicitud(.delete, "/usuarios/me"))
    }

    public func consentimientoModelo() async throws(ErrorBackend) -> ConsentimientoModelo {
        try await cliente.pedir(Solicitud(.get, "/api/v1/usuarios/me/consentimiento-modelo"))
    }

    public func actualizarConsentimientoModelo(_ cambio: CambioConsentimiento) async throws(ErrorBackend) -> ConsentimientoModelo {
        try await cliente.pedir(Solicitud(.patch, "/api/v1/usuarios/me/consentimiento-modelo", cuerpo: cuerpo(cambio)))
    }

    public func notificaciones() async throws(ErrorBackend) -> [Notificacion] {
        try await cliente.pedir(Solicitud(.get, "/notificaciones"))
    }

    public func marcarLeida(id: Int) async throws(ErrorBackend) -> NotificacionLeida {
        try await cliente.pedir(Solicitud(.patch, "/notificaciones/\(id)"))
    }

    // MARK: Paginación

    /// Todas las páginas de un listado `{"items", "total"}`, sin repetidos por id. Corta si una
    /// página llega vacía aunque `total` diga que faltan.
    func todasLasPaginas<T: Decodable & Sendable & Identifiable>(_ ruta: String) async throws(ErrorBackend) -> [T] where T.ID == Int {
        var recibidos: [Int: T] = [:]
        var orden: [Int] = []
        var desde = 0
        var limite = Self.paginaInicial
        while true {
            let pagina: Pagina<T> = try await cliente.pedir(Solicitud(.get, ruta, consulta: ["limit": limite, "offset": desde]))
            for item in pagina.items {
                if recibidos.updateValue(item, forKey: item.id) == nil { orden.append(item.id) }
            }
            desde += pagina.items.count
            if pagina.items.isEmpty || desde >= pagina.total { return orden.map { recibidos[$0]! } }
            limite = Self.paginaSiguiente
        }
    }

    /// Catálogo completo de un endpoint que pagina con una lista simple: una página corta es la última.
    func catalogo<T: Decodable & Sendable>(_ ruta: String) async throws(ErrorBackend) -> [T] {
        var items: [T] = []
        var desde = 0
        while true {
            let pagina: [T] = try await cliente.pedir(Solicitud(.get, ruta, consulta: ["limit": Self.paginaCatalogo, "offset": desde]))
            items += pagina
            if pagina.count < Self.paginaCatalogo { return items }
            desde += pagina.count
        }
    }

    private func cuerpo<T: Encodable>(_ valor: T) -> Data {
        // Los modelos de pedido son structs simples: si esto falla es un error de programación.
        try! JSON.encoder.encode(valor)
    }
}

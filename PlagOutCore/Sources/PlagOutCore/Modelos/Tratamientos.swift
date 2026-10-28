import Foundation

// Los conteos de la plaga antes y después de aplicar (backend docs/tratamientos.md). El testigo
// (franja sin tratar) es opcional: con él el backend calcula la eficacia de Henderson-Tilton;
// sin él, solo la reducción observada, que incluye la mortalidad natural.

public struct SolicitudTratamiento: Codable, Hashable, Sendable {
    public let idempotencyKey: String
    public let fechaAplicacion: DiaCalendario
    public let producto: String
    public let unidadConteo: String
    public let conteoAntes: Double
    public let fechaConteoAntes: DiaCalendario
    public let conteoDespues: Double?
    public let fechaConteoDespues: DiaCalendario?
    public let testigoAntes: Double?
    public let testigoDespues: Double?
}

public struct Tratamiento: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let monitoreoId: Int
    public let fechaAplicacion: DiaCalendario
    public let producto: String
    public let unidadConteo: String
    public let conteoAntes: Double
    public let fechaConteoAntes: DiaCalendario
    public let conteoDespues: Double?
    public let fechaConteoDespues: DiaCalendario?
    public let testigoAntes: Double?
    public let testigoDespues: Double?
    /// "henderson_tilton", "reduccion_observada" o nil.
    public let metodo: String?
    public let reduccionObservadaPct: Double?
    public let eficaciaPct: Double?
    /// Por qué falta la cifra preferida (falta_conteo_despues, conteo_antes_cero, …).
    public let sinCalculo: String?
    public let cita: String?
}

public enum UnidadConteo: String, Sendable, CaseIterable, Identifiable {
    case porMetroLineal = "por_metro_lineal"
    case porPlanta = "por_planta"
    case porGolpeRed = "por_golpe_red"
    case porTrampa = "por_trampa"

    public var id: String { rawValue }

    public var etiqueta: String {
        switch self {
        case .porMetroLineal: "por metro lineal"
        case .porPlanta: "por planta"
        case .porGolpeRed: "por golpe de red"
        case .porTrampa: "por trampa"
        }
    }
}

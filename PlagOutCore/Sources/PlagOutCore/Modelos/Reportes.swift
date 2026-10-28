import Foundation

public struct NuevoReporte: Encodable, Sendable {
    public let plantacionId: Int
    public let plagaId: Int
    public let nivelSeveridad: String
    public let timestampMs: Int64
    public let etapaBiologica: String?

    public init(plantacionId: Int, plagaId: Int, severidad: Severidad, observadoEn: Date, etapa: EtapaBiologica?) {
        self.plantacionId = plantacionId
        self.plagaId = plagaId
        self.nivelSeveridad = severidad.rawValue
        self.timestampMs = Int64((observadoEn.timeIntervalSince1970 * 1000).rounded())
        self.etapaBiologica = etapa?.rawValue
    }
}

public struct ReporteCreado: Decodable, Sendable {
    public let id: Int
    public let plantacionId: Int?
    public let plagaId: Int
    public let nivelSeveridad: String
    public let latitud: Double?
    public let longitud: Double?
    public let timestampMs: Int64
}

public struct Reporte: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let plantacionId: Int?
    public let plagaId: Int
    public let plagaNombre: String
    public let terrenoNombre: String?
    public let cultivoNombre: String?
    public let etapaBiologica: String?
    public let nivelSeveridad: String
    public let latitud: Double?
    public let longitud: Double?
    public let timestampMs: Int64
    public let creadoEn: String?
    public let esPropio: Bool?
    public let terrenoMasCercanoId: Int?
    public let distanciaKm: Double?

    public var propio: Bool { esPropio ?? true }
    public var severidad: Severidad? { Severidad(rawValue: nivelSeveridad) }
    public var observadoEn: Date { Date(timeIntervalSince1970: Double(timestampMs) / 1000) }
}

public struct ConteoReportes: Codable, Hashable, Sendable {
    public let total: Int
    public let alto: Int
    public let medio: Int
    public let bajo: Int
}

/// `ambito` de los listados de reportes.
public enum AmbitoReportes: String, Sendable, CaseIterable {
    case propios
    case comunidad
}

/// Lo que devuelve el mapa: grupos con zoom lejano o reportes sueltos de cerca. Puede
/// responder grupos aunque se hayan pedido reportes (demasiados en la vista).
public struct ReportesMapa: Decodable, Sendable {
    public let nivel: String?
    public let grupos: [GrupoReportesMapa]?
    public let reportes: [Reporte]?
    public let total: Int?
    public let cultivos: [String]?
}

public struct GrupoReportesMapa: Decodable, Hashable, Sendable {
    public let latitud: Double
    public let longitud: Double
    public let cantidad: Int
    public let severidadMax: String?
}

import Foundation

public struct EstadoConfirmacion: Codable, Hashable, Sendable {
    public let estado: String
    public let solicitadaEn: String?
    public let expiraEn: String?
    public let respuesta: String?
    public let respondidoEn: String?
}

public struct Prediccion: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let monitoreoId: Int?
    public let plantacionId: Int
    public let plagaId: Int
    public let plagaNombreCientifico: String
    public let fecha: DiaCalendario
    public let modelId: String
    public let horizonDays: Int
    public let probabilidadPorcentaje: Double
    public let umbralModeloRecomendadoPorcentaje: Double
    public let umbralEfectivoPorcentaje: Double?
    public let confirmacion: EstadoConfirmacion
}

public struct ConfirmacionPrediccion: Encodable, Sendable {
    public let biofix: SolicitudBiofix?
    public let respuesta: String
    public let idempotencyKey: String

    public init(respuesta: String, biofix: SolicitudBiofix? = nil, idempotencyKey: String = UUID().uuidString.lowercased()) {
        self.respuesta = respuesta
        self.biofix = biofix
        self.idempotencyKey = idempotencyKey
    }
}

public struct PrediccionConfirmada: Decodable, Sendable {
    public let biofix: ResultadoBiofix?
    public let id: String
    public let prediccionId: Int
    public let respuesta: String
    public let respondidoEn: String
    public let reporteId: Int?
    public let reporteCreado: Bool?
}

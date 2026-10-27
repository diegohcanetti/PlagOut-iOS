import Foundation

public struct Usuario: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let email: String
    public let nombre: String
    public let apellido: String
    public let cargo: String
    public let fechaCreacion: DiaCalendario
    public let radioNotificacionKm: Double?
    public let rol: String?
    public let activo: Bool?

    public static let rolAdmin = "admin"

    public var esAdmin: Bool { rol == Self.rolAdmin }
    public var radioKm: Double { radioNotificacionKm ?? 20 }
    public var nombreCompleto: String { "\(nombre) \(apellido)" }
}

/// El backend toma el email del token firmado, no del cuerpo.
public struct NuevoUsuario: Encodable, Sendable {
    public let nombre: String
    public let apellido: String
    public let cargoId: Int

    public init(nombre: String, apellido: String, cargoId: Int) {
        self.nombre = nombre
        self.apellido = apellido
        self.cargoId = cargoId
    }
}

public struct UsuarioCreado: Decodable, Sendable {
    public let usuarioId: String
    public let created: Bool
}

public struct CambiosUsuario: Encodable, Sendable {
    public let nombre: String?
    public let apellido: String?
    public let cargoId: Int?
    public let radioNotificacionKm: Double?

    public init(nombre: String? = nil, apellido: String? = nil, cargoId: Int? = nil, radioNotificacionKm: Double? = nil) {
        self.nombre = nombre
        self.apellido = apellido
        self.cargoId = cargoId
        self.radioNotificacionKm = radioNotificacionKm
    }
}

public struct Cargo: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let tipo: String
}

public struct ConsentimientoModelo: Codable, Hashable, Sendable {
    public let consentido: Bool
    public let vigenteDesde: String?
    public let versionContrato: String
}

public struct CambioConsentimiento: Encodable, Sendable {
    public let consentido: Bool
    public let versionContrato: String

    public init(consentido: Bool, versionContrato: String) {
        self.consentido = consentido
        self.versionContrato = versionContrato
    }
}

/// `authIdentityDeleted` en false: se borró del backend pero sigue en Supabase Auth; la app
/// cierra sesión igual. `retainedReports`: reportes que se conservan anonimizados.
public struct BajaDeCuenta: Decodable, Sendable {
    public let deleted: Bool
    public let authIdentityDeleted: Bool
    public let retainedReports: Int
}

/// Notificación dentro de la app. El backend devuelve solo las no leídas.
public struct Notificacion: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let titulo: String
    public let mensaje: String
    public let leido: Bool
    public let tipo: String
    public let fechaEnvio: String
    public let entidadId: Int?

    public var fecha: Date? { FechaHora.leer(fechaEnvio) }
}

public struct NotificacionLeida: Decodable, Sendable {
    public let id: Int
    public let leido: Bool
}

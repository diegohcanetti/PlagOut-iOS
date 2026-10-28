import Foundation

// Terrenos, plantaciones, monitoreos, ciclos y catálogos. Mismos contratos que `Models.kt` de
// Android y los presenters del backend (api/modules/agriculture/presenters.py). Las claves
// viajan en snake_case: el decoder las convierte (ver `JSON.decoder`).

public struct Terreno: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let terrenoNombre: String
    public let terrenoLatitud: Double
    public let terrenoLongitud: Double
    public let terrenoArea: Double

    public init(id: Int, terrenoNombre: String, terrenoLatitud: Double, terrenoLongitud: Double, terrenoArea: Double) {
        self.id = id
        self.terrenoNombre = terrenoNombre
        self.terrenoLatitud = terrenoLatitud
        self.terrenoLongitud = terrenoLongitud
        self.terrenoArea = terrenoArea
    }
}

public struct NuevoTerreno: Encodable, Sendable {
    public let nombre: String
    public let latitud: Double
    public let longitud: Double
    public let areaHectareas: Double

    public init(nombre: String, latitud: Double, longitud: Double, areaHectareas: Double) {
        self.nombre = nombre
        self.latitud = latitud
        self.longitud = longitud
        self.areaHectareas = areaHectareas
    }
}

public struct CambiosTerreno: Encodable, Sendable {
    public let nombre: String?
    public let areaHectareas: Double?

    public init(nombre: String? = nil, areaHectareas: Double? = nil) {
        self.nombre = nombre
        self.areaHectareas = areaHectareas
    }
}

/// El alta de un terreno responde con otros nombres de campo que el listado.
public struct TerrenoCreado: Decodable, Sendable {
    public let id: Int
    public let nombre: String
    public let latitud: Double
    public let longitud: Double
    public let areaHectareas: Double

    public var comoTerreno: Terreno {
        Terreno(id: id, terrenoNombre: nombre, terrenoLatitud: latitud, terrenoLongitud: longitud, terrenoArea: areaHectareas)
    }
}

public struct Plantacion: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let terrenoId: Int
    public let terrenoNombre: String
    public let cultivoId: Int
    public let cultivoNombre: String
    public let cultivoNombreCientifico: String
    public let fechaSiembra: DiaCalendario
    public let activa: Bool
}

public struct NuevaPlantacion: Encodable, Sendable {
    public let terrenoId: Int
    public let cultivoId: Int
    public let fechaSiembra: DiaCalendario
    public let activa: Bool

    public init(terrenoId: Int, cultivoId: Int, fechaSiembra: DiaCalendario, activa: Bool = true) {
        self.terrenoId = terrenoId
        self.cultivoId = cultivoId
        self.fechaSiembra = fechaSiembra
        self.activa = activa
    }
}

public struct PlantacionCreada: Decodable, Sendable {
    public let id: Int
    public let terrenoId: Int
    public let cultivoId: Int
    public let fechaSiembra: DiaCalendario
    public let activa: Bool
    public let cultivo: Cultivo
}

public struct CambiosPlantacion: Encodable, Sendable {
    public let activa: Bool?

    public init(activa: Bool?) { self.activa = activa }
}

public struct Cultivo: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let nombre: String
    public let nombreCientifico: String
}

/// `cultivosAfectados` son ids de cultivo. `etapas` son las que admite un reporte de esta plaga,
/// en orden del ciclo de vida (sin dato, todas). `modeloTermico` en false: se puede reportar pero
/// no admite monitoreos GDD nuevos.
public struct Plaga: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let nombre: String
    public let nombreCientifico: String
    public let cultivosAfectados: [Int]?
    public let etapas: [String]?
    public let modeloTermico: Bool?

    public var admiteMonitoreo: Bool { modeloTermico != false }

    public func afecta(cultivoId: Int) -> Bool {
        cultivosAfectados?.contains(cultivoId) ?? true
    }
}

public struct Monitoreo: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let plantacionId: Int
    public let terrenoId: Int
    public let terrenoNombre: String
    public let cultivoNombre: String
    public let plagaId: Int
    public let plagaNombre: String
    public let plagaNombreCientifico: String?
    /// GDD hasta la eclosión; sin modelo térmico citado, no hay.
    public let gddObjetivo: Double?
    public let umbralRiesgo: Int?
    public let activo: Bool?
    public let fechaInicio: DiaCalendario?
    public let alertasMlActivas: Bool?
    public let umbralAlertaMlRecomendado: Double?
    public let modeloAlertaMlId: String?
    public let horizonteAlertaMlDias: Int?
    public let ciclos: [CicloGDD]?
    public let observaciones: String?

    public var estaActivo: Bool { activo ?? true }
}

public struct NuevoMonitoreo: Encodable, Sendable {
    public let terrenoId: Int
    public let plantacionId: Int
    public let plagaId: Int
    public let umbralRiesgo: Int

    public init(terrenoId: Int, plantacionId: Int, plagaId: Int, umbralRiesgo: Int) {
        self.terrenoId = terrenoId
        self.plantacionId = plantacionId
        self.plagaId = plagaId
        self.umbralRiesgo = umbralRiesgo
    }
}

/// Para borrar la nota se manda "" (cadena vacía), no null.
public struct CambiosMonitoreo: Encodable, Sendable {
    public let umbralRiesgo: Int?
    public let activo: Bool?
    public let alertasMlActivas: Bool?
    public let observaciones: String?

    public init(umbralRiesgo: Int? = nil, activo: Bool? = nil, alertasMlActivas: Bool? = nil, observaciones: String? = nil) {
        self.umbralRiesgo = umbralRiesgo
        self.activo = activo
        self.alertasMlActivas = alertasMlActivas
        self.observaciones = observaciones
    }
}

/// Un ciclo GDD: empieza con un biofix. `gddAcumulado` es el desarrollo hasta el adulto; el
/// huevo acumula con su propia base hasta la eclosión (`gddAcumuladoHuevo`).
public struct CicloGDD: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let monitoreoId: Int
    public let fechaBiofix: DiaCalendario
    public let estado: String
    public let fechaActualizacion: DiaCalendario
    public let gddAcumulado: Double
    public let gddDiario: Double
    public let gddEclosion: Double
    public let gddGeneracion: Double
    public let progreso: Double
    public let estadioBiologico: String
    public let nivelAlerta: Int
    public let diasPendientes: Int
    public let fechaEclosion: DiaCalendario?
    public let gddAcumuladoHuevo: Double?

    /// Solo los ciclos "activo" siguen midiendo; el resto está finalizado (`CiclosUI.kt`).
    public var activo: Bool { estado == "activo" }
}

/// Registro de una observación de campo (biofix). `accion`: ver `AccionBiofix`.
public struct SolicitudBiofix: Codable, Sendable, Hashable {
    public let idempotencyKey: String
    public let fechaObservacion: DiaCalendario
    public let accion: String
    public let cicloId: Int?
    public let confirmarCicloAdicional: Bool
    public let versionContrato: String
    public let nivelSeveridad: String

    public init(
        idempotencyKey: String = UUID().uuidString.lowercased(),
        fechaObservacion: DiaCalendario,
        accion: AccionBiofix,
        cicloId: Int? = nil,
        confirmarCicloAdicional: Bool = false,
        nivelSeveridad: Severidad
    ) {
        self.idempotencyKey = idempotencyKey
        self.fechaObservacion = fechaObservacion
        self.accion = accion.rawValue
        self.cicloId = cicloId
        self.confirmarCicloAdicional = confirmarCicloAdicional
        self.versionContrato = "biofix-v1"
        self.nivelSeveridad = nivelSeveridad.rawValue
    }
}

/// "iniciar_ciclo" abre un ciclo nuevo; "asociar_ciclo" suma la observación a `cicloId`.
public enum AccionBiofix: String, Sendable, CaseIterable {
    case iniciarCiclo = "iniciar_ciclo"
    case asociarCiclo = "asociar_ciclo"
}

/// Severidades del contrato de reportes (config/simple_pest_reports.v1.yaml del backend).
public enum Severidad: String, Sendable, CaseIterable, Codable, Identifiable {
    case bajo = "Bajo"
    case medio = "Medio"
    case alto = "Alto"

    public var id: String { rawValue }
}

/// Etapas biológicas que admite un reporte, en orden del ciclo de vida.
public enum EtapaBiologica: String, Sendable, CaseIterable, Codable, Identifiable {
    case huevo = "HUEVO"
    case ninfa = "NINFA"
    case larva = "LARVA"
    case adulto = "ADULTO"

    public var id: String { rawValue }
}

public struct ResultadoBiofix: Codable, Sendable, Hashable {
    public let observacionId: String
    public let reporteId: Int
    public let reporteCreado: Bool
    public let cicloId: Int
    public let cicloCreado: Bool
    public let ciclo: CicloGDD
}

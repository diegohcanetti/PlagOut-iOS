import Foundation

// Las palabras de cada nivel según el hito que mide el ciclo, como `estiloDeNivel(nivel, hito)` y
// `estiloDeNivelAgregado` en `CampoUI.kt` de Android. Colores e íconos no cambian.

public enum Hito {
    public static let eclosion = "eclosion"
    /// Pulgones vivíparos: no tienen huevo y el nivel cuenta el avance hacia una nueva generación.
    public static let generacion = "generacion"
}

public struct PalabrasNivel: Equatable, Sendable {
    public let etiqueta: String
    public let descripcion: String
    /// nil: vale la recomendación de siempre.
    public let recomendacion: String?
}

public enum PalabrasDeNivel {
    /// Las palabras de [nivel] para lo que cuenta ese nivel. nil cuando ninguno es un pulgón
    /// vivíparo: valen las de siempre. Si todos lo son, las de generación; si se mezclan, palabras
    /// que valen para ambos.
    public static func para(nivel: Int, hitos: [String?]) -> PalabrasNivel? {
        let generacion = hitos.filter { $0 == Hito.generacion }.count
        guard nivel >= 0, generacion > 0 else { return nil }
        let todos = generacion == hitos.count
        switch (min(nivel, 2), todos) {
        case (0, true):
            return PalabrasNivel(etiqueta: "En desarrollo",
                                 descripcion: "Según los grados-día acumulados, la colonia se sigue desarrollando y falta para una nueva generación.",
                                 recomendacion: nil)
        case (1, true):
            return PalabrasNivel(etiqueta: "Generación cerca",
                                 descripcion: "Pasó tu umbral de aviso: la nueva generación estimada está cerca.",
                                 recomendacion: nil)
        case (_, true):
            return PalabrasNivel(etiqueta: "Nueva generación",
                                 descripcion: "Según el modelo térmico ya se completó una generación: puede haber más pulgones en el lote.",
                                 recomendacion: "Recorré el lote y contá; si aplicar o no se decide con el umbral de daño de tu cultivo.")
        case (0, false):
            return PalabrasNivel(etiqueta: "En desarrollo",
                                 descripcion: "Según los grados-día acumulados, falta para el objetivo de cada plaga: la eclosión o una nueva generación.",
                                 recomendacion: nil)
        case (1, false):
            return PalabrasNivel(etiqueta: "Objetivo cerca",
                                 descripcion: "Pasó tu umbral de aviso: la eclosión o la nueva generación estimada está cerca.",
                                 recomendacion: nil)
        default:
            return PalabrasNivel(etiqueta: "Objetivo alcanzado",
                                 descripcion: "Según el modelo térmico ya eclosionaron o se completó una generación: puede haber larvas, ninfas o más pulgones en el lote.",
                                 recomendacion: nil)
        }
    }
}

extension Monitoreo {
    /// El hito de los ciclos activos: un monitoreo sigue una sola plaga, así que lo comparten.
    public var hito: String? { ciclosActivos.first?.hito }
}

extension Array where Element == Monitoreo {
    /// Los hitos de los monitoreos activos que están en [nivel] (2 incluye los superiores).
    public func hitos(enNivel nivel: Int) -> [String?] {
        filter { $0.estaActivo && $0.nivelAlertaEfectivo >= 0 && Swift.min($0.nivelAlertaEfectivo, 2) == nivel }.map(\.hito)
    }
}

extension EtapaTermica {
    /// El rótulo de la etapa para lo que cuenta: los de siempre salvo que haya pulgones vivíparos.
    public func etiqueta(hitos: [String?]) -> String {
        PalabrasDeNivel.para(nivel: rawValue, hitos: hitos)?.etiqueta ?? etiqueta
    }

    public func estadioPorDefecto(hito: String?) -> String {
        guard hito == Hito.generacion else { return estadioPorDefecto }
        switch self {
        case .huevo: return "Ninfa"
        case .eclosionCerca: return "Ninfa, generación cerca"
        case .eclosionada: return "Adulto"
        }
    }

    public func recomendacion(hito: String?) -> String {
        guard hito == Hito.generacion else { return recomendacion }
        switch self {
        case .huevo: return "Según los grados-día acumulados todavía no se completó una nueva generación."
        case .eclosionCerca: return recomendacion
        case .eclosionada: return "Recorrer el lote y contar pulgones: la aplicación se decide con el umbral de daño del cultivo."
        }
    }
}

import Foundation

// Reglas de alta de terrenos, plantaciones y monitoreos (los ViewModels de Android). El backend
// valida lo mismo; acá se avisa antes de mandar.

public enum ReglasCampo {
    /// Nombre (1-150) y hectáreas (más de 0, hasta 100.000), como `NuevoTerrenoViewModel.kt`.
    public static func errorTerreno(nombre: String, hectareas: String) -> String? {
        let nombre = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        if nombre.isEmpty { return "El nombre del terreno no puede estar vacío" }
        if nombre.count > 150 { return "El nombre del terreno no puede superar los 150 caracteres" }
        guard let area = leerHectareas(hectareas), area > 0 else { return "Las hectáreas deben ser un número decimal mayor a 0" }
        if area > 100_000 { return "Las hectáreas no pueden superar las 100.000" }
        return nil
    }

    public static func leerHectareas(_ texto: String) -> Double? {
        Double(texto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    /// La caja de la República Argentina que usa Android.
    public static func enArgentina(latitud: Double, longitud: Double) -> Bool {
        (-55.0 ... -21.8).contains(latitud) && (-73.6 ... -53.6).contains(longitud)
    }

    /// Siembras de hasta un año atrás y nunca futuras.
    public static func rangoSiembra(hoy: DiaCalendario) -> ClosedRange<DiaCalendario> {
        DiaCalendario(anio: hoy.anio - 1, mes: hoy.mes, dia: min(hoy.dia, 28)) ... hoy
    }

    public struct PlagasParaMonitorear: Equatable, Sendable {
        public let disponibles: [Plaga]
        /// Afectan al cultivo y tienen modelo, pero ya se monitorean en esa plantación.
        public let yaMonitoreadas: Int
        /// Afectan al cultivo pero no tienen parámetros térmicos: se reportan, no se monitorean.
        public let sinModelo: [Plaga]
    }

    /// Las plagas que se pueden monitorear en un cultivo (`filtrarPlagas` de Android).
    public static func plagasParaMonitorear(_ plagas: [Plaga], cultivoId: Int, yaMonitoreadas: Set<Int>) -> PlagasParaMonitorear {
        let delCultivo = plagas.filter { $0.cultivosAfectados?.contains(cultivoId) == true }
        let conModelo = delCultivo.filter(\.admiteMonitoreo)
        let disponibles = conModelo.filter { !yaMonitoreadas.contains($0.id) }
        return PlagasParaMonitorear(
            disponibles: disponibles,
            yaMonitoreadas: conModelo.count - disponibles.count,
            sinModelo: delCultivo.filter { !$0.admiteMonitoreo }
        )
    }
}

extension Errores {
    public static let altaTerreno: [Int: String] = [500: "No se pudo crear el terreno. Intentá de nuevo."]

    public static let altaPlantacion: [String: String] = [
        "plantation_already_active": "Ya existe una plantación activa de ese cultivo con esa fecha en este terreno.",
        "cultivo_inactivo": "Este cultivo ya no está disponible. Elegí otro.",
    ]
    public static let altaPlantacionPorCodigo: [Int: String] = [
        400: "El cultivo seleccionado ya no está disponible.",
        404: "El terreno ya no existe.",
        500: "No se pudo crear la plantación. Intentá de nuevo.",
    ]

    public static let altaMonitoreo: [String: String] = [
        "plantation_finalized": "La plantación está finalizada.",
        "plaga_inactiva": "Esta plaga ya no está disponible.",
        "plaga_sin_modelo_termico": "Esta plaga no tiene parámetros térmicos validados: se puede reportar, pero no monitorear.",
        "monitoring_already_active": "Ya tenés un monitoreo activo de esta plaga en esta plantación.",
        "plaga_no_afecta_cultivo": "Ya no se puede monitorear en este cultivo.",
        "no afecta al cultivo": "Esta plaga no afecta al cultivo de la plantación.",
        "Terreno no encontrado": "El terreno ya no existe.",
        "Plantacion no encontrada": "La plantación ya no existe.",
    ]
    public static let altaMonitoreoPorCodigo: [Int: String] = [
        400: "Esta plaga ya no está disponible.",
        500: "No se pudo crear el monitoreo. Intentá de nuevo.",
    ]
}

public enum ReglasReporte {
    /// Las etapas que admite un reporte de esa plaga; sin dato, todas.
    public static func etapas(de plaga: Plaga) -> [EtapaBiologica] {
        let propias = (plaga.etapas ?? []).compactMap(EtapaBiologica.init(rawValue:))
        return propias.isEmpty ? EtapaBiologica.allCases : propias
    }

    /// "Larva" a partir de "LARVA" (los reportes viejos pueden traer etapas fuera del contrato).
    public static func etiqueta(etapa codigo: String) -> String {
        let limpio = codigo.trimmingCharacters(in: .whitespaces).lowercased()
        return limpio.prefix(1).uppercased() + limpio.dropFirst()
    }

    /// "350 m", "4,2 km", "18 km".
    public static func distancia(km: Double) -> String {
        if km < 1 { return "\(Int((km * 1000).rounded())) m" }
        let formato = km < 10 ? FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)) : .number.precision(.fractionLength(0))
        return km.formatted(formato.locale(Locale(identifier: "es_AR"))) + " km"
    }

    /// El zoom de un mapa (escala de teselas) a partir del ancho visible en grados.
    public static func zoom(anchoEnGrados: Double) -> Int {
        guard anchoEnGrados > 0 else { return 18 }
        return max(1, min(18, Int(log2(360 / anchoEnGrados).rounded(.down))))
    }
}

extension Severidad {
    public var descripcion: String {
        switch self {
        case .bajo: "Avistamiento inicial o presencias mínimas aisladas."
        case .medio: "Presencia moderada o visible en varias plantas."
        case .alto: "Infestación severa o daño crítico que pone en riesgo el rendimiento del lote."
        }
    }
}

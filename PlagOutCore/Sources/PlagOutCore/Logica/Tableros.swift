import Foundation

// Tableros del productor, calculados en la app con sus monitoreos, terrenos y plantaciones, como
// `AdminMetricasModel.kt` de Android (sin las métricas globales del admin).

extension Monitoreo {
    /// El nivel del ciclo que describe el monitoreo; nil mientras espera el biofix.
    public var nivelAlertaResuelto: Int? { cicloQueDescribe?.nivelAlerta }
    /// El nivel del ciclo activo más avanzado; nil si no hay ciclos activos.
    public var nivelAlertaVigente: Int? { cicloVigente?.nivelAlerta }
}

/// Etapa térmica de la plaga: el nivel de alerta del ciclo (0 huevo, 1 eclosión cerca, 2 eclosionó).
public enum EtapaTermica: Int, CaseIterable, Comparable, Sendable {
    case huevo = 0, eclosionCerca = 1, eclosionada = 2

    public init(nivel: Int) { self = nivel >= 2 ? .eclosionada : nivel == 1 ? .eclosionCerca : .huevo }

    public static func < (a: EtapaTermica, b: EtapaTermica) -> Bool { a.rawValue < b.rawValue }

    public var etiqueta: String {
        switch self {
        case .huevo: "En huevo"
        case .eclosionCerca: "Eclosión cerca"
        case .eclosionada: "Eclosionó"
        }
    }

    public var estadioPorDefecto: String {
        switch self {
        case .huevo: "Huevo"
        case .eclosionCerca: "Huevo, eclosión cerca"
        case .eclosionada: "Larva o ninfa"
        }
    }

    // Las larvas chicas son las más sensibles al control; aplicar se decide con el umbral de daño
    // del cultivo (Gamundi y Perotti, INTA 2007), no con el modelo.
    public var recomendacion: String {
        switch self {
        case .huevo: "Según los grados-día acumulados todavía no eclosionó."
        case .eclosionCerca: "Pasó el umbral de aviso del productor: conviene planificar la recorrida del lote."
        case .eclosionada: "Recorrer el lote: las larvas chicas son las más sensibles al control y la aplicación se decide con el umbral de daño del cultivo."
        }
    }
}

public struct ResumenPlaga: Equatable, Sendable, Identifiable {
    public var id: String { nombre }
    public let nombre: String
    public let cientifico: String?
    public let monitoreos: Int
    public let incidencia: Double
    public let enRiesgoAlto: Int
    public let cultivos: [String]
}

public struct ResumenCultivoCampania: Equatable, Sendable, Identifiable {
    public var id: String { nombre }
    public let nombre: String
    public let monitoreos: Int
    public let plagas: [(nombre: String, monitoreos: Int)]

    public static func == (a: Self, b: Self) -> Bool {
        a.nombre == b.nombre && a.monitoreos == b.monitoreos && a.plagas.map(\.nombre) == b.plagas.map(\.nombre)
    }
}

/// Una campaña agrícola: del 1 de julio al 30 de junio.
public struct Campania: Equatable, Sendable, Identifiable {
    public var id: String { nombre }
    public let nombre: String
    public let anioInicio: Int
    public let monitoreos: Int
    public let hectareas: Double
    public let plagas: [ResumenPlaga]
    public let cultivos: [ResumenCultivoCampania]
    public let riesgoBajo: Int
    public let riesgoModerado: Int
    public let riesgoAlto: Int

    public var plagaPredominante: ResumenPlaga? { plagas.first }
}

public struct SemaforoHectareas: Equatable, Sendable {
    public var hectareas: [EtapaTermica: Double]
    public var lotes: [EtapaTermica: Int]
    public var lotesEsperandoBiofix: Int
    public var hectareasEsperandoBiofix: Double
    public var lotesSinMonitoreo: Int
    public var hectareasSinMonitoreo: Double

    public var totalHectareas: Double { hectareas.values.reduce(0, +) }
    public var totalLotes: Int { lotes.values.reduce(0, +) }
}

public struct CultivoConPlagas: Equatable, Sendable, Identifiable {
    public var id: String { nombre }
    public let nombre: String
    public let lotes: Int
    public let hectareas: Double
    public let plagas: [(nombre: String, lotes: Int, porcentaje: Double)]
    public let lotesEnRiesgoAlto: Int
    public let diasDesdeSiembra: Int?

    public static func == (a: Self, b: Self) -> Bool {
        a.nombre == b.nombre && a.lotes == b.lotes && a.plagas.map(\.nombre) == b.plagas.map(\.nombre)
    }
}

public struct LoteEnEtapa: Equatable, Sendable, Identifiable {
    public var id: Int { monitoreoId }
    public let monitoreoId: Int
    public let terreno: String
    public let cultivo: String
    public let plaga: String
    public let etapa: EtapaTermica
    public let progreso: Double
    public let estadio: String
}

public enum Tableros {
    public static func campania(de fecha: DiaCalendario) -> String {
        fecha.mes >= 7 ? "\(fecha.anio)/\(fecha.anio + 1)" : "\(fecha.anio - 1)/\(fecha.anio)"
    }

    public static func campanias(_ monitoreos: [Monitoreo], terrenos: [Terreno], hoy: DiaCalendario = .hoy()) -> [Campania] {
        let areas = Dictionary(terrenos.map { ($0.id, $0.terrenoArea) }, uniquingKeysWith: { a, _ in a })
        let porCampania = Dictionary(grouping: monitoreos) { campania(de: $0.fechaInicio ?? hoy) }
        return porCampania.map { nombre, lista in
            let total = lista.count
            let plagas = Dictionary(grouping: lista) { $0.plagaNombre.trimmingCharacters(in: .whitespaces) }.map { plaga, items in
                let cultivos = Dictionary(grouping: items.map { $0.cultivoNombre.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }, by: { $0 })
                    .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }.map(\.key)
                return ResumenPlaga(
                    nombre: plaga, cientifico: items.compactMap(\.plagaNombreCientifico).first, monitoreos: items.count,
                    incidencia: total > 0 ? Double(items.count) * 100 / Double(total) : 0,
                    enRiesgoAlto: items.filter { ($0.nivelAlertaResuelto ?? -1) >= 2 }.count, cultivos: cultivos
                )
            }.sorted { ($0.monitoreos, $1.nombre) > ($1.monitoreos, $0.nombre) }
            let cultivos = Dictionary(grouping: lista.filter { !$0.cultivoNombre.trimmingCharacters(in: .whitespaces).isEmpty }) {
                $0.cultivoNombre.trimmingCharacters(in: .whitespaces)
            }.map { cultivo, items in
                let plagas = Dictionary(grouping: items) { $0.plagaNombre.trimmingCharacters(in: .whitespaces) }
                    .map { (nombre: $0.key, monitoreos: $0.value.count) }
                    .sorted { ($0.monitoreos, $1.nombre) > ($1.monitoreos, $0.nombre) }
                return ResumenCultivoCampania(nombre: cultivo, monitoreos: items.count, plagas: plagas)
            }.sorted { ($0.monitoreos, $1.nombre) > ($1.monitoreos, $0.nombre) }
            // Los que esperan el biofix no tienen nivel: no cuentan en ningún riesgo.
            return Campania(
                nombre: nombre, anioInicio: Int(nombre.prefix(4)) ?? 0, monitoreos: total,
                hectareas: Set(lista.map(\.terrenoId)).compactMap { areas[$0] }.reduce(0, +),
                plagas: plagas, cultivos: cultivos,
                riesgoBajo: lista.filter { $0.nivelAlertaResuelto == 0 }.count,
                riesgoModerado: lista.filter { $0.nivelAlertaResuelto == 1 }.count,
                riesgoAlto: lista.filter { ($0.nivelAlertaResuelto ?? -1) >= 2 }.count
            )
        }.sorted { $0.anioInicio > $1.anioInicio }
    }

    /// Hectáreas según la etapa más avanzada de cada lote con monitoreos activos.
    public static func semaforo(_ monitoreos: [Monitoreo], terrenos: [Terreno]) -> SemaforoHectareas {
        let activos = monitoreos.filter(\.estaActivo)
        let areas = Dictionary(terrenos.map { ($0.id, $0.terrenoArea) }, uniquingKeysWith: { a, _ in a })
        var nivelPorTerreno: [Int: Int] = [:]
        for (terreno, lista) in Dictionary(grouping: activos, by: \.terrenoId) {
            if let nivel = lista.compactMap(\.nivelAlertaVigente).max() { nivelPorTerreno[terreno] = nivel }
        }
        var resultado = SemaforoHectareas(hectareas: [:], lotes: [:], lotesEsperandoBiofix: 0, hectareasEsperandoBiofix: 0,
                                          lotesSinMonitoreo: 0, hectareasSinMonitoreo: 0)
        for (terreno, nivel) in nivelPorTerreno {
            let etapa = EtapaTermica(nivel: nivel)
            resultado.hectareas[etapa, default: 0] += areas[terreno] ?? 0
            resultado.lotes[etapa, default: 0] += 1
        }
        let conMonitoreo = Set(activos.map(\.terrenoId))
        let esperando = conMonitoreo.subtracting(nivelPorTerreno.keys)
        let sinMonitoreo = terrenos.filter { !conMonitoreo.contains($0.id) }
        resultado.lotesEsperandoBiofix = esperando.count
        resultado.hectareasEsperandoBiofix = esperando.compactMap { areas[$0] }.reduce(0, +)
        resultado.lotesSinMonitoreo = sinMonitoreo.count
        resultado.hectareasSinMonitoreo = sinMonitoreo.map(\.terrenoArea).reduce(0, +)
        return resultado
    }

    /// Las plagas de cada cultivo (preferentemente con los monitoreos activos).
    public static func plagasPorCultivo(_ monitoreos: [Monitoreo], terrenos: [Terreno], plantaciones: [Plantacion], hoy: DiaCalendario = .hoy()) -> [CultivoConPlagas] {
        let areas = Dictionary(terrenos.map { ($0.id, $0.terrenoArea) }, uniquingKeysWith: { a, _ in a })
        let activos = monitoreos.filter(\.estaActivo)
        let analizados = activos.isEmpty ? monitoreos : activos
        return Dictionary(grouping: analizados) { $0.cultivoNombre.trimmingCharacters(in: .whitespaces) }.map { cultivo, lista in
            let lotes = Set(lista.map(\.terrenoId))
            let delCultivo = plantaciones.filter { $0.cultivoNombre.trimmingCharacters(in: .whitespaces) == cultivo }
            let siembra = delCultivo.filter(\.activa).map(\.fechaSiembra).min() ?? delCultivo.map(\.fechaSiembra).max()
            let plagas = Dictionary(grouping: lista) { $0.plagaNombre.trimmingCharacters(in: .whitespaces) }.map { plaga, items in
                let lotesPlaga = Set(items.map(\.terrenoId)).count
                return (nombre: plaga, lotes: lotesPlaga, porcentaje: lotes.isEmpty ? 0 : Double(lotesPlaga) * 100 / Double(lotes.count))
            }.sorted { ($0.lotes, $1.nombre) > ($1.lotes, $0.nombre) }
            return CultivoConPlagas(
                nombre: cultivo, lotes: lotes.count, hectareas: lotes.compactMap { areas[$0] }.reduce(0, +), plagas: plagas,
                lotesEnRiesgoAlto: lista.filter { ($0.nivelAlertaResuelto ?? -1) >= 2 }.count,
                diasDesdeSiembra: siembra.map { max(0, $0.dias(hasta: hoy)) }
            )
        }.sorted { ($0.lotes, $1.nombre) > ($1.lotes, $0.nombre) }
    }

    /// Etapa de cada monitoreo activo con ciclo, lo más avanzado primero.
    public static func lotesPorEtapa(_ monitoreos: [Monitoreo]) -> [LoteEnEtapa] {
        monitoreos.filter(\.estaActivo).compactMap { m -> LoteEnEtapa? in
            guard let ciclo = m.cicloVigente else { return nil }
            let etapa = EtapaTermica(nivel: ciclo.nivelAlerta)
            let estadio = ciclo.estadioBiologico.trimmingCharacters(in: .whitespaces)
            return LoteEnEtapa(monitoreoId: m.id, terreno: m.terrenoNombre, cultivo: m.cultivoNombre, plaga: m.plagaNombre,
                               etapa: etapa, progreso: ciclo.progreso, estadio: estadio.isEmpty ? etapa.estadioPorDefecto : estadio.capitalized)
        }.sorted { ($0.etapa, $0.progreso) > ($1.etapa, $1.progreso) }
    }
}

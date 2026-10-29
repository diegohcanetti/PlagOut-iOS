import Foundation

// Lectura de los ciclos de un monitoreo, con el mismo criterio que `CiclosUI.kt` y
// `AdminMetricasModel.kt` de Android.

extension Monitoreo {
    public var ciclosActivos: [CicloGDD] { (ciclos ?? []).filter(\.activo) }
    public var ciclosFinalizados: [CicloGDD] { (ciclos ?? []).filter { !$0.activo } }

    /// Activo y sin ciclos que midan: falta registrar la primera observación (biofix).
    public var esperandoBiofix: Bool { estaActivo && ciclosActivos.isEmpty }

    /// El ciclo que describe el monitoreo: el activo o, si no hay, el de biofix más reciente
    /// (mismo criterio que el backend). nil mientras espera el biofix.
    public var cicloQueDescribe: CicloGDD? {
        if let activo = (ciclos ?? []).first(where: { $0.estado.lowercased() == "activo" }) { return activo }
        return (ciclos ?? []).max { ($0.fechaBiofix, $0.id) < ($1.fechaBiofix, $1.id) }
    }

    /// Entre los activos, el más avanzado en alerta (y luego en progreso).
    public var cicloVigente: CicloGDD? {
        ciclosActivos.max { ($0.nivelAlerta, $0.progreso) < ($1.nivelAlerta, $1.progreso) }
    }

    /// El nivel de alerta más alto de los ciclos activos, o -1 si no hay ninguno.
    public var nivelAlertaEfectivo: Int { ciclosActivos.map(\.nivelAlerta).max() ?? -1 }

    public var ciclosEnAlerta: Int { ciclosActivos.filter { $0.enAlerta(umbralRiesgo: umbralRiesgo) }.count }

    public func puedeFinalizar(_ ciclo: CicloGDD) -> Bool {
        estaActivo && ciclo.activo && ciclo.enAlerta(umbralRiesgo: umbralRiesgo)
    }
}

extension CicloGDD {
    /// Llegó al umbral de riesgo del monitoreo (100 % si no tiene).
    public func enAlerta(umbralRiesgo: Int?) -> Bool {
        progreso >= Double(umbralRiesgo ?? 100)
    }

    /// Los GDD hasta la eclosión de este ciclo; si no los trae, los del monitoreo.
    public func objetivo(delMonitoreo objetivoMonitoreo: Double?) -> Double? {
        if gddEclosion > 0 { return gddEclosion }
        if let objetivoMonitoreo, objetivoMonitoreo > 0 { return objetivoMonitoreo }
        return nil
    }

    /// Lo acumulado hacia la eclosión: el huevo tiene su propio acumulador.
    public var acumuladoHuevo: Double { gddAcumuladoHuevo ?? gddAcumulado }

    /// Lo que se muestra como acumulado: no pasa del objetivo una vez completo.
    public func acumuladoVisible(objetivo: Double?) -> Double {
        if let objetivo, progreso >= 100 { return min(acumuladoHuevo, objetivo) }
        return acumuladoHuevo
    }
}

extension CicloGDD {
    /// Eclosionó: tiene fecha de eclosión o llegó al 100 %.
    public var eclosiono: Bool { fechaEclosion != nil || progreso >= 100 }

    /// La fecha de la última actualización que se muestra: después de la eclosión, la eclosión.
    public var actualizacionVisible: DiaCalendario {
        if let eclosion = fechaEclosion, fechaActualizacion > eclosion { return eclosion }
        return fechaActualizacion
    }

    /// GDD por día desde el biofix (el promedio real), o el del último día si no hay historia.
    var ritmoDiario: Double {
        let dias = fechaBiofix.dias(hasta: fechaActualizacion)
        return dias > 0 ? acumuladoHuevo / Double(dias) : gddDiario
    }

    /// Días que faltan para el objetivo al ritmo actual; nil si ya llegó o no se puede estimar.
    public func diasEstimados(objetivoMonitoreo: Double?) -> Int? {
        guard let objetivo = objetivo(delMonitoreo: objetivoMonitoreo) else { return nil }
        let restante = objetivo - acumuladoHuevo
        guard restante > 0, progreso < 100 else { return nil }
        let ritmo = ritmoDiario
        return ritmo > 0 ? Int((restante / ritmo).rounded(.up)) : nil
    }
}

extension Array where Element == CicloGDD {
    /// Número de cada ciclo por orden de biofix ("Ciclo 1", "Ciclo 2", …).
    public var numeros: [Int: Int] {
        let ordenados = sorted { ($0.fechaBiofix, $0.id) < ($1.fechaBiofix, $1.id) }
        return Dictionary(uniqueKeysWithValues: ordenados.enumerated().map { ($1.id, $0 + 1) })
    }

    /// Los más avanzados primero.
    public var porProgreso: [CicloGDD] {
        sorted { ($0.progreso, -$0.id) > ($1.progreso, -$1.id) }
    }
}

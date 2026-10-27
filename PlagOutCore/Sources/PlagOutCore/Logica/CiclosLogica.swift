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

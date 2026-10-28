import Foundation

/// Adónde lleva tocar una notificación (`destinoDe` en `Models.kt`).
public enum Destino: Hashable, Sendable {
    case monitoreo(Int)
    case monitoreos
    case prediccion(Int)
    case reporte(Int)
    case reportes
    case plantacion(Int)
    case terrenos

    public static func de(_ notificacion: Notificacion) -> Destino? {
        let id = notificacion.entidadId
        let tipo = notificacion.tipo.uppercased()
        if ["ALERTA_GDD_CICLO", "BIOFIX_CICLO"].contains(tipo) { return id.map(Destino.monitoreo) }
        if tipo == "ALERTA_ML_RIESGO" { return id.map(Destino.prediccion) }
        if tipo.contains("REPORTE") { return id.map(Destino.reporte) ?? .reportes }
        if tipo.contains("GDD") || tipo.contains("MONITOREO") { return id.map(Destino.monitoreo) ?? .monitoreos }
        if tipo.contains("BIOFIX") || tipo.contains("PLANTACION") { return id.map(Destino.plantacion) ?? .terrenos }
        return nil
    }
}

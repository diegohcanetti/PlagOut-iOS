import Foundation
import Observation
import PlagOutCore

/// Detalle de un monitoreo (`MonitoreoDetalleViewModel.kt`), sin caché local: siempre se lee de
/// la red.
@MainActor
@Observable
final class MonitoreoDetalleModelo {
    static let maxCaracteresNotas = 500

    let id: Int
    var monitoreo: Monitoreo?
    var cargando = true
    var noDisponible = false
    var error: String?
    var guardando = false

    init(id: Int) { self.id = id }

    func cargar(_ api: PlagOutAPI) async {
        if monitoreo == nil { cargando = true }
        defer { cargando = false }
        do {
            monitoreo = try await api.monitoreo(id: id)
            noDisponible = false
            error = nil
        } catch {
            // 404 del recurso: se eliminó (por ejemplo desde otro dispositivo) o es de otra cuenta.
            if error.codigo == 404 {
                monitoreo = nil
                noDisponible = true
            } else if monitoreo == nil {
                self.error = error.codigo == nil ? "No se pudo cargar el monitoreo. Revisá tu conexión." : error.mensaje
            } else {
                self.error = error.mensaje
            }
        }
    }

    /// Aplica un cambio y devuelve el error para mostrar, o nil si salió bien.
    func cambiar(_ api: PlagOutAPI, _ cambios: CambiosMonitoreo, al500: String) async -> String? {
        guardando = true
        defer { guardando = false }
        do {
            monitoreo = try await api.actualizarMonitoreo(id: id, cambios, porCodigo: [500: al500])
            return nil
        } catch {
            return error.mensaje
        }
    }

    func eliminar(_ api: PlagOutAPI) async -> String? {
        guardando = true
        defer { guardando = false }
        do {
            try await api.eliminarMonitoreo(id: id)
            return nil
        } catch {
            if error.codigo == 404 { return nil } // ya no existía
            return error.codigo == 500 ? "No se pudo eliminar el monitoreo. Intentá de nuevo." : error.mensaje
        }
    }
}

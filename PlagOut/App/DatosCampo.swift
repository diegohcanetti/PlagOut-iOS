import Foundation
import Observation
import PlagOutCore

/// Terrenos, plantaciones, monitoreos y catálogos del productor, compartidos por las pestañas.
/// Sin caché en disco: se leen de la red al entrar y se recargan después de cada cambio.
@MainActor
@Observable
final class DatosCampo {
    var terrenos: [Terreno] = []
    var plantaciones: [Plantacion] = []
    var monitoreos: [Monitoreo] = []
    var cultivos: [Cultivo] = []
    var plagas: [Plaga] = []
    var cargando = false
    var cargado = false
    var error: String?

    private var enCurso: Task<Void, Never>?

    /// Trae todo en paralelo. Si ya hay una carga en curso, espera esa: dos pantallas pueden
    /// pedirla a la vez. Corre en su propia tarea para que no la corte el cambio de pestaña.
    func cargar(_ api: PlagOutAPI) async {
        if let enCurso {
            await enCurso.value
            return
        }
        let tarea = Task { await traer(api) }
        enCurso = tarea
        await tarea.value
        enCurso = nil
    }

    private func traer(_ api: PlagOutAPI) async {
        cargando = !cargado
        defer { cargando = false }
        do {
            async let terrenos = api.terrenos()
            async let plantaciones = api.plantaciones()
            async let monitoreos = api.monitoreos()
            if cultivos.isEmpty || plagas.isEmpty {
                async let cultivos = api.cultivos()
                async let plagas = api.plagas()
                (self.cultivos, self.plagas) = try await (cultivos, plagas)
            }
            (self.terrenos, self.plantaciones, self.monitoreos) = try await (terrenos, plantaciones, monitoreos)
            cargado = true
            error = nil
        } catch let error as ErrorBackend {
            self.error = error.mensaje
        } catch {
            self.error = ErrorBackend.mensajeGenerico
        }
    }

    func vaciar() {
        terrenos = []
        plantaciones = []
        monitoreos = []
        cargado = false
        error = nil
    }

    func terreno(_ id: Int) -> Terreno? { terrenos.first { $0.id == id } }
    func plantacion(_ id: Int) -> Plantacion? { plantaciones.first { $0.id == id } }

    func plantaciones(deTerreno id: Int) -> [Plantacion] {
        plantaciones.filter { $0.terrenoId == id }.sorted { ($0.activa ? 1 : 0, $0.fechaSiembra) > ($1.activa ? 1 : 0, $1.fechaSiembra) }
    }

    func monitoreos(deTerreno id: Int) -> [Monitoreo] { monitoreos.filter { $0.terrenoId == id } }
    func monitoreos(dePlantacion id: Int) -> [Monitoreo] { monitoreos.filter { $0.plantacionId == id } }

    /// Las plagas que ya tienen un monitoreo activo en una plantación (para no duplicarlo).
    func plagasMonitoreadas(enPlantacion id: Int) -> Set<Int> {
        Set(monitoreos(dePlantacion: id).filter(\.estaActivo).map(\.plagaId))
    }
}

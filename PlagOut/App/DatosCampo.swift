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

    private var enCurso: (id: UUID, tarea: Task<Void, Never>)?

    /// Trae todo en paralelo. Si ya hay una carga en curso, espera esa: dos pantallas pueden
    /// pedirla a la vez. Corre en su propia tarea para que no la corte el cambio de pestaña.
    func cargar(_ api: PlagOutAPI) async {
        if let enCurso {
            await enCurso.tarea.value
            return
        }
        let id = UUID()
        let tarea = Task { await traer(api) }
        enCurso = (id, tarea)
        await tarea.value
        if enCurso?.id == id { enCurso = nil }
    }

    private func traer(_ api: PlagOutAPI) async {
        guard !Task.isCancelled else { return }
        cargando = !cargado
        defer {
            if !Task.isCancelled { cargando = false }
        }
        do {
            async let terrenos = api.terrenos()
            async let plantaciones = api.plantaciones()
            async let monitoreos = api.monitoreos()
            if cultivos.isEmpty || plagas.isEmpty {
                async let cultivos = api.cultivos()
                async let plagas = api.plagas()
                let catalogo = try await (cultivos, plagas)
                guard !Task.isCancelled else { return }
                (self.cultivos, self.plagas) = catalogo
            }
            let datos = try await (terrenos, plantaciones, monitoreos)
            guard !Task.isCancelled else { return }
            (self.terrenos, self.plantaciones, self.monitoreos) = datos
            cargado = true
            error = nil
        } catch {
            guard !Task.isCancelled else { return }
            self.error = (error as? ErrorBackend)?.mensaje ?? ErrorBackend.mensajeGenerico
        }
    }

    func vaciar() {
        enCurso?.tarea.cancel()
        enCurso = nil
        terrenos = []
        plantaciones = []
        monitoreos = []
        cargando = false
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

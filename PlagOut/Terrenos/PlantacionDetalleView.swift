import PlagOutCore
import SwiftUI

/// Un cultivo con sus monitoreos: crear un monitoreo, finalizar o eliminar el cultivo.
struct PlantacionDetalleView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    let id: Int
    @State private var creandoMonitoreo = false
    @State private var confirmarFinalizar = false
    @State private var confirmarEliminar = false

    var body: some View {
        let datos = estado.datos
        Group {
            if let plantacion = datos.plantacion(id) {
                let monitoreos = FiltroMonitoreos.todos.aplicar(datos.monitoreos(dePlantacion: id))
                ScrollView {
                    VStack(spacing: 14) {
                        TarjetaPlantacion(plantacion: plantacion, monitoreos: monitoreos)
                        HStack {
                            Text("Monitoreos").font(.headline)
                            Spacer()
                            if plantacion.activa {
                                Button("Nuevo Monitoreo", systemImage: "plus") { creandoMonitoreo = true }
                                    .buttonStyle(.bordered)
                                    .tint(Paleta.bosque)
                            }
                        }
                        if monitoreos.isEmpty {
                            EstadoVacio(icono: "flask", titulo: "Todavía no hay monitoreos en este cultivo",
                                        detalle: plantacion.activa ? "Creá un monitoreo para seguir el riesgo de plagas en este cultivo."
                                                                   : "Este cultivo se finalizó sin registrar monitoreos.")
                        }
                        ForEach(monitoreos) { monitoreo in
                            NavigationLink(value: Destino.monitoreo(monitoreo.id)) { TarjetaMonitoreo(monitoreo: monitoreo) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await datos.cargar(estado.api) }
                .navigationTitle("Detalle de cultivo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            if plantacion.activa {
                                Button("Finalizar cultivo", systemImage: "flag.checkered") { confirmarFinalizar = true }
                            }
                            Button("Eliminar cultivo", systemImage: "trash", role: .destructive) { confirmarEliminar = true }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                .sheet(isPresented: $creandoMonitoreo) { NuevoMonitoreoView(plantacionFija: plantacion) }
                .confirmationDialog("¿Finalizar este cultivo?", isPresented: $confirmarFinalizar, titleVisibility: .visible) {
                    Button("Finalizar cultivo", role: .destructive) { Task { await finalizar() } }
                } message: {
                    Text("Se finalizan todos sus monitoreos y dejás de recibir sus alertas. Se conserva el historial para consultarlo. No se puede volver a activar.")
                }
                .confirmationDialog("Eliminar cultivo", isPresented: $confirmarEliminar, titleVisibility: .visible) {
                    Button("Eliminar", role: .destructive) { Task { await eliminar() } }
                } message: {
                    Text("Borra sus monitoreos y su historial.")
                }
            } else {
                EstadoVacio(icono: "questionmark.folder", titulo: "No disponible", detalle: "Este cultivo ya no existe.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoCampo()
    }

    private func finalizar() async {
        do {
            _ = try await estado.api.actualizarPlantacion(id: id, CambiosPlantacion(activa: false))
            estado.avisar("Cultivo finalizado.", esError: false)
            await estado.datos.cargar(estado.api)
        } catch {
            estado.avisar(error.mensaje)
        }
    }

    private func eliminar() async {
        do {
            try await estado.api.eliminarPlantacion(id: id)
            estado.avisar("Cultivo eliminado.", esError: false)
            cerrar()
            await estado.datos.cargar(estado.api)
        } catch {
            estado.avisar(error.mensaje)
        }
    }
}

/// Alta de un monitoreo: terreno → cultivo → plaga y umbral. Con `plantacionFija` se salta la
/// elección del cultivo (`AgregarMonitoreoScreen.kt`).
struct NuevoMonitoreoView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    var plantacionFija: Plantacion?
    @State private var plantacion: Plantacion?
    @State private var plaga: Plaga?
    @State private var umbral: Double = 80
    @State private var enviando = false
    @State private var error: String?

    var body: some View {
        let datos = estado.datos
        let elegida = plantacionFija ?? plantacion
        let opciones = elegida.map {
            ReglasCampo.plagasParaMonitorear(datos.plagas, cultivoId: $0.cultivoId, yaMonitoreadas: datos.plagasMonitoreadas(enPlantacion: $0.id))
        }
        NavigationStack {
            Form {
                if plantacionFija == nil {
                    Section("Cultivo") {
                        let activas = datos.plantaciones.filter(\.activa)
                        if activas.isEmpty {
                            Text("Primero agregá un cultivo activo en uno de tus terrenos.").foregroundStyle(Paleta.textoSecundario)
                        }
                        Picker("Cultivo", selection: $plantacion) {
                            Text("Elegí un cultivo").tag(Plantacion?.none)
                            ForEach(activas) { Text("\($0.cultivoNombre) · \($0.terrenoNombre)").tag(Optional($0)) }
                        }
                        .onChange(of: plantacion) { plaga = nil }
                    }
                } else if let plantacionFija {
                    Section("Cultivo") { Text("\(plantacionFija.cultivoNombre) · \(plantacionFija.terrenoNombre)") }
                }
                if let opciones {
                    Section {
                        Picker("Plaga", selection: $plaga) {
                            Text("Elegí una plaga").tag(Plaga?.none)
                            ForEach(opciones.disponibles) { Text($0.nombre).tag(Optional($0)) }
                        }
                    } header: {
                        Text("Plaga")
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            if opciones.yaMonitoreadas > 0 {
                                Text(opciones.yaMonitoreadas == 1 ? "1 plaga ya se monitorea en este cultivo." : "\(opciones.yaMonitoreadas) plagas ya se monitorean en este cultivo.")
                            }
                            if !opciones.sinModelo.isEmpty {
                                Text("Sin parámetros térmicos validados (se pueden reportar, no monitorear): \(opciones.sinModelo.map(\.nombre).joined(separator: ", ")).")
                            }
                        }
                    }
                    Section {
                        HStack {
                            Text("Umbral de riesgo")
                            Spacer()
                            Text("\(Int(umbral))%").fontWeight(.semibold).foregroundStyle(Paleta.bosque)
                        }
                        Slider(value: $umbral, in: 0...100, step: 1).tint(Paleta.bosque)
                    } footer: {
                        Text("Te avisamos cuando el ciclo supere este porcentaje del camino hacia la eclosión.")
                    }
                }
                if let error { Section { MensajeEnLinea(texto: error) } }
            }
            .navigationTitle("Nuevo Monitoreo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando { ProgressView() } else {
                        Button("Crear") { Task { await crear(elegida) } }.disabled(elegida == nil || plaga == nil)
                    }
                }
            }
            .task { if !datos.cargado { await datos.cargar(estado.api) } }
        }
    }

    private func crear(_ plantacion: Plantacion?) async {
        guard let plantacion, let plaga else { return }
        enviando = true
        defer { enviando = false }
        do {
            let nuevo = try await estado.api.crearMonitoreo(NuevoMonitoreo(
                terrenoId: plantacion.terrenoId, plantacionId: plantacion.id, plagaId: plaga.id, umbralRiesgo: Int(umbral)
            ))
            estado.avisar("Monitoreo creado.", esError: false)
            await estado.datos.cargar(estado.api)
            cerrar()
            estado.destinoPendiente = .monitoreo(nuevo.id)
        } catch {
            self.error = error.mensaje
        }
    }
}

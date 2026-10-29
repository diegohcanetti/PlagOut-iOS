import PlagOutCore
import SwiftUI

/// Nueva alerta de plaga (`CrearReporteScreen.kt`): terreno → cultivo → plaga → etapa →
/// severidad. La ubicación es la del terreno y la hora, la del momento.
struct NuevoReporteView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    let alGuardar: () async -> Void

    @State private var terreno: Terreno?
    @State private var plantacion: Plantacion?
    @State private var plaga: Plaga?
    @State private var etapa: EtapaBiologica?
    @State private var severidad: Severidad = .bajo
    @State private var momento = Date()
    @State private var enviando = false
    @State private var error: String?
    @State private var infoSeveridad = false

    var body: some View {
        let datos = estado.datos
        let plantaciones = terreno.map { t in datos.plantaciones.filter { $0.terrenoId == t.id && $0.activa } } ?? []
        let plagas = plantacion.map { p in datos.plagas.filter { $0.cultivosAfectados?.contains(p.cultivoId) == true } } ?? []
        NavigationStack {
            Form {
                Section("Terreno de la alerta") {
                    if datos.terrenos.isEmpty {
                        Text("No hay terrenos cargados").foregroundStyle(Paleta.textoSecundario)
                    }
                    Picker("Terreno", selection: $terreno) {
                        Text("Seleccioná un terreno").tag(Terreno?.none)
                        ForEach(datos.terrenos) { Text($0.terrenoNombre).tag(Optional($0)) }
                    }
                    .onChange(of: terreno) {
                        plantacion = plantaciones.count == 1 ? plantaciones.first : nil
                        plaga = nil
                        etapa = nil
                    }
                    if terreno != nil {
                        if plantaciones.isEmpty {
                            Text("Este terreno no tiene cultivos activos").foregroundStyle(Paleta.textoSecundario)
                        } else {
                            Picker("Cultivo", selection: $plantacion) {
                                Text("Seleccioná un cultivo").tag(Plantacion?.none)
                                ForEach(plantaciones) { Text("\($0.cultivoNombre) · siembra \($0.fechaSiembra.corto)").tag(Optional($0)) }
                            }
                            .onChange(of: plantacion) {
                                plaga = nil
                                etapa = nil
                            }
                        }
                    }
                }
                Section("Tipo de plaga") {
                    if let plantacion {
                        if plagas.isEmpty {
                            Text("No hay plagas registradas para \(plantacion.cultivoNombre)").foregroundStyle(Paleta.textoSecundario)
                        }
                        Picker("Plaga", selection: $plaga) {
                            Text("Seleccioná un tipo de plaga").tag(Plaga?.none)
                            ForEach(plagas) { Text($0.nombre).tag(Optional($0)) }
                        }
                        .onChange(of: plaga) { etapa = nil }
                    } else {
                        Text(terreno == nil ? "Elegí un terreno primero" : "Elegí un cultivo primero").foregroundStyle(Paleta.textoSecundario)
                    }
                }
                Section("Etapa biológica de la plaga") {
                    if let plaga {
                        Picker("Etapa", selection: $etapa) {
                            Text("Seleccioná una etapa").tag(EtapaBiologica?.none)
                            ForEach(ReglasReporte.etapas(de: plaga)) { Text(ReglasReporte.etiqueta(etapa: $0.rawValue)).tag(Optional($0)) }
                        }
                    } else {
                        Text("Elegí una plaga primero").foregroundStyle(Paleta.textoSecundario)
                    }
                }
                Section {
                    Picker("Severidad", selection: $severidad) {
                        ForEach(Severidad.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(severidad.descripcion).font(.caption).foregroundStyle(Paleta.textoSecundario)
                } header: {
                    HStack {
                        Text("Nivel de severidad")
                        Spacer()
                        Button("¿Qué es?", systemImage: "info.circle") { infoSeveridad = true }
                            .labelStyle(.iconOnly)
                    }
                }
                Section("Fecha y hora") {
                    HStack {
                        Text(momento.formatted(.dateTime.day().month(.twoDigits).year().hour().minute().locale(Locale(identifier: "es_AR"))))
                        Spacer()
                        Button("Actualizar hora") { momento = Date() }.buttonStyle(.borderless)
                    }
                    if let terreno {
                        Text(String(format: "Lat: %.4f, Lon: %.4f", terreno.terrenoLatitud, terreno.terrenoLongitud))
                            .font(.caption)
                            .foregroundStyle(Paleta.textoSecundario)
                        Text("Coordenadas del terreno (asignadas automáticamente)").font(.caption2).foregroundStyle(Paleta.textoSecundario)
                    }
                }
                if let error { Section { MensajeEnLinea(texto: error) } }
            }
            .navigationTitle("Nueva Alerta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando { ProgressView() } else { Button("Enviar") { Task { await enviar() } } }
                }
            }
            .alert("¿Qué es el nivel de severidad?", isPresented: $infoSeveridad) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text("Representa la intensidad, grado de infestación o la magnitud del daño causado por la plaga en el terreno monitoreado. Plag-Out las sintetiza para facilitarte la priorización y toma de decisiones rápidamente.")
            }
            .task { if !datos.cargado { await datos.cargar(estado.api) } }
        }
    }

    private func enviar() async {
        guard terreno != nil else { error = "Debes seleccionar un terreno"; return }
        guard let plantacion else { error = "Debes seleccionar un cultivo"; return }
        guard let plaga else { error = "El tipo de plaga es obligatorio"; return }
        guard let etapa else { error = "Elegí la etapa biológica en la que viste la plaga"; return }
        enviando = true
        defer { enviando = false }
        do {
            _ = try await estado.api.crearReporte(NuevoReporte(plantacionId: plantacion.id, plagaId: plaga.id, severidad: severidad, observadoEn: momento, etapa: etapa))
            estado.avisar("Alerta enviada.", esError: false)
            await alGuardar()
            cerrar()
        } catch {
            self.error = error.mensaje
        }
    }
}

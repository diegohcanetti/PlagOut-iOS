import PlagOutCore
import SwiftUI

/// Detalle de un monitoreo con sus tres pestañas, como `MonitoreoDetalleScreen.kt`.
struct MonitoreoDetalleView: View {
    enum Seccion: String, CaseIterable, Identifiable {
        case detalle = "Detalle"
        case ciclos = "Ciclos"
        case tratamientos = "Tratamientos"
        var id: String { rawValue }
    }

    @Environment(AppEstado.self) private var estado
    @State private var modelo: MonitoreoDetalleModelo
    @State private var seccion: Seccion

    init(id: Int, seccion: Seccion = .ciclos) {
        _modelo = State(initialValue: MonitoreoDetalleModelo(id: id))
        _seccion = State(initialValue: seccion)
    }

    var body: some View {
        Group {
            if let monitoreo = modelo.monitoreo {
                ScrollView {
                    VStack(spacing: 14) {
                        Encabezado(monitoreo: monitoreo)
                        Picker("Sección", selection: $seccion) {
                            ForEach(Seccion.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        switch seccion {
                        case .detalle: DetalleSeccion(modelo: modelo)
                        case .ciclos: CiclosSeccion(modelo: modelo)
                        case .tratamientos: TratamientosSeccion(monitoreo: monitoreo)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await modelo.cargar(estado.api) }
            } else if modelo.cargando {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if modelo.noDisponible {
                EstadoVacio(icono: "questionmark.folder", titulo: "No disponible",
                            detalle: "Este monitoreo ya no existe. Puede haberse eliminado desde otro dispositivo.")
            } else {
                EstadoVacio(icono: "wifi.exclamationmark", titulo: "No se pudo cargar el monitoreo.", detalle: modelo.error,
                            boton: "Reintentar", accion: { Task { await modelo.cargar(estado.api) } })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoCampo()
        .navigationTitle("Monitoreo de plaga")
        .navigationBarTitleDisplayMode(.inline)
        .task { await modelo.cargar(estado.api) }
        // Lo que cambió acá (biofix, finalizar, borrar) se ve al volver a las listas.
        .onDisappear { Task { await estado.datos.cargar(estado.api) } }
    }
}

private struct Encabezado: View {
    let monitoreo: Monitoreo

    var body: some View {
        let estilo = EstiloNivel.de(monitoreo)
        Tarjeta {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monitoreo.plagaNombre).font(.title3.weight(.bold)).foregroundStyle(Paleta.texto)
                    if let cientifico = monitoreo.plagaNombreCientifico {
                        Text(cientifico).font(.subheadline).italic().foregroundStyle(Paleta.textoSecundario)
                    }
                    Text("\(monitoreo.cultivoNombre) · \(monitoreo.terrenoNombre)")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                }
                Spacer()
                SelloNivel(estilo: estilo)
            }
            if let inicio = monitoreo.fechaInicio {
                Label("Desde el \(inicio.corto)", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
            }
        }
    }
}

// MARK: Detalle

private struct DetalleSeccion: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    let modelo: MonitoreoDetalleModelo
    @State private var editandoUmbral = false
    @State private var editandoNotas = false
    @State private var confirmarFinalizar = false
    @State private var confirmarEliminar = false

    var body: some View {
        if let monitoreo = modelo.monitoreo {
            VStack(spacing: 14) {
                Tarjeta {
                    Text("Umbral GDD").font(.headline)
                    HStack {
                        Text(monitoreo.umbralRiesgo.map { "\($0)%" } ?? "—")
                            .font(.title.weight(.bold))
                            .foregroundStyle(Paleta.bosque)
                        Spacer()
                        if monitoreo.estaActivo {
                            Button("Ajustar") { editandoUmbral = true }.buttonStyle(.bordered)
                        }
                    }
                    Text(monitoreo.estaActivo ? "Te avisamos al superarlo." : "Umbral con el que se siguió este monitoreo")
                        .font(.caption)
                        .foregroundStyle(Paleta.textoSecundario)
                    Text("Es el porcentaje del camino hacia la eclosión (en grados-día) a partir del cual el ciclo pasa a \"Eclosión cerca\" y te avisamos.")
                        .font(.caption)
                        .foregroundStyle(Paleta.textoSecundario)
                }

                if monitoreo.alertasMlActivas != nil, monitoreo.modeloAlertaMlId != nil {
                    Tarjeta {
                        Toggle(isOn: Binding(
                            get: { monitoreo.alertasMlActivas ?? false },
                            set: { activas in Task { await cambiar(CambiosMonitoreo(alertasMlActivas: activas), al500: "No se pudo actualizar la alerta de brote severo. Intentá de nuevo.", exito: "Preferencia de alertas actualizada.") } }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Alerta de brote severo").font(.headline)
                                Text("El modelo estima capturas elevadas a \(monitoreo.horizonteAlertaMlDias ?? 7) días. La alerta no confirma presencia: revisá el cultivo.")
                                    .font(.caption)
                                    .foregroundStyle(Paleta.textoSecundario)
                            }
                        }
                        .disabled(!monitoreo.estaActivo || modelo.guardando)
                    }
                }

                Tarjeta {
                    HStack {
                        Text("Notas de campaña").font(.headline)
                        Spacer()
                        Button(monitoreo.observaciones == nil ? "Escribir" : "Editar") { editandoNotas = true }
                            .buttonStyle(.bordered)
                    }
                    Text(monitoreo.observaciones ?? "Todavía no escribiste nada")
                        .foregroundStyle(monitoreo.observaciones == nil ? Paleta.textoSecundario : Paleta.texto)
                    Text("Anotá si apareció la plaga, qué tratamiento hiciste y si dio resultado. Lo que escribas acá te va a servir para la próxima campaña.")
                        .font(.caption)
                        .foregroundStyle(Paleta.textoSecundario)
                }

                VStack(spacing: 10) {
                    if monitoreo.estaActivo {
                        Button { confirmarFinalizar = true } label: {
                            Label("Finalizar monitoreo", systemImage: "flag.checkered").frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Paleta.corteza)
                    }
                    Button(role: .destructive) { confirmarEliminar = true } label: {
                        Label("Eliminar monitoreo", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(modelo.guardando)
            }
            .sheet(isPresented: $editandoUmbral) {
                EditorUmbral(inicial: monitoreo.umbralRiesgo ?? 80) { nuevo in
                    await cambiar(CambiosMonitoreo(umbralRiesgo: nuevo), al500: "No se pudo actualizar el umbral. Intentá de nuevo.", exito: "Umbral actualizado.")
                }
            }
            .sheet(isPresented: $editandoNotas) {
                EditorNotas(inicial: monitoreo.observaciones ?? "") { texto in
                    // Cadena vacía (no null) para que el backend distinga "borrar la nota".
                    await cambiar(CambiosMonitoreo(observaciones: texto), al500: "No se pudo guardar la nota. Intentá de nuevo.", exito: "Nota guardada.")
                }
            }
            .confirmationDialog("¿Finalizar este monitoreo?", isPresented: $confirmarFinalizar, titleVisibility: .visible) {
                Button("Finalizar monitoreo", role: .destructive) {
                    Task { _ = await cambiar(CambiosMonitoreo(activo: false), al500: "No se pudo finalizar el monitoreo. Intentá de nuevo.", exito: "Monitoreo finalizado.") }
                }
            } message: {
                Text("Dejás de recibir alertas de esta plaga en este cultivo. Se conservan sus ciclos, predicciones y alertas para consultarlos. No se puede volver a activar.")
            }
            .confirmationDialog("Eliminar monitoreo", isPresented: $confirmarEliminar, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    Task {
                        if let error = await modelo.eliminar(estado.api) {
                            estado.avisar(error)
                        } else {
                            estado.avisar("Monitoreo eliminado.", esError: false)
                            cerrar()
                        }
                    }
                }
            } message: {
                Text("Borra ciclos, predicciones y alertas.")
            }
        }
    }

    /// Devuelve true si salió bien (para cerrar el editor).
    @discardableResult
    private func cambiar(_ cambios: CambiosMonitoreo, al500: String, exito: String) async -> Bool {
        if let error = await modelo.cambiar(estado.api, cambios, al500: al500) {
            estado.avisar(error)
            return false
        }
        estado.avisar(exito, esError: false)
        return true
    }
}

private struct EditorUmbral: View {
    @Environment(\.dismiss) private var cerrar
    @State var valor: Double
    let guardar: (Int) async -> Bool
    @State private var guardando = false

    init(inicial: Int, guardar: @escaping (Int) async -> Bool) {
        _valor = State(initialValue: Double(inicial))
        self.guardar = guardar
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("\(Int(valor))%").font(.system(size: 48, weight: .bold)).foregroundStyle(Paleta.bosque)
                Slider(value: $valor, in: 0...100, step: 1).tint(Paleta.bosque)
                Text("Un umbral más bajo avisa antes, con más anticipación y más falsas alarmas.")
                    .font(.subheadline)
                    .foregroundStyle(Paleta.textoSecundario)
                    .multilineTextAlignment(.center)
                BotonPrincipal(titulo: "Guardar", cargando: guardando) {
                    Task {
                        guardando = true
                        if await guardar(Int(valor)) { cerrar() }
                        guardando = false
                    }
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("Umbral GDD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
        }
        .presentationDetents([.medium])
    }
}

private struct EditorNotas: View {
    @Environment(\.dismiss) private var cerrar
    @State var texto: String
    let guardar: (String) async -> Bool
    @State private var guardando = false

    init(inicial: String, guardar: @escaping (String) async -> Bool) {
        _texto = State(initialValue: inicial)
        self.guardar = guardar
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $texto)
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(Paleta.superficie, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Paleta.divisor))
                    .onChange(of: texto) {
                        if texto.count > MonitoreoDetalleModelo.maxCaracteresNotas {
                            texto = String(texto.prefix(MonitoreoDetalleModelo.maxCaracteresNotas))
                        }
                    }
                Text("\(texto.count)/\(MonitoreoDetalleModelo.maxCaracteresNotas)")
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
                Text("Ej.: no apareció la plaga; apliqué X el 12/2 y funcionó")
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
                BotonPrincipal(titulo: "Guardar", cargando: guardando) {
                    Task {
                        guardando = true
                        if await guardar(texto.trimmingCharacters(in: .whitespacesAndNewlines)) { cerrar() }
                        guardando = false
                    }
                }
                Spacer()
            }
            .padding(20)
            .fondoCampo()
            .navigationTitle("Tu nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
        }
    }
}

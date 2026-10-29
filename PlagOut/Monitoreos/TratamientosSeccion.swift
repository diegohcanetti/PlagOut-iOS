import PlagOutCore
import SwiftUI

/// Tratamientos del monitoreo: conteo antes y después de aplicar, con testigo opcional
/// (`TratamientosTab.kt`). Sin cola offline: sin red se muestra el error y se reintenta.
struct TratamientosSeccion: View {
    @Environment(AppEstado.self) private var estado
    let monitoreo: Monitoreo
    @State private var tratamientos: [Tratamiento] = []
    @State private var cargando = true
    @State private var error: String?
    @State private var editando: Edicion?
    @State private var aEliminar: Tratamiento?

    struct Edicion: Identifiable {
        let id = UUID()
        let original: Tratamiento?
        var conDespues = false
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Contá la plaga antes de aplicar y unos días después. Si dejás una franja sin tratar (testigo) y la contás igual, se calcula la eficacia real; sin testigo, solo la reducción observada.")
                .font(.footnote)
                .foregroundStyle(Paleta.textoSecundario)
            if monitoreo.estaActivo {
                BotonPrincipal(titulo: "Registrar tratamiento") { editando = Edicion(original: nil) }
            }
            if cargando {
                ProgressView().padding(30)
            } else if let error, tratamientos.isEmpty {
                EstadoVacio(icono: "wifi.exclamationmark", titulo: "No se pudieron cargar los tratamientos", detalle: error,
                            boton: "Reintentar", accion: { Task { await cargar() } })
            } else if tratamientos.isEmpty {
                EstadoVacio(icono: "drop", titulo: "Todavía no hay tratamientos en este monitoreo.")
            }
            ForEach(tratamientos) { tratamiento in
                TarjetaTratamiento(
                    tratamiento: tratamiento,
                    alEditar: { editando = Edicion(original: tratamiento) },
                    alCargarDespues: tratamiento.conteoDespues == nil ? { editando = Edicion(original: tratamiento, conDespues: true) } : nil,
                    alEliminar: { aEliminar = tratamiento }
                )
            }
        }
        .task { await cargar() }
        .sheet(item: $editando) { edicion in
            FormularioTratamientoView(monitoreo: monitoreo, original: edicion.original, conDespues: edicion.conDespues) {
                await cargar()
            }
        }
        .confirmationDialog("¿Eliminar este tratamiento?", isPresented: Binding(get: { aEliminar != nil }, set: { if !$0 { aEliminar = nil } }), titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let tratamiento = aEliminar { Task { await eliminar(tratamiento) } }
            }
        } message: {
            Text("Se borran sus conteos y su eficacia. No se puede deshacer.")
        }
    }

    private func cargar() async {
        defer { cargando = false }
        do {
            tratamientos = try await estado.api.tratamientos(monitoreoId: monitoreo.id)
                .sorted { ($0.fechaAplicacion, $0.id) > ($1.fechaAplicacion, $1.id) }
            error = nil
        } catch {
            self.error = error.mensaje
        }
    }

    private func eliminar(_ tratamiento: Tratamiento) async {
        do {
            try await estado.api.eliminarTratamiento(id: tratamiento.id)
            estado.avisar("Tratamiento eliminado.", esError: false)
            await cargar()
        } catch {
            estado.avisar(error.mensaje)
        }
    }
}

private struct TarjetaTratamiento: View {
    let tratamiento: Tratamiento
    let alEditar: () -> Void
    let alCargarDespues: (() -> Void)?
    let alEliminar: () -> Void

    var body: some View {
        let resultado = resultadoDeTratamiento(tratamiento)
        let unidad = UnidadConteo(rawValue: tratamiento.unidadConteo)?.etiqueta ?? tratamiento.unidadConteo
        Tarjeta {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tratamiento.producto).font(.headline)
                    Text("Aplicado el \(tratamiento.fechaAplicacion.corto)")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                }
                Spacer()
                Menu {
                    Button("Editar", systemImage: "pencil", action: alEditar)
                    Button("Eliminar", systemImage: "trash", role: .destructive, action: alEliminar)
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(Paleta.textoSecundario)
                }
            }
            Text("\(formatearConteo(tratamiento.conteoAntes)) \(unidad)"
                 + (tratamiento.conteoDespues.map { " · \(formatearConteo($0)) después" } ?? ""))
                .font(.subheadline)
            if let antes = tratamiento.testigoAntes {
                Text("Testigo: \(formatearConteo(antes)) antes" + (tratamiento.testigoDespues.map { " · \(formatearConteo($0)) después" } ?? ""))
                    .font(.subheadline)
                    .foregroundStyle(Paleta.textoSecundario)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(resultado.titulo).font(.headline).foregroundStyle(colorResultado)
                if let detalle = resultado.detalle {
                    Text(detalle).font(.caption).foregroundStyle(Paleta.textoSecundario)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paleta.crema, in: RoundedRectangle(cornerRadius: 12))
            if let alCargarDespues {
                Button("Cargar conteo posterior", systemImage: "plus.circle", action: alCargarDespues)
                    .buttonStyle(.bordered)
                    .tint(Paleta.bosque)
            }
        }
    }

    private var colorResultado: Color {
        let valor = tratamiento.eficaciaPct ?? tratamiento.reduccionObservadaPct
        guard let valor else { return Paleta.texto }
        return valor < 0 ? Paleta.riesgoAlto : Paleta.bosque
    }
}

/// Alta o edición de un tratamiento. La edición manda solo lo que cambió.
struct FormularioTratamientoView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    let monitoreo: Monitoreo
    let original: Tratamiento?
    let alGuardar: () async -> Void

    @State private var form: FormularioTratamiento
    @State private var errores: [CampoTratamiento: String] = [:]
    @State private var enviando = false
    @State private var error: String?
    /// La clave de idempotencia del alta: un reintento no duplica el tratamiento.
    @State private var clave = UUID().uuidString.lowercased()

    init(monitoreo: Monitoreo, original: Tratamiento?, conDespues: Bool, alGuardar: @escaping () async -> Void) {
        self.monitoreo = monitoreo
        self.original = original
        self.alGuardar = alGuardar
        var form = original.map(FormularioTratamiento.desde) ?? .nuevo(hoy: .hoy())
        if conDespues {
            form.conDespues = true
            if form.fechaConteoDespues == nil { form.fechaConteoDespues = .hoy() }
        }
        _form = State(initialValue: form)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    selectorFecha("Fecha de aplicación", \.fechaAplicacion, error: errores[.fechaAplicacion])
                    VStack(alignment: .leading) {
                        TextField("Ej: Clorantraniliprole", text: $form.producto)
                        if let e = errores[.producto] { Text(e).font(.caption).foregroundStyle(Paleta.riesgoAlto) }
                    }
                }
                Section("Cómo contaste") {
                    Picker("Unidad", selection: $form.unidad) {
                        ForEach(UnidadConteo.allCases) { Text("Individuos \($0.etiqueta)").tag($0) }
                    }
                }
                Section("Antes de aplicar") {
                    campoNumero("Conteo antes", $form.conteoAntes, error: errores[.conteoAntes])
                    selectorFecha("Fecha del conteo", \.fechaConteoAntes, error: errores[.fechaConteoAntes])
                    Toggle("Dejé una franja sin tratar (testigo)", isOn: $form.conTestigo)
                    if form.conTestigo {
                        campoNumero("Testigo antes", $form.testigoAntes, error: errores[.testigoAntes])
                    }
                }
                Section {
                    Toggle("Ya tengo el conteo posterior", isOn: $form.conDespues.animation())
                    if form.conDespues {
                        campoNumero("Conteo después", $form.conteoDespues, error: errores[.conteoDespues])
                        selectorFecha("Fecha del conteo", \.fechaConteoDespues, error: errores[.fechaConteoDespues])
                        if form.conTestigo {
                            campoNumero("Testigo después (opcional)", $form.testigoDespues, error: errores[.testigoDespues])
                        }
                    }
                } header: {
                    Text("Después")
                } footer: {
                    Text(form.conDespues ? "Vacío el testigo: solo reducción observada." : "Si todavía no, lo cargás después desde la tarjeta del tratamiento.")
                }
                if let error { Section { MensajeEnLinea(texto: error) } }
            }
            .navigationTitle(original == nil ? "Registrar tratamiento" : "Editar tratamiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando { ProgressView() } else { Button("Guardar") { Task { await guardar() } } }
                }
            }
        }
    }

    private func campoNumero(_ titulo: String, _ texto: Binding<String>, error: String?) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(titulo) {
                TextField("0", text: texto)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            if let error { Text(error).font(.caption).foregroundStyle(Paleta.riesgoAlto) }
        }
    }

    private func selectorFecha(_ titulo: String, _ campo: WritableKeyPath<FormularioTratamiento, DiaCalendario?>, error: String?) -> some View {
        VStack(alignment: .leading) {
            DatePicker(titulo, selection: Binding(
                get: { (form[keyPath: campo] ?? .hoy()).fecha },
                set: { form[keyPath: campo] = DiaCalendario(fecha: $0) }
            ), in: ...DiaCalendario.hoy().fecha, displayedComponents: .date)
            .environment(\.locale, Locale(identifier: "es_AR"))
            .environment(\.timeZone, DiaCalendario.zonaArgentina)
            if let error { Text(error).font(.caption).foregroundStyle(Paleta.riesgoAlto) }
        }
    }

    private func guardar() async {
        errores = validarTratamiento(form, inicioMonitoreo: monitoreo.fechaInicio, hoy: .hoy())
        guard errores.isEmpty else { return }
        enviando = true
        defer { enviando = false }
        do {
            if let original {
                guard let cambios = cambiosDeTratamiento(original: original, form: form) else {
                    cerrar()
                    return
                }
                _ = try await estado.api.actualizarTratamiento(id: original.id, cambios: cambios)
            } else {
                _ = try await estado.api.registrarTratamiento(monitoreoId: monitoreo.id, form.solicitud(clave: clave))
            }
            estado.avisar("Tratamiento guardado.", esError: false)
            await alGuardar()
            cerrar()
        } catch {
            self.error = error.mensaje
        }
    }
}

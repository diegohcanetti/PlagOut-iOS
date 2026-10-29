import PlagOutCore
import SwiftUI

/// Los ciclos GDD del monitoreo y el registro de biofix (`CiclosUI.kt`, `BiofixScreen.kt`).
struct CiclosSeccion: View {
    @Environment(AppEstado.self) private var estado
    let modelo: MonitoreoDetalleModelo
    @State private var registrandoBiofix = false
    @State private var finalizando: Int?

    var body: some View {
        if let monitoreo = modelo.monitoreo {
            let ciclos = monitoreo.ciclos ?? []
            let numeros = ciclos.numeros
            VStack(spacing: 14) {
                if monitoreo.estaActivo {
                    BotonPrincipal(titulo: monitoreo.esperandoBiofix ? "Registrar biofix" : "Registrar presencia") {
                        registrandoBiofix = true
                    }
                }
                if ciclos.isEmpty {
                    if monitoreo.estaActivo {
                        EstadoVacio(icono: "hourglass", titulo: "Esperando biofix",
                                    detalle: "El conteo de GDD arranca cuando registrás la primera presencia de la plaga.")
                    } else {
                        EstadoVacio(icono: "calendar.badge.exclamationmark", titulo: "No se registraron ciclos para este monitoreo",
                                    detalle: "El monitoreo se finalizó antes de confirmar la presencia de la plaga.")
                    }
                }
                ForEach(monitoreo.ciclosActivos.porProgreso) { ciclo in
                    TarjetaCiclo(
                        ciclo: ciclo, numero: numeros[ciclo.id], monitoreo: monitoreo,
                        finalizando: finalizando == ciclo.id,
                        alFinalizar: monitoreo.puedeFinalizar(ciclo) ? { Task { await archivar(ciclo) } } : nil
                    )
                }
                if !monitoreo.ciclosFinalizados.isEmpty {
                    Text("Ciclos finalizados")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Paleta.textoSecundario)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(monitoreo.ciclosFinalizados.sorted { $0.fechaBiofix > $1.fechaBiofix }) { ciclo in
                        TarjetaCiclo(ciclo: ciclo, numero: numeros[ciclo.id], monitoreo: monitoreo)
                    }
                }
            }
            .sheet(isPresented: $registrandoBiofix) {
                BiofixSheet(monitoreo: monitoreo) { await modelo.cargar(estado.api) }
            }
        }
    }

    private func archivar(_ ciclo: CicloGDD) async {
        finalizando = ciclo.id
        defer { finalizando = nil }
        do {
            _ = try await estado.api.archivarCiclo(id: ciclo.id)
            estado.avisar("Ciclo finalizado.", esError: false)
            await modelo.cargar(estado.api)
        } catch {
            estado.avisar(error.mensaje)
            // 404/409: ya no existe o cambió de estado; se recarga para mostrar el real.
            if error.codigo == 404 || error.codigo == 409 { await modelo.cargar(estado.api) }
        }
    }
}

struct TarjetaCiclo: View {
    let ciclo: CicloGDD
    let numero: Int?
    let monitoreo: Monitoreo
    var finalizando = false
    var alFinalizar: (() -> Void)?

    var body: some View {
        let estilo = ciclo.activo ? EstiloNivel.de(nivel: ciclo.nivelAlerta) : .finalizado
        let objetivo = ciclo.objetivo(delMonitoreo: monitoreo.gddObjetivo)
        Tarjeta {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    SelloNivel(estilo: estilo)
                    Text(numero.map { "Ciclo \($0)" } ?? "Ciclo").font(.headline)
                    Text("Biofix \(ciclo.fechaBiofix.corto)" + (ciclo.estadioBiologico.isEmpty ? "" : " · \(ciclo.estadioBiologico.capitalized)"))
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                }
                Spacer()
                AnilloProgreso(progreso: ciclo.progreso, color: estilo.color, tamano: 62)
            }
            HStack {
                if ciclo.activo {
                    Estadistica(titulo: "GDD actuales", valor: "\(Int(ciclo.acumuladoVisible(objetivo: objetivo)))")
                    Divider().frame(height: 28)
                    Estadistica(titulo: "Objetivo", valor: objetivo.map { "\(Int($0))" } ?? "—")
                    Divider().frame(height: 28)
                    if ciclo.eclosiono {
                        Estadistica(titulo: "Fecha eclosión", valor: ciclo.fechaEclosion?.corto ?? "Sin registrar")
                    } else {
                        Estadistica(titulo: "Al objetivo", valor: ciclo.diasEstimados(objetivoMonitoreo: monitoreo.gddObjetivo).map { "≈ \($0) d" } ?? "—")
                    }
                } else {
                    Estadistica(titulo: "Biofix", valor: ciclo.fechaBiofix.corto)
                    if let eclosion = ciclo.fechaEclosion {
                        Divider().frame(height: 28)
                        Estadistica(titulo: "Fecha eclosión", valor: eclosion.corto)
                    }
                }
            }
            .padding(10)
            .background(Paleta.crema, in: RoundedRectangle(cornerRadius: 14))
            HStack {
                if ciclo.activo, !ciclo.eclosiono {
                    if ciclo.enAlerta(umbralRiesgo: monitoreo.umbralRiesgo) {
                        Label("Superó el umbral", systemImage: "flag.fill").foregroundStyle(Paleta.riesgoAlto)
                    } else if ciclo.diasPendientes > 0 {
                        Label("Cálculo pendiente · \(ciclo.diasPendientes) d", systemImage: "hourglass").foregroundStyle(Paleta.riesgoMedio)
                    } else {
                        Label("En seguimiento", systemImage: "clock").foregroundStyle(Paleta.bosque)
                    }
                }
                Spacer()
                Text("Act. \(ciclo.actualizacionVisible.corto)").foregroundStyle(Paleta.textoSecundario)
            }
            .font(.caption.weight(.medium))
            if let alFinalizar {
                Button(action: alFinalizar) {
                    Group {
                        if finalizando { ProgressView() } else { Text("Finalizar ciclo") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(Paleta.bosque)
                .disabled(finalizando)
            }
        }
    }
}

struct Estadistica: View {
    let titulo: String
    let valor: String

    var body: some View {
        VStack(spacing: 2) {
            Text(valor).font(.headline).foregroundStyle(Paleta.texto)
            Text(titulo).font(.caption2).foregroundStyle(Paleta.textoSecundario)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Registrar una presencia de la plaga adulta (biofix): inicia un ciclo o se suma a uno activo.
struct BiofixSheet: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    let monitoreo: Monitoreo
    let alTerminar: () async -> Void

    @State private var fecha = DiaCalendario.hoy().fecha
    @State private var severidad: Severidad?
    /// nil = sin elegir; -1 = iniciar otro ciclo; un id = asociar a ese ciclo.
    @State private var opcion: Int?
    @State private var enviando = false
    @State private var error: String?

    private var hoy: DiaCalendario { .hoy() }
    private var dia: DiaCalendario { DiaCalendario(fecha: fecha) }
    private var activos: [CicloGDD] { monitoreo.ciclosActivos }
    private var puedeConfirmar: Bool {
        severidad != nil && (activos.isEmpty || opcion != nil) && !enviando
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Al confirmar arranca el conteo de GDD desde la fecha que elijas.")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                    LabeledContent(monitoreo.plagaNombre, value: "\(monitoreo.cultivoNombre) · \(monitoreo.terrenoNombre)")
                }
                Section("Fecha de observación") {
                    DatePicker("Fecha", selection: $fecha, in: rangoFechas, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "es_AR"))
                        .environment(\.timeZone, DiaCalendario.zonaArgentina)
                }
                Section("Severidad de la plaga adulta") {
                    Picker("Severidad", selection: $severidad) {
                        ForEach(Severidad.allCases) { Text($0.rawValue).tag(Optional($0)) }
                    }
                    .pickerStyle(.segmented)
                }
                if activos.isEmpty {
                    Section {
                        Label("Se inicia un ciclo GDD nuevo desde esa fecha.", systemImage: "clock")
                            .foregroundStyle(Paleta.hoja)
                    }
                } else {
                    Section("¿Es la presencia que ya seguís?") {
                        let numeros = (monitoreo.ciclos ?? []).numeros
                        ForEach(activos) { ciclo in
                            Opcion(seleccionada: opcion == ciclo.id, titulo: "Ciclo \(numeros[ciclo.id] ?? ciclo.id)",
                                   detalle: "Biofix \(ciclo.fechaBiofix.corto) · \(Int(ciclo.progreso))%") { opcion = ciclo.id }
                        }
                        Opcion(seleccionada: opcion == -1, titulo: "Iniciar otro ciclo",
                               detalle: "Una presencia distinta, en paralelo a la que ya seguís") { opcion = -1 }
                    }
                }
                if let error {
                    Section { MensajeEnLinea(texto: error) }
                }
            }
            .navigationTitle("Registrar presencia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando { ProgressView() } else {
                        Button("Confirmar") { Task { await confirmar() } }.disabled(!puedeConfirmar)
                    }
                }
            }
        }
    }

    private var rangoFechas: ClosedRange<Date> {
        let inicio = monitoreo.fechaInicio ?? hoy.sumando(dias: -365)
        return inicio.fecha...hoy.fecha
    }

    private func confirmar() async {
        guard let severidad else { return }
        let asociar = !activos.isEmpty && opcion != -1
        let pedido = SolicitudBiofix(
            fechaObservacion: dia,
            accion: asociar ? .asociarCiclo : .iniciarCiclo,
            cicloId: asociar ? opcion : nil,
            confirmarCicloAdicional: !activos.isEmpty && !asociar,
            nivelSeveridad: severidad
        )
        enviando = true
        defer { enviando = false }
        do {
            let resultado = try await estado.api.registrarBiofix(monitoreoId: monitoreo.id, pedido, porDetalle: Errores.biofix)
            estado.avisar(resultado.cicloCreado ? "Biofix registrado: arrancó un ciclo nuevo." : "Presencia registrada en el ciclo.", esError: false)
            await alTerminar()
            cerrar()
        } catch {
            if error.detalle == "biofix_active_cycles_changed" {
                self.error = "Los ciclos activos cambiaron. Volvé a elegir."
                opcion = nil
                await alTerminar()
            } else {
                self.error = error.mensaje
            }
        }
    }
}

private struct Opcion: View {
    let seleccionada: Bool
    let titulo: String
    let detalle: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack {
                Image(systemName: seleccionada ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(seleccionada ? Paleta.bosque : Paleta.textoSecundario)
                VStack(alignment: .leading) {
                    Text(titulo).foregroundStyle(Paleta.texto)
                    Text(detalle).font(.caption).foregroundStyle(Paleta.textoSecundario)
                }
            }
        }
    }
}

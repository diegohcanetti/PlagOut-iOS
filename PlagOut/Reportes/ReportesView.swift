import PlagOutCore
import SwiftUI

/// Las alertas de plaga (reportes): las propias y las de la comunidad cerca de los terrenos
/// (`MisReportesScreen.kt`).
struct ReportesView: View {
    @Environment(AppEstado.self) private var estado
    @State private var ambito: AmbitoReportes = .propios
    @State private var severidad: Severidad?
    @State private var reportes: [Reporte] = []
    @State private var total = 0
    @State private var resumen: ConteoReportes?
    @State private var cargando = false
    @State private var error: String?
    @State private var creando = false

    private static let pagina = 20

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Picker("Ámbito", selection: $ambito) {
                    Text("Mis alertas").tag(AmbitoReportes.propios)
                    Text("Comunidad").tag(AmbitoReportes.comunidad)
                }
                .pickerStyle(.segmented)

                if let resumen { ResumenSeveridad(resumen: resumen, seleccionada: $severidad) }
                if ambito == .comunidad {
                    Label("Hasta \(radioKm) km de tus terrenos", systemImage: "scope")
                        .font(.caption)
                        .foregroundStyle(Paleta.textoSecundario)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if cargando && reportes.isEmpty {
                    ProgressView().padding(40)
                } else if let error, reportes.isEmpty {
                    EstadoVacio(icono: "wifi.exclamationmark", titulo: "No se pudieron cargar las alertas", detalle: error,
                                boton: "Reintentar", accion: { Task { await cargar() } })
                } else if reportes.isEmpty {
                    if ambito == .propios {
                        EstadoVacio(icono: "ant", titulo: severidad == nil ? "No tenés alertas cargadas" : "No hay alertas con severidad '\(severidad!.rawValue)'.",
                                    boton: severidad == nil ? "Crear Alerta" : nil, accion: { creando = true })
                    } else {
                        EstadoVacio(icono: "person.3", titulo: "No hay alertas cerca de tus terrenos",
                                    detalle: "Acá vas a ver lo que reportan otros productores en la zona de tus terrenos.")
                    }
                } else {
                    ForEach(reportes) { reporte in
                        NavigationLink(value: Destino.reporte(reporte.id)) { TarjetaReporte(reporte: reporte) }
                            .buttonStyle(.plain)
                    }
                    if reportes.count < total {
                        Button("Cargar más") { Task { await cargar(siguiente: true) } }
                            .buttonStyle(.bordered)
                            .disabled(cargando)
                    }
                }
            }
            .padding(16)
        }
        .fondoCampo()
        .navigationTitle("Alertas de plagas")
        .barraSuperior()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink(value: RutaCampo.mapaReportes) { Image(systemName: "map") }
                    .accessibilityLabel("Mapa de alertas")
                Button("Nueva Alerta", systemImage: "plus") { creando = true }
            }
        }
        .sheet(isPresented: $creando) {
            NuevoReporteView { await cargar() }
        }
        .refreshable { await cargar() }
        .task(id: "\(ambito)-\(severidad?.rawValue ?? "")") { await cargar() }
    }

    private var radioKm: Int { min(Int((estado.usuario?.radioKm ?? 20).rounded()), 100) }

    private var filtro: PlagOutAPI.FiltroReportes {
        PlagOutAPI.FiltroReportes(distanciaKm: ambito == .comunidad ? radioKm : nil, severidad: severidad)
    }

    private func cargar(siguiente: Bool = false) async {
        cargando = true
        defer { cargando = false }
        do {
            let desde = siguiente ? reportes.count : 0
            let pagina = try await estado.api.reportes(ambito: ambito, filtro: filtro, limite: Self.pagina, desde: desde)
            reportes = siguiente ? reportes + pagina.items.filter { nuevo in !reportes.contains { $0.id == nuevo.id } } : pagina.items
            total = pagina.total
            error = nil
            if !siguiente {
                var sinSeveridad = filtro
                sinSeveridad.severidad = nil
                resumen = try? await estado.api.resumenReportes(ambito: ambito, filtro: sinSeveridad)
            }
        } catch {
            self.error = error.mensaje
        }
    }
}

private struct ResumenSeveridad: View {
    let resumen: ConteoReportes
    @Binding var seleccionada: Severidad?

    var body: some View {
        HStack(spacing: 8) {
            chip(nil, "Todas", resumen.total, Paleta.bosque)
            chip(.alto, "Alto", resumen.alto, Paleta.riesgoAlto)
            chip(.medio, "Medio", resumen.medio, Paleta.riesgoMedio)
            chip(.bajo, "Bajo", resumen.bajo, Paleta.riesgoBajo)
        }
    }

    private func chip(_ severidad: Severidad?, _ titulo: String, _ cantidad: Int, _ color: Color) -> some View {
        let elegido = seleccionada == severidad
        return Button { seleccionada = severidad } label: {
            VStack(spacing: 2) {
                Text("\(cantidad)").font(.headline)
                Text(titulo).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(elegido ? Paleta.textoSobreOscuro : color)
            .background(elegido ? color : color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct TarjetaReporte: View {
    let reporte: Reporte

    var body: some View {
        Tarjeta {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(reporte.plagaNombre).font(.headline).foregroundStyle(Paleta.texto)
                    Text([reporte.terrenoNombre, reporte.cultivoNombre.map { "Cultivo de \($0)" }].compactMap { $0 }.joined(separator: " • "))
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                    if let etapa = reporte.etapaBiologica {
                        Label(ReglasReporte.etiqueta(etapa: etapa), systemImage: "circle.hexagongrid")
                            .font(.caption)
                            .foregroundStyle(Paleta.textoSecundario)
                    }
                    if !reporte.propio, let km = reporte.distanciaKm {
                        Label("A \(ReglasReporte.distancia(km: km)) de tus terrenos", systemImage: "location")
                            .font(.caption)
                            .foregroundStyle(Paleta.textoSecundario)
                    }
                }
                Spacer()
                SelloSeveridad(severidad: reporte.severidad, texto: reporte.nivelSeveridad)
            }
            Text(reporte.observadoEn.formatted(.dateTime.day().month(.twoDigits).year().hour().minute().locale(Locale(identifier: "es_AR"))))
                .font(.caption)
                .foregroundStyle(Paleta.textoSecundario)
        }
    }
}

struct SelloSeveridad: View {
    let severidad: Severidad?
    let texto: String

    var body: some View {
        let color = severidad.map(Self.color) ?? Paleta.riesgoDesconocido
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    static func color(_ severidad: Severidad) -> Color {
        switch severidad {
        case .bajo: Paleta.riesgoBajo
        case .medio: Paleta.riesgoMedio
        case .alto: Paleta.riesgoAlto
        }
    }
}

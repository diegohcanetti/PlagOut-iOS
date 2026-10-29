import PlagOutCore
import SwiftUI

enum FiltroMonitoreos: String, CaseIterable, Identifiable {
    case activos = "Activos"
    case alerta = "En alerta"
    case finalizados = "Finalizados"
    case todos = "Todos"
    var id: String { rawValue }

    func aplicar(_ monitoreos: [Monitoreo]) -> [Monitoreo] {
        let lista: [Monitoreo]
        switch self {
        case .activos: lista = monitoreos.filter(\.estaActivo)
        case .alerta: lista = monitoreos.filter { $0.estaActivo && $0.ciclosEnAlerta > 0 }
        case .finalizados: lista = monitoreos.filter { !$0.estaActivo }
        case .todos: lista = monitoreos
        }
        // Primero lo más urgente, como `OrdenarMonitoreos` de Android: activos, nivel y avance.
        return lista.sorted {
            ($0.estaActivo ? 1 : 0, $0.nivelAlertaEfectivo, $0.cicloVigente?.progreso ?? -1, $0.id)
                > ($1.estaActivo ? 1 : 0, $1.nivelAlertaEfectivo, $1.cicloVigente?.progreso ?? -1, $1.id)
        }
    }
}

struct MonitoreosView: View {
    @Environment(AppEstado.self) private var estado
    @State private var filtro: FiltroMonitoreos = .activos
    @State private var creando = false

    var body: some View {
        let datos = estado.datos
        let filtrados = filtro.aplicar(datos.monitoreos)
        ScrollView {
            LazyVStack(spacing: 12) {
                Picker("Filtro", selection: $filtro) {
                    ForEach(FiltroMonitoreos.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if datos.cargando || (!datos.cargado && datos.error == nil) {
                    ProgressView().padding(40)
                } else if let error = datos.error, !datos.cargado {
                    EstadoVacio(icono: "wifi.exclamationmark", titulo: "No se pudieron cargar los monitoreos", detalle: error,
                                boton: "Reintentar", accion: { Task { await datos.cargar(estado.api) } })
                } else if datos.monitoreos.isEmpty {
                    EstadoVacio(icono: "leaf", titulo: "Sin monitoreos activos",
                                detalle: "Creá un monitoreo para seguir el riesgo de plagas en tus cultivos.",
                                boton: "Nuevo Monitoreo", accion: { creando = true })
                } else if filtrados.isEmpty {
                    EstadoVacio(icono: "line.3.horizontal.decrease.circle", titulo: "No hay monitoreos en este estado.")
                } else {
                    ForEach(filtrados) { monitoreo in
                        NavigationLink(value: Destino.monitoreo(monitoreo.id)) {
                            TarjetaMonitoreo(monitoreo: monitoreo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .fondoCampo()
        .navigationTitle("Mis Monitoreos")
        .barraSuperior()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nuevo Monitoreo", systemImage: "plus") { creando = true }
            }
        }
        .sheet(isPresented: $creando) { NuevoMonitoreoView() }
        .refreshable { await datos.cargar(estado.api) }
        .task { await datos.cargar(estado.api) }
    }
}

struct TarjetaMonitoreo: View {
    let monitoreo: Monitoreo

    var body: some View {
        let estilo = EstiloNivel.de(monitoreo)
        Tarjeta {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(monitoreo.plagaNombre)
                        .font(.headline)
                        .foregroundStyle(Paleta.texto)
                    if let cientifico = monitoreo.plagaNombreCientifico {
                        Text(cientifico).font(.caption).italic().foregroundStyle(Paleta.textoSecundario)
                    }
                    Label("\(monitoreo.cultivoNombre) · \(monitoreo.terrenoNombre)", systemImage: "leaf")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                    SelloNivel(estilo: estilo)
                }
                Spacer(minLength: 0)
                if monitoreo.estaActivo, let ciclo = monitoreo.cicloVigente {
                    AnilloProgreso(progreso: ciclo.progreso, color: estilo.color)
                }
            }
            if monitoreo.estaActivo, monitoreo.ciclosEnAlerta > 0 {
                Text(monitoreo.ciclosEnAlerta == 1 ? "1 ciclo superó el umbral" : "\(monitoreo.ciclosEnAlerta) ciclos superaron el umbral")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Paleta.riesgoAlto)
            }
        }
    }
}

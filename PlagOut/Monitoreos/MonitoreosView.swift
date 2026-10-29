import PlagOutCore
import SwiftUI

@MainActor
@Observable
final class MonitoreosModelo {
    enum Filtro: String, CaseIterable, Identifiable {
        case activos = "Activos"
        case alerta = "En alerta"
        case finalizados = "Finalizados"
        case todos = "Todos"
        var id: String { rawValue }
    }

    var monitoreos: [Monitoreo] = []
    var cargando = false
    var error: String?
    var filtro: Filtro = .activos

    var filtrados: [Monitoreo] {
        let lista: [Monitoreo]
        switch filtro {
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

    func cargar(_ api: PlagOutAPI) async {
        cargando = monitoreos.isEmpty
        defer { cargando = false }
        do {
            monitoreos = try await api.monitoreos()
            error = nil
        } catch {
            self.error = error.mensaje
        }
    }
}

struct MonitoreosView: View {
    @Environment(AppEstado.self) private var estado
    @State private var modelo = MonitoreosModelo()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Picker("Filtro", selection: $modelo.filtro) {
                    ForEach(MonitoreosModelo.Filtro.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if modelo.cargando {
                    ProgressView().padding(40)
                } else if let error = modelo.error, modelo.monitoreos.isEmpty {
                    EstadoVacio(icono: "wifi.exclamationmark", titulo: "No se pudieron cargar los monitoreos", detalle: error,
                                boton: "Reintentar", accion: { Task { await modelo.cargar(estado.api) } })
                } else if modelo.monitoreos.isEmpty {
                    EstadoVacio(icono: "leaf", titulo: "Sin monitoreos activos",
                                detalle: "Creá un monitoreo para seguir el riesgo de plagas en tus cultivos.")
                } else if modelo.filtrados.isEmpty {
                    EstadoVacio(icono: "line.3.horizontal.decrease.circle", titulo: "No hay monitoreos en este estado.")
                } else {
                    ForEach(modelo.filtrados) { monitoreo in
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
        .refreshable { await modelo.cargar(estado.api) }
        .task { await modelo.cargar(estado.api) }
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

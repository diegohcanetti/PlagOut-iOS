import PlagOutCore
import SwiftUI

/// Las pestañas del productor (`BottomNavigationBar` de Android, sin Tableros).
struct PestanasView: View {
    enum Pestanas: Hashable { case monitoreos, terrenos, reportes, perfil }

    @Environment(AppEstado.self) private var estado
    @State private var actual: Pestanas = .monitoreos
    @State private var caminos: [Pestanas: NavigationPath] = [:]

    var body: some View {
        TabView(selection: $actual) {
            Pestana(camino: camino(.monitoreos)) { MonitoreosView() }
                .tabItem { Label("Monitoreos", systemImage: "flask") }
                .tag(Pestanas.monitoreos)
            Pestana(camino: camino(.terrenos)) { PendienteView(titulo: "Terrenos") }
                .tabItem { Label("Terrenos", systemImage: "map") }
                .tag(Pestanas.terrenos)
            Pestana(camino: camino(.reportes)) { PendienteView(titulo: "Reportes") }
                .tabItem { Label("Reportes", systemImage: "ant") }
                .tag(Pestanas.reportes)
            Pestana(camino: camino(.perfil)) { PendienteView(titulo: "Perfil") }
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                .tag(Pestanas.perfil)
        }
        .onChange(of: estado.destinoPendiente, initial: true) { _, destino in
            guard let destino else { return }
            estado.destinoPendiente = nil
            abrir(destino)
        }
    }

    private func camino(_ pestana: Pestanas) -> Binding<NavigationPath> {
        Binding(get: { caminos[pestana] ?? NavigationPath() }, set: { caminos[pestana] = $0 })
    }

    /// Abre un destino en la pestaña que le corresponde.
    func abrir(_ destino: Destino) {
        let pestana: Pestanas = switch destino {
        case .monitoreo, .monitoreos, .prediccion: .monitoreos
        case .reporte, .reportes: .reportes
        case .plantacion, .terrenos: .terrenos
        }
        actual = pestana
        var camino = NavigationPath()
        if destino != .monitoreos, destino != .reportes, destino != .terrenos { camino.append(destino) }
        caminos[pestana] = camino
    }
}

/// Una pestaña con su propia pila de navegación. Los destinos se resuelven acá para que
/// cualquier pantalla (o una notificación) pueda abrir un monitoreo, un reporte, etc.
struct Pestana<Contenido: View>: View {
    @Binding var camino: NavigationPath
    @ViewBuilder let contenido: Contenido

    var body: some View {
        NavigationStack(path: $camino) {
            contenido
                .navigationDestination(for: Destino.self) { destino in
                    switch destino {
                    case .monitoreo(let id): MonitoreoDetalleView(id: id)
                    default: PendienteView(titulo: "Próximamente")
                    }
                }
        }
    }
}

/// Lugar reservado para las pantallas de las próximas etapas.
struct PendienteView: View {
    @Environment(AppEstado.self) private var estado
    let titulo: String

    var body: some View {
        VStack(spacing: 16) {
            EstadoVacio(icono: "hammer", titulo: titulo, detalle: "En construcción.")
            if titulo == "Perfil" {
                Button("Cerrar sesión", role: .destructive) { Task { await estado.cerrarSesion() } }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoCampo()
        .navigationTitle(titulo)
    }
}

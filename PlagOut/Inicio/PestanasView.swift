import PlagOutCore
import SwiftUI

/// Las pestañas del productor (`BottomNavigationBar` de Android, sin Tableros).
struct PestanasView: View {
    var body: some View {
        TabView {
            Pestana { MonitoreosView() }
                .tabItem { Label("Monitoreos", systemImage: "flask") }
            Pestana { PendienteView(titulo: "Terrenos") }
                .tabItem { Label("Terrenos", systemImage: "map") }
            Pestana { PendienteView(titulo: "Reportes") }
                .tabItem { Label("Reportes", systemImage: "ant") }
            Pestana { PendienteView(titulo: "Perfil") }
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }
    }
}

/// Una pestaña con su propia pila de navegación. Los destinos se resuelven acá para que
/// cualquier pantalla (o una notificación) pueda abrir un monitoreo, un reporte, etc.
struct Pestana<Contenido: View>: View {
    @ViewBuilder let contenido: Contenido
    @State private var camino = NavigationPath()

    var body: some View {
        NavigationStack(path: $camino) {
            contenido
                .navigationDestination(for: Destino.self) { destino in
                    switch destino {
                    case .monitoreo(let id): PendienteView(titulo: "Monitoreo \(id)")
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

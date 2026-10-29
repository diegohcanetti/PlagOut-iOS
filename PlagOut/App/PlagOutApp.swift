import SwiftUI

@main
struct PlagOutApp: App {
    @State private var estado = AppEstado()

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(estado)
                .tint(Paleta.bosque)
                .preferredColorScheme(.light)
                .onOpenURL { estado.abrir($0) }
                .task {
                    await estado.arrancar()
                    #if DEBUG
                    // Solo en desarrollo: SIMCTL_CHILD_PLAGOUT_ABRIR=plagout://monitoreo/41 abre esa pantalla.
                    if let link = ProcessInfo.processInfo.environment["PLAGOUT_ABRIR"], let url = URL(string: link) {
                        estado.abrir(url)
                    }
                    #endif
                }
        }
    }
}

/// Decide qué se ve según la sesión.
struct RaizView: View {
    @Environment(AppEstado.self) private var estado

    var body: some View {
        @Bindable var estado = estado
        Group {
            if estado.recuperacion != nil {
                NavigationStack { NuevaPasswordView() }
            } else {
                switch estado.fase {
                case .cargando:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).fondoCampo()
                case .afuera:
                    NavigationStack { LoginView() }
                case .sinConexion:
                    EstadoVacio(
                        icono: "wifi.slash",
                        titulo: "Sin conexión",
                        detalle: "Revisá tu conexión a internet para entrar a tu cuenta.",
                        boton: "Reintentar",
                        accion: { Task { await estado.arrancar() } }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fondoCampo()
                case .adentro:
                    PestanasView()
                case .admin(let usuario):
                    SoloPanelWebView(usuario: usuario)
                }
            }
        }
        .avisoFlotante($estado.aviso)
    }
}

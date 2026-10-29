import PlagOutCore
import SwiftUI

struct LoginView: View {
    @Environment(AppEstado.self) private var estado
    @State private var email = ""
    @State private var password = ""
    @State private var cargando = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .accessibilityLabel("Logo")
                    Text("PLAG-OUT")
                        .font(.largeTitle.weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(Paleta.bosque)
                    Text("Gestión Inteligente de Cultivos")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                }
                .padding(.top, 32)

                Tarjeta {
                    Text("Bienvenido")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Paleta.texto)
                    Text("Ingresá a tu cuenta")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                    CampoTexto(etiqueta: "Correo electrónico", texto: $email, teclado: .emailAddress, contenido: .username)
                        .onChange(of: email) { error = nil }
                    CampoTexto(etiqueta: "Contraseña", texto: $password, seguro: true, contenido: .password)
                        .onChange(of: password) { error = nil }
                    if let error { MensajeEnLinea(texto: error) }
                    BotonPrincipal(titulo: "Iniciar sesión", cargando: cargando, habilitado: !email.isEmpty && !password.isEmpty) {
                        Task { await entrar() }
                    }
                    .padding(.top, 4)
                    NavigationLink("¿Olvidaste tu contraseña?") { RecuperarPasswordView(emailInicial: email) }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 4) {
                    Text("¿No tenés cuenta?").foregroundStyle(Paleta.textoSecundario)
                    NavigationLink("Registrate ahora") { RegistroView() }
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .fondoCampo()
        .toolbar(.hidden, for: .navigationBar)
        #if DEBUG
        // Solo en desarrollo: `simctl launch` con SIMCTL_CHILD_PLAGOUT_DEMO_EMAIL/_PASSWORD entra
        // solo, para probar en el simulador sin tipear.
        .task {
            let entorno = ProcessInfo.processInfo.environment
            if let demo = entorno["PLAGOUT_DEMO_EMAIL"], let clave = entorno["PLAGOUT_DEMO_PASSWORD"], email.isEmpty {
                email = demo
                password = clave
                await entrar()
            }
        }
        #endif
    }

    private func entrar() async {
        cargando = true
        error = await estado.iniciarSesion(email: email, password: password)
        cargando = false
    }
}

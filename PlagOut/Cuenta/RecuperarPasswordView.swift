import PlagOutCore
import SwiftUI

/// Pide el link de recuperación por mail (`RecuperarPasswordScreen.kt`). El link vuelve a la app
/// con `plagout://reset-password` y abre `NuevaPasswordView`.
struct RecuperarPasswordView: View {
    @Environment(AppEstado.self) private var estado
    @State var emailInicial: String
    @State private var email = ""
    @State private var enviado = false
    @State private var cargando = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            Tarjeta {
                if enviado {
                    Label("¡Enlace enviado!", systemImage: "envelope.badge.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Paleta.bosque)
                    Text("Te enviamos un correo a \(email).\n\nAbrí el mensaje en tu teléfono y presioná el enlace para definir tu nueva contraseña directamente en la aplicación.")
                        .foregroundStyle(Paleta.texto)
                    if let error { MensajeEnLinea(texto: error) }
                    BotonPrincipal(titulo: "Reenviar correo", cargando: cargando) { Task { await enviar() } }
                    Button("Usar otro correo electrónico") {
                        enviado = false
                        error = nil
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Ingresá tu correo electrónico registrado y te enviaremos un enlace seguro para restablecer tu contraseña.")
                        .foregroundStyle(Paleta.textoSecundario)
                    CampoTexto(etiqueta: "Correo electrónico", texto: $email, teclado: .emailAddress, contenido: .username)
                        .onChange(of: email) { error = nil }
                    if let error { MensajeEnLinea(texto: error) }
                    BotonPrincipal(titulo: "Enviar enlace", cargando: cargando) { Task { await enviar() } }
                }
            }
            .padding(20)
        }
        .fondoCampo()
        .navigationTitle("Recuperar contraseña")
        .onAppear { if email.isEmpty { email = emailInicial } }
    }

    private func enviar() async {
        guard MensajesAuth.emailValido(email) else {
            error = "Ingresá un correo electrónico válido"
            return
        }
        cargando = true
        defer { cargando = false }
        do {
            try await estado.sesion.enviarRecuperacion(email: email)
            error = nil
            enviado = true
        } catch {
            self.error = error.mensaje
        }
    }
}

/// La nueva contraseña, con la sesión que abrió el link del mail.
struct NuevaPasswordView: View {
    @Environment(AppEstado.self) private var estado
    @State private var nueva = ""
    @State private var repetir = ""
    @State private var cargando = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            Tarjeta {
                switch estado.recuperacion {
                case .abriendo, nil:
                    ProgressView("Abriendo el enlace…").frame(maxWidth: .infinity)
                case .enlaceInvalido:
                    enlaceVencido
                case .nuevaPassword:
                    formulario
                }
            }
            .padding(20)
        }
        .fondoCampo()
        .navigationTitle("Recuperar contraseña")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Volver") {
                    Task {
                        // Con el link abierto, la sesión es la de recuperación: no sirve para entrar.
                        if estado.recuperacion == .nuevaPassword { await estado.cerrarSesion() }
                        estado.terminarRecuperacion()
                    }
                }
            }
        }
    }

    private var formulario: some View {
        Group {
            Text("Establecer nueva contraseña")
                .font(.title3.weight(.bold))
                .foregroundStyle(Paleta.texto)
            Text("Ingresá y confirmá tu nueva contraseña para volver a ingresar a tu cuenta.")
                .foregroundStyle(Paleta.textoSecundario)
            CampoTexto(etiqueta: "Nueva contraseña", texto: $nueva, seguro: true, contenido: .newPassword)
            CampoTexto(etiqueta: "Repetir nueva contraseña", texto: $repetir, seguro: true, contenido: .newPassword)
            if let error { MensajeEnLinea(texto: error) }
            BotonPrincipal(titulo: "Guardar contraseña", cargando: cargando) { Task { await guardar() } }
        }
    }

    private var enlaceVencido: some View {
        Group {
            Label("Enlace no válido o ya utilizado", systemImage: "link.badge.plus")
                .font(.title3.weight(.bold))
                .foregroundStyle(Paleta.riesgoAlto)
            Text("Este enlace para recuperar tu contraseña ya fue utilizado o ha caducado. Por seguridad, cada enlace puede usarse una sola vez.")
                .foregroundStyle(Paleta.texto)
            // Un link vencido no abrió ninguna sesión: se vuelve a donde estaba.
            BotonPrincipal(titulo: "Volver al inicio de sesión") { estado.terminarRecuperacion() }
        }
    }

    private func guardar() async {
        guard nueva.count >= MensajesAuth.passwordMinima else {
            error = "La contraseña debe tener al menos \(MensajesAuth.passwordMinima) caracteres"
            return
        }
        guard nueva == repetir else {
            error = "Las contraseñas no coinciden"
            return
        }
        cargando = true
        defer { cargando = false }
        do {
            try await estado.sesion.restablecerPassword(nueva)
            await estado.cerrarSesion()
            estado.terminarRecuperacion(mensaje: "¡Contraseña restablecida con éxito! Ya podés iniciar sesión.")
        } catch {
            if error.enlaceInvalido {
                estado.recuperacion = .enlaceInvalido(error.mensaje)
            } else {
                self.error = error.mensaje
            }
        }
    }
}

/// Las cuentas admin se administran desde el panel web.
struct SoloPanelWebView: View {
    @Environment(AppEstado.self) private var estado
    let usuario: Usuario

    var body: some View {
        VStack(spacing: 20) {
            Image("Logo").resizable().scaledToFit().frame(height: 90)
            Tarjeta {
                Text("Hola, \(usuario.nombre)")
                    .font(.title3.weight(.bold))
                Text("Las cuentas de administración se usan desde el panel web. La app de iPhone es para productores.")
                    .foregroundStyle(Paleta.textoSecundario)
                Link(destination: Configuracion.panelWeb) {
                    Label("Abrir el panel web", systemImage: "safari")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Paleta.bosque)
                Button("Cerrar sesión", role: .destructive) { Task { await estado.cerrarSesion() } }
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoCampo()
    }
}

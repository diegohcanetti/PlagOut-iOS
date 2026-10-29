import PlagOutCore
import SwiftUI

/// Alta de cuenta: Supabase manda el mail de confirmación y el perfil se crea al primer login
/// (`CrearCuentaScreen.kt`).
struct RegistroView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var apellido = ""
    @State private var cargo: Cargo?
    @State private var cargos: [Cargo] = []
    @State private var email = ""
    @State private var password = ""
    @State private var repetir = ""
    @State private var cargando = false
    @State private var error: String?

    private var passwordCorta: Bool { !password.isEmpty && password.count < MensajesAuth.passwordMinima }
    private var noCoinciden: Bool { !repetir.isEmpty && repetir != password }
    private var completo: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && !apellido.trimmingCharacters(in: .whitespaces).isEmpty
            && cargo != nil && MensajesAuth.emailValido(email) && password.count >= MensajesAuth.passwordMinima && repetir == password
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Completá tus datos profesionales")
                    .font(.subheadline)
                    .foregroundStyle(Paleta.textoSecundario)
                Tarjeta {
                    CampoTexto(etiqueta: "Nombre", texto: $nombre, contenido: .givenName)
                    CampoTexto(etiqueta: "Apellido", texto: $apellido, contenido: .familyName)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cargo").font(.subheadline.weight(.medium)).foregroundStyle(Paleta.textoSecundario)
                        Picker("Cargo", selection: $cargo) {
                            Text("Elegí tu cargo").tag(Cargo?.none)
                            ForEach(cargos) { Text($0.tipo).tag(Optional($0)) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(.horizontal, 6)
                        .background(Paleta.superficie, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Paleta.divisor))
                    }
                    CampoTexto(etiqueta: "Email corporativo", texto: $email, teclado: .emailAddress, contenido: .username)
                    CampoTexto(
                        etiqueta: "Contraseña", texto: $password, seguro: true, contenido: .newPassword,
                        error: passwordCorta ? "Al menos \(MensajesAuth.passwordMinima) caracteres" : nil
                    )
                    CampoTexto(
                        etiqueta: "Repetir contraseña", texto: $repetir, seguro: true, contenido: .newPassword,
                        error: noCoinciden ? "Las contraseñas no coinciden" : nil
                    )
                    if let error { MensajeEnLinea(texto: error) }
                    BotonPrincipal(titulo: "Crear cuenta", cargando: cargando, habilitado: completo) {
                        Task { await crear() }
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .fondoCampo()
        .navigationTitle("Nueva Cuenta")
        .task { await cargarCargos() }
    }

    private func cargarCargos() async {
        do {
            cargos = try await estado.api.cargos()
        } catch {
            self.error = "No se pudieron cargar los cargos"
        }
    }

    private func crear() async {
        guard let cargo else { return }
        cargando = true
        defer { cargando = false }
        do {
            try await estado.sesion.registrar(
                email: email, password: password,
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                apellido: apellido.trimmingCharacters(in: .whitespaces),
                cargoId: cargo.id
            )
            estado.avisar("Te enviamos un correo para confirmar tu cuenta. Confirmala y después iniciá sesión.", esError: false)
            cerrar()
        } catch {
            self.error = error.mensaje
        }
    }
}

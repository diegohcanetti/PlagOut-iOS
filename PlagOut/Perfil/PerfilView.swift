import PlagOutCore
import SwiftUI

/// Mi perfil (`PerfilScreen.kt`): datos, actividad, rango de alertas, consentimiento del modelo,
/// contraseña, ayuda, cerrar sesión y eliminar la cuenta.
struct PerfilView: View {
    static let versionConsentimiento = "report-ml-consent-v1"

    @Environment(AppEstado.self) private var estado
    @State private var consentimiento: ConsentimientoModelo?
    @State private var guardandoConsentimiento = false
    @State private var confirmarConsentimiento: Bool?
    @State private var editando = false
    @State private var ajustandoRadio = false
    @State private var cambiandoPassword = false
    @State private var mostrarAyuda = false
    @State private var eliminandoCuenta = false
    @State private var confirmarSalir = false

    var body: some View {
        let datos = estado.datos
        ScrollView {
            VStack(spacing: 14) {
                if let usuario = estado.usuario {
                    Tarjeta {
                        HStack(spacing: 14) {
                            Text(String(usuario.nombre.prefix(1)) + String(usuario.apellido.prefix(1)))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Paleta.textoSobreOscuro)
                                .frame(width: 60, height: 60)
                                .background(Paleta.bosque, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(usuario.nombreCompleto).font(.title3.weight(.bold))
                                Text(usuario.cargo.isEmpty ? "Sin cargo asignado" : usuario.cargo).foregroundStyle(Paleta.textoSecundario)
                                Text(usuario.email).font(.caption).foregroundStyle(Paleta.textoSecundario)
                            }
                        }
                        Text("Miembro desde el \(usuario.fechaCreacion.corto)").font(.caption).foregroundStyle(Paleta.textoSecundario)
                        Button("Editar perfil", systemImage: "pencil") { editando = true }.buttonStyle(.bordered)
                    }
                    Tarjeta {
                        Text("Tu actividad").font(.headline)
                        HStack {
                            Estadistica(titulo: "Terrenos", valor: "\(datos.terrenos.count)")
                            Divider().frame(height: 28)
                            Estadistica(titulo: "Cultivos activos", valor: "\(datos.plantaciones.filter(\.activa).count)")
                            Divider().frame(height: 28)
                            Estadistica(titulo: "Monitoreos activos", valor: "\(datos.monitoreos.filter(\.estaActivo).count)")
                        }
                    }
                    Tarjeta {
                        Fila(icono: "scope", titulo: "Rango de alerta de plagas", detalle: "\(Int(usuario.radioKm)) km de tus lotes") { ajustandoRadio = true }
                        Divider()
                        consentimientoFila
                    }
                }
                Tarjeta {
                    Fila(icono: "key", titulo: "Cambiar contraseña", detalle: "Elegí una contraseña nueva para tu cuenta") { cambiandoPassword = true }
                    Divider()
                    Fila(icono: "questionmark.circle", titulo: "¿Cómo funciona Plag-Out?", detalle: "Qué hace la app y cómo se usa, en un minuto") { mostrarAyuda = true }
                    Divider()
                    Fila(icono: "rectangle.portrait.and.arrow.right", titulo: "Cerrar sesión", detalle: "Vas a tener que iniciar sesión de nuevo") { confirmarSalir = true }
                }
                Tarjeta {
                    Text("Zona de peligro").font(.headline).foregroundStyle(Paleta.riesgoAlto)
                    Text("Acciones que no se pueden deshacer").font(.caption).foregroundStyle(Paleta.textoSecundario)
                    Button(role: .destructive) { eliminandoCuenta = true } label: {
                        Label("Eliminar cuenta", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(Paleta.riesgoAlto)
                }
                Text("Versión \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") · iPhone")
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
            }
            .padding(16)
        }
        .fondoCampo()
        .navigationTitle("Mi perfil")
        .barraSuperior()
        .refreshable { await recargar() }
        .task {
            await recargar()
            if !datos.cargado { await datos.cargar(estado.api) }
        }
        .sheet(isPresented: $editando) { EditarPerfilView() }
        .sheet(isPresented: $ajustandoRadio) { RadioAlertaView() }
        .sheet(isPresented: $cambiandoPassword) { CambiarPasswordView() }
        .sheet(isPresented: $mostrarAyuda) { AyudaView() }
        .sheet(isPresented: $eliminandoCuenta) { EliminarCuentaView() }
        .confirmationDialog("Cerrar sesión", isPresented: $confirmarSalir, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { Task { await estado.cerrarSesion() } }
        }
        .alert(confirmarConsentimiento == true ? "¿Autorizar uso de reportes?" : "¿Revocar consentimiento?",
               isPresented: Binding(get: { confirmarConsentimiento != nil }, set: { if !$0 { confirmarConsentimiento = nil } })) {
            Button("Cancelar", role: .cancel) {}
            Button(confirmarConsentimiento == true ? "Autorizar" : "Revocar") {
                if let valor = confirmarConsentimiento { Task { await cambiarConsentimiento(valor) } }
            }
        } message: {
            Text(confirmarConsentimiento == true
                 ? "Los reportes que envíes desde ahora podrán usarse para evaluar y mejorar los modelos de riesgo. Tus reportes anteriores no se incluyen. Podés revocarlo cuando quieras."
                 : "Los reportes que envíes después de revocar ya no se usarán para evaluar modelos. El historial ya registrado no se borra. Podés volver a autorizarlo cuando quieras desde tu perfil.")
        }
    }

    private var consentimientoFila: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain").foregroundStyle(Paleta.bosque).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Modelos de riesgo").font(.subheadline.weight(.semibold))
                Text(consentimiento?.consentido == true ? "Aceptado · podés revocarlo cuando quieras" : "Ayudá a que Plag-Out anticipe mejor el riesgo de plagas en tu zona.")
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
            }
            Spacer()
            if guardandoConsentimiento {
                ProgressView()
            } else if let consentimiento {
                Toggle("Consentimiento ML", isOn: Binding(get: { consentimiento.consentido }, set: { confirmarConsentimiento = $0 }))
                    .labelsHidden()
            }
        }
    }

    private func recargar() async {
        if let usuario = try? await estado.api.usuarioActual() { estado.actualizar(usuario: usuario) }
        consentimiento = try? await estado.api.consentimientoModelo()
    }

    private func cambiarConsentimiento(_ valor: Bool) async {
        guardandoConsentimiento = true
        defer { guardandoConsentimiento = false }
        do {
            consentimiento = try await estado.api.actualizarConsentimientoModelo(CambioConsentimiento(consentido: valor, versionContrato: Self.versionConsentimiento))
            estado.avisar(valor ? "Consentimiento registrado." : "Consentimiento revocado.", esError: false)
        } catch {
            estado.avisar(error.mensaje)
        }
    }
}

private struct Fila: View {
    let icono: String
    let titulo: String
    let detalle: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 12) {
                Image(systemName: icono).foregroundStyle(Paleta.bosque).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo).font(.subheadline.weight(.semibold)).foregroundStyle(Paleta.texto)
                    Text(detalle).font(.caption).foregroundStyle(Paleta.textoSecundario)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Paleta.textoSecundario)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Nombre, apellido y cargo (`EditarPerfilScreen.kt`).
private struct EditarPerfilView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var apellido = ""
    @State private var cargo: Cargo?
    @State private var cargos: [Cargo] = []
    @State private var enviando = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $nombre).textContentType(.givenName)
                    TextField("Apellido", text: $apellido).textContentType(.familyName)
                    Picker("Cargo", selection: $cargo) {
                        Text("Sin cargo").tag(Cargo?.none)
                        ForEach(cargos) { Text($0.tipo).tag(Optional($0)) }
                    }
                } header: {
                    Text("Datos personales")
                } footer: {
                    Text("Así te ve el resto del equipo en Plag-Out")
                }
                if let error { Section { MensajeEnLinea(texto: error) } }
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando { ProgressView() } else { Button("Guardar") { Task { await guardar() } } }
                }
            }
            .task {
                if let usuario = estado.usuario {
                    nombre = usuario.nombre
                    apellido = usuario.apellido
                }
                cargos = (try? await estado.api.cargos()) ?? []
                cargo = cargos.first { $0.tipo == estado.usuario?.cargo }
            }
        }
    }

    private func guardar() async {
        let nombre = nombre.trimmingCharacters(in: .whitespaces), apellido = apellido.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty, !apellido.isEmpty else {
            error = "Completá tu nombre y apellido."
            return
        }
        enviando = true
        defer { enviando = false }
        do {
            let usuario = try await estado.api.actualizarUsuario(CambiosUsuario(nombre: nombre, apellido: apellido, cargoId: cargo?.id))
            estado.actualizar(usuario: usuario)
            await estado.sesion.espejarPerfil(nombre: nombre, apellido: apellido, cargoId: cargo?.id)
            estado.avisar("Perfil actualizado.", esError: false)
            cerrar()
        } catch {
            self.error = error.codigo == 500 ? "No se pudieron guardar los cambios. Intentá de nuevo." : error.mensaje
        }
    }
}

/// Distancia a los lotes dentro de la que se avisa de reportes cercanos (5 a 150 km).
private struct RadioAlertaView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    @State private var radio: Double = 20
    @State private var enviando = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Te avisamos cuando se reporten plagas dentro de esta distancia a cualquiera de tus lotes.")
                    .font(.subheadline)
                    .foregroundStyle(Paleta.textoSecundario)
                    .multilineTextAlignment(.center)
                Text("\(Int(radio)) km").font(.system(size: 44, weight: .bold)).foregroundStyle(Paleta.bosque)
                Slider(value: $radio, in: 5...150, step: 5) {
                    Text("Radio")
                } minimumValueLabel: { Text("5 km").font(.caption) } maximumValueLabel: { Text("150 km").font(.caption) }
                    .tint(Paleta.bosque)
                Text(radio <= 20 ? "Solo plagas muy próximas a tus lotes: pocas alertas, todas urgentes."
                     : radio <= 60 ? "Rango equilibrado: te enterás de lo que avanza por la zona con tiempo para actuar."
                     : "Rango amplio: vas a recibir más alertas, incluso de plagas lejanas.")
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
                    .multilineTextAlignment(.center)
                BotonPrincipal(titulo: "Guardar", cargando: enviando) { Task { await guardar() } }
                Spacer()
            }
            .padding(24)
            .navigationTitle("Rango de alerta de plagas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
            .onAppear { radio = estado.usuario?.radioKm ?? 20 }
        }
        .presentationDetents([.medium])
    }

    private func guardar() async {
        enviando = true
        defer { enviando = false }
        do {
            let usuario = try await estado.api.actualizarUsuario(CambiosUsuario(radioNotificacionKm: radio))
            estado.actualizar(usuario: usuario)
            estado.avisar("Rango actualizado.", esError: false)
            cerrar()
        } catch {
            estado.avisar(error.mensaje)
        }
    }
}

private struct CambiarPasswordView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    @State private var actual = ""
    @State private var nueva = ""
    @State private var repetir = ""
    @State private var enviando = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Contraseña actual", text: $actual).textContentType(.password)
                    SecureField("Contraseña nueva", text: $nueva).textContentType(.newPassword)
                    SecureField("Repetir contraseña", text: $repetir).textContentType(.newPassword)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Requisito(texto: "Al menos \(MensajesAuth.passwordMinima) caracteres", cumplido: nueva.count >= MensajesAuth.passwordMinima)
                        Requisito(texto: "Distinta de la contraseña actual", cumplido: !nueva.isEmpty && nueva != actual)
                        Requisito(texto: "Las dos contraseñas coinciden", cumplido: !nueva.isEmpty && nueva == repetir)
                    }
                }
                if let error { Section { MensajeEnLinea(texto: error) } }
            }
            .navigationTitle("Cambiar contraseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando { ProgressView() } else { Button("Guardar") { Task { await guardar() } } }
                }
            }
        }
    }

    private func guardar() async {
        if actual.isEmpty { error = "Ingresá tu contraseña actual"; return }
        if nueva.count < MensajesAuth.passwordMinima { error = "La nueva contraseña debe tener al menos \(MensajesAuth.passwordMinima) caracteres"; return }
        if actual == nueva { error = "La nueva contraseña tiene que ser distinta de la actual"; return }
        if nueva != repetir { error = "Las contraseñas no coinciden"; return }
        enviando = true
        defer { enviando = false }
        do {
            try await estado.sesion.cambiarPassword(actual: actual, nueva: nueva)
            estado.avisar("Contraseña actualizada.", esError: false)
            cerrar()
        } catch {
            self.error = error.mensaje
        }
    }
}

private struct Requisito: View {
    let texto: String
    let cumplido: Bool

    var body: some View {
        Label(texto, systemImage: cumplido ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(cumplido ? Paleta.riesgoBajo : Paleta.textoSecundario)
    }
}

/// Baja de la cuenta: hay que escribir ELIMINAR para confirmar.
private struct EliminarCuentaView: View {
    static let palabra = "ELIMINAR"

    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    @State private var confirmacion = ""
    @State private var enviando = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Se va a borrar") {
                    Label("Tu perfil y tus datos personales", systemImage: "person.crop.circle.badge.xmark")
                    Label("Tus terrenos, cultivos y monitoreos", systemImage: "map")
                    Text("Los reportes de plagas que enviaste se conservan de forma anónima, sin datos que te identifiquen.")
                        .font(.caption)
                        .foregroundStyle(Paleta.textoSecundario)
                }
                Section {
                    TextField(Self.palabra, text: $confirmacion)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Para confirmar, escribí \(Self.palabra)")
                } footer: {
                    Text("Esta acción es permanente y no se puede deshacer.")
                }
                if let error { Section { MensajeEnLinea(texto: error) } }
                Section {
                    Button(role: .destructive) { Task { await eliminar() } } label: {
                        if enviando { ProgressView().frame(maxWidth: .infinity) } else { Text("Eliminar cuenta").frame(maxWidth: .infinity) }
                    }
                    .disabled(confirmacion != Self.palabra || enviando)
                }
            }
            .navigationTitle("¿Eliminar tu cuenta?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
        }
    }

    private func eliminar() async {
        enviando = true
        defer { enviando = false }
        do {
            _ = try await estado.api.eliminarCuenta()
            cerrar()
            await estado.cerrarSesion()
            estado.avisar("Cuenta eliminada.", esError: false)
        } catch {
            self.error = error.mensaje
        }
    }
}

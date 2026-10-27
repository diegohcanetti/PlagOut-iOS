import Auth
import Foundation
import PlagOutCore

/// Error de una operación de cuenta, con el mensaje listo para mostrar.
public struct ErrorDeCuenta: Error, Equatable, Sendable {
    public let mensaje: String
    /// El enlace de recuperación ya no sirve: hay que pedir otro.
    public let enlaceInvalido: Bool

    public init(_ mensaje: String, enlaceInvalido: Bool = false) {
        self.mensaje = mensaje
        self.enlaceInvalido = enlaceInvalido
    }
}

/// Datos con los que se registró la cuenta: el backend crea el perfil con ellos al primer login.
public struct DatosDeRegistro: Sendable, Equatable {
    public let nombre: String
    public let apellido: String
    public let cargoId: Int?
}

/// La sesión de Supabase Auth de la app. Guarda la sesión en el llavero, la renueva sola y le
/// da el token al `APIClient`. Mismo flujo implícito que Android (`SupabaseProvider.kt`): el link
/// de recuperación vuelve con los tokens en el fragmento.
public final class SesionSupabase: ProveedorDeSesion {
    public static let redirectRecuperar = URL(string: "plagout://reset-password")!

    let auth: AuthClient

    public init(supabaseURL: URL, clavePublicable: String) {
        auth = AuthClient(
            url: supabaseURL.appending(path: "auth/v1"),
            headers: ["apikey": clavePublicable],
            flowType: .implicit,
            redirectToURL: Self.redirectRecuperar,
            localStorage: KeychainLocalStorage(service: "ar.plagout.sesion"),
            emitLocalSessionAsInitialSession: true
        )
    }

    // MARK: ProveedorDeSesion

    public func tokenDeAcceso() async -> String? {
        // `session` renueva si hace falta; sin sesión guardada tira error.
        try? await auth.session.accessToken
    }

    public func renovarSesion() async -> Bool {
        (try? await auth.refreshSession()) != nil
    }

    // MARK: Estado

    /// Hay una sesión guardada (puede estar vencida: `tokenDeAcceso` la renueva).
    public var haySesionGuardada: Bool { auth.currentSession != nil }

    public var emailActual: String? { auth.currentUser?.email }

    /// Nombre, apellido y cargo guardados en el registro (`user_metadata`).
    public var datosDeRegistro: DatosDeRegistro? {
        guard let datos = auth.currentUser?.userMetadata else { return nil }
        func texto(_ clave: String) -> String {
            (datos[clave]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let cargo = datos["cargo"]?.stringValue.flatMap { Int($0) } ?? datos["cargo"]?.intValue
        return DatosDeRegistro(nombre: texto("nombre"), apellido: texto("apellido"), cargoId: cargo)
    }

    // MARK: Operaciones

    public func iniciarSesion(email: String, password: String) async throws(ErrorDeCuenta) {
        do {
            try await auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        } catch {
            throw Self.traducir(error, porDefecto: "No se pudo iniciar sesión. Intentá de nuevo.")
        }
    }

    /// Crea la cuenta y manda el mail de confirmación. El perfil del backend se crea al primer login.
    public func registrar(email: String, password: String, nombre: String, apellido: String, cargoId: Int) async throws(ErrorDeCuenta) {
        let respuesta: AuthResponse
        do {
            respuesta = try await auth.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                data: ["nombre": .string(nombre), "apellido": .string(apellido), "cargo": .string(String(cargoId))]
            )
        } catch {
            throw Self.traducir(error, porDefecto: "No se pudo crear la cuenta. Intentá de nuevo.")
        }
        // Con la confirmación por mail activa, Supabase no da error si el correo ya existe:
        // responde con un usuario sin identidades y no crea nada.
        if respuesta.user.identities?.isEmpty == true {
            throw ErrorDeCuenta("Ya existe una cuenta con este correo.")
        }
    }

    public func enviarRecuperacion(email: String) async throws(ErrorDeCuenta) {
        do {
            try await auth.resetPasswordForEmail(email.trimmingCharacters(in: .whitespacesAndNewlines), redirectTo: Self.redirectRecuperar)
        } catch let error as AuthError {
            let mensaje = error.message.lowercased()
            if mensaje.contains("rate limit") || error.errorCode.rawValue.contains("rate_limit") {
                throw ErrorDeCuenta("Demasiadas solicitudes. Esperá unos minutos antes de volver a intentar.")
            }
            throw ErrorDeCuenta("No se pudo procesar la solicitud. Intentá de nuevo.")
        } catch {
            throw ErrorDeCuenta("No se pudo enviar el correo. Verificá tu conexión e intentá de nuevo.")
        }
    }

    /// Abre la sesión de recuperación del link `plagout://reset-password#access_token=…`. Si el link
    /// trae un error (vencido o usado), lo informa.
    public func abrirEnlaceDeRecuperacion(_ url: URL) async throws(ErrorDeCuenta) {
        if Self.errorEnEnlace(url) != nil { throw ErrorDeCuenta(MensajesAuth.enlaceVencido, enlaceInvalido: true) }
        do {
            _ = try await auth.session(from: url)
        } catch {
            throw ErrorDeCuenta(MensajesAuth.enlaceVencido, enlaceInvalido: true)
        }
    }

    /// Guarda la nueva contraseña con la sesión de recuperación y cierra esa sesión.
    public func restablecerPassword(_ nueva: String) async throws(ErrorDeCuenta) {
        do {
            _ = try await auth.update(user: UserAttributes(password: nueva))
        } catch {
            if case AuthError.sessionMissing = error { throw ErrorDeCuenta(MensajesAuth.enlaceVencido, enlaceInvalido: true) }
            if let auth = error as? AuthError, case .api(_, _, _, let respuesta) = auth, [401, 403].contains(respuesta.statusCode) {
                throw ErrorDeCuenta(MensajesAuth.enlaceVencido, enlaceInvalido: true)
            }
            throw Self.traducir(error, porDefecto: "No se pudo cambiar la contraseña. Intentá de nuevo.")
        }
        try? await auth.signOut(scope: .local)
    }

    /// Cambia la contraseña con sesión abierta, verificando antes la actual.
    public func cambiarPassword(actual: String, nueva: String) async throws(ErrorDeCuenta) {
        guard let email = emailActual else {
            throw ErrorDeCuenta("No se pudo identificar tu cuenta. Por favor cerrá sesión y volvé a entrar.")
        }
        do {
            try await auth.signIn(email: email, password: actual)
        } catch {
            if let auth = error as? AuthError, auth.errorCode.rawValue == "invalid_credentials" {
                throw ErrorDeCuenta("La contraseña actual es incorrecta")
            }
            throw Self.traducir(error, porDefecto: "No se pudo cambiar la contraseña. Revisá tu conexión.")
        }
        do {
            _ = try await auth.update(user: UserAttributes(password: nueva))
        } catch {
            throw Self.traducir(error, porDefecto: "No se pudo cambiar la contraseña. Intentá de nuevo.")
        }
    }

    /// Cierra la sesión del dispositivo. Si el servidor no responde, se borra igual la local.
    public func cerrarSesion() async {
        do {
            try await auth.signOut(scope: .local)
        } catch {
            try? await auth.signOut(scope: .local)
        }
    }

    // MARK: Errores

    static func errorEnEnlace(_ url: URL) -> String? {
        var parametros = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let fragmento = url.fragment, let extra = URLComponents(string: "?" + fragmento)?.queryItems {
            parametros += extra
        }
        return parametros.first { $0.name == "error" || $0.name == "error_code" }?.value
    }

    static func traducir(_ error: Error, porDefecto: String) -> ErrorDeCuenta {
        guard let auth = error as? AuthError else {
            return ErrorDeCuenta((error as? URLError) != nil ? ErrorBackend.mensajeSinConexion : ErrorBackend.mensajeGenerico)
        }
        var estado: Int?
        var motivos: [String] = []
        switch auth {
        case .api(_, _, _, let respuesta): estado = respuesta.statusCode
        case .weakPassword(_, let razones): motivos = razones
        default: break
        }
        return ErrorDeCuenta(MensajesAuth.mensaje(codigo: auth.errorCode.rawValue, estado: estado, motivos: motivos, porDefecto: porDefecto))
    }
}

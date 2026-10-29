import Foundation
import Observation
import PlagOutAuth
import PlagOutCore

/// El estado de la app que no es de una pantalla: la sesión, el usuario y los avisos. Sigue el
/// flujo de `MainActivity.kt` y `AuthViewModel.kt` de Android.
@MainActor
@Observable
final class AppEstado {
    enum Fase: Equatable {
        case cargando
        case afuera
        /// No se pudo validar la sesión guardada (sin conexión): se puede reintentar.
        case sinConexion
        case adentro(Usuario)
        /// Las cuentas admin usan el panel web.
        case admin(Usuario)
    }

    /// El link de recuperación de contraseña, mientras se usa.
    enum Recuperacion: Equatable {
        case abriendo
        case nuevaPassword
        case enlaceInvalido(String)
    }

    var fase: Fase = .cargando
    var recuperacion: Recuperacion?
    var aviso: Aviso?
    /// Una pantalla a abrir desde afuera (un link o una notificación); la consume `PestanasView`.
    var destinoPendiente: Destino?

    let sesion: SesionSupabase
    let api: PlagOutAPI
    let datos = DatosCampo()

    init(configuracion: Configuracion = .actual) {
        let sesion = SesionSupabase(supabaseURL: configuracion.supabase, clavePublicable: configuracion.clavePublicable)
        let receptor = ReceptorDeEventos()
        self.sesion = sesion
        api = PlagOutAPI(cliente: APIClient(
            base: configuracion.backend,
            proveedor: sesion,
            alEvento: { evento in Task { @MainActor in receptor.estado?.manejar(evento) } }
        ))
        receptor.estado = self
    }

    var usuario: Usuario? {
        switch fase {
        case .adentro(let usuario), .admin(let usuario): usuario
        default: nil
        }
    }

    func avisar(_ texto: String, esError: Bool = true) {
        aviso = Aviso(texto: texto, esError: esError)
    }

    // MARK: Sesión

    /// Al abrir la app: si hay sesión guardada, se valida contra el backend.
    func arrancar() async {
        guard sesion.haySesionGuardada else {
            fase = .afuera
            return
        }
        do {
            entrar(con: try await api.usuarioActual())
        } catch {
            if error == .sinConexion {
                fase = .sinConexion
            } else if fase == .cargando {
                // 401 sin arreglo (el evento ya cerró la sesión) o perfil inexistente.
                await sesion.cerrarSesion()
                fase = .afuera
                if error.codigo != 401 { avisar(error.mensaje) }
            }
        }
    }

    /// Login con correo y contraseña. El perfil del backend tiene que existir antes de entrar:
    /// sin él, el backend rechaza todo. Devuelve el error para mostrar en el formulario.
    func iniciarSesion(email: String, password: String) async -> String? {
        do {
            try await sesion.iniciarSesion(email: email, password: password)
        } catch {
            return error.mensaje
        }
        switch await prepararPerfil() {
        case .success(let usuario):
            entrar(con: usuario)
            return nil
        case .failure(let mensaje):
            await sesion.cerrarSesion()
            return mensaje.texto
        }
    }

    private struct Rechazo: Error { let texto: String }

    /// Crea el perfil si falta (idempotente en el backend) y lo lee.
    private func prepararPerfil() async -> Result<Usuario, Rechazo> {
        if let datos = sesion.datosDeRegistro, !datos.nombre.isEmpty, !datos.apellido.isEmpty, let cargo = datos.cargoId {
            do {
                _ = try await api.crearUsuario(NuevoUsuario(nombre: datos.nombre, apellido: datos.apellido, cargoId: cargo))
            } catch {
                switch error.codigo {
                case 404: return .failure(Rechazo(texto: MensajesAuth.cuentaEliminada))
                case 403: return .failure(Rechazo(texto: ErrorBackend.mensajeCuentaSuspendida))
                case nil: return .failure(Rechazo(texto: error.mensaje))
                default: return .failure(Rechazo(texto: MensajesAuth.perfilNoDisponible))
                }
            }
        }
        do {
            return .success(try await api.usuarioActual())
        } catch {
            switch error.codigo {
            case 403 where error.detalle == ErrorBackend.detalleCuentaSuspendida:
                return .failure(Rechazo(texto: ErrorBackend.mensajeCuentaSuspendida))
            // 401 con la sesión recién abierta: no hay perfil y no se pudo crear.
            case 401: return .failure(Rechazo(texto: MensajesAuth.perfilIncompleto))
            case nil: return .failure(Rechazo(texto: error.mensaje))
            default: return .failure(Rechazo(texto: MensajesAuth.perfilNoDisponible))
            }
        }
    }

    private func entrar(con usuario: Usuario) {
        fase = usuario.esAdmin ? .admin(usuario) : .adentro(usuario)
    }

    func actualizar(usuario: Usuario) {
        if case .adentro = fase { fase = .adentro(usuario) }
    }

    func cerrarSesion(aviso texto: String? = nil) async {
        await sesion.cerrarSesion()
        datos.vaciar()
        fase = .afuera
        if let texto { avisar(texto) }
    }

    func manejar(_ evento: EventoSesion) {
        guard usuario != nil else { return }
        Task {
            switch evento {
            case .expirada: await cerrarSesion(aviso: ErrorBackend.mensajeSesionExpirada)
            case .cuentaSuspendida: await cerrarSesion(aviso: ErrorBackend.mensajeCuentaSuspendida)
            }
        }
    }

    // MARK: Recuperación de contraseña

    /// `plagout://reset-password#access_token=…` desde el mail de recuperación.
    func abrir(_ url: URL) {
        guard url.scheme == "plagout" else { return }
        // plagout://monitoreo/41, plagout://reporte/7, plagout://prediccion/3
        if let id = Int(url.lastPathComponent) {
            switch url.host {
            case "monitoreo": destinoPendiente = .monitoreo(id)
            case "reporte": destinoPendiente = .reporte(id)
            case "prediccion": destinoPendiente = .prediccion(id)
            default: break
            }
            return
        }
        guard url.host == "reset-password" else { return }
        recuperacion = .abriendo
        Task {
            do {
                try await sesion.abrirEnlaceDeRecuperacion(url)
                recuperacion = .nuevaPassword
            } catch {
                recuperacion = .enlaceInvalido((error as? ErrorDeCuenta)?.mensaje ?? MensajesAuth.enlaceVencido)
            }
        }
    }

    func terminarRecuperacion(mensaje: String? = nil) {
        recuperacion = nil
        if let mensaje { avisar(mensaje, esError: false) }
    }
}

/// Puente para que el cliente HTTP avise a la app sin retenerla.
private final class ReceptorDeEventos: @unchecked Sendable {
    @MainActor weak var estado: AppEstado?
}

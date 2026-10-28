import Foundation

/// Mensajes de los errores de Supabase Auth, los mismos que `mensajeDeErrorAuth` de Android.
public enum MensajesAuth {
    /// Igual que el mínimo configurado en Supabase Auth: el servidor rechaza las más cortas.
    public static let passwordMinima = 12

    public static let enlaceVencido = "El enlace de recuperación ya fue utilizado o ha expirado. Por favor, solicitá uno nuevo."
    public static let perfilNoDisponible = "No pudimos preparar tu cuenta. Intentá de nuevo en unos minutos."
    public static let perfilIncompleto = "A tu cuenta le faltan datos de perfil (nombre, apellido o cargo). Escribinos para completarlos."
    public static let cuentaEliminada = "Esta cuenta fue eliminada y no puede volver a usarse."

    public static func mensaje(codigo: String, estado: Int?, motivos: [String] = [], porDefecto: String) -> String {
        switch codigo {
        case "invalid_credentials": return "Correo o contraseña incorrectos."
        case "email_not_confirmed": return "Confirmá tu correo antes de iniciar sesión."
        case "user_already_exists", "email_exists": return "Ya existe una cuenta con este correo."
        case "email_address_invalid": return "El correo no es válido."
        // Al suspender una cuenta el backend la banea en Supabase Auth.
        case "user_banned": return ErrorBackend.mensajeCuentaSuspendida
        case "same_password": return "La nueva contraseña debe ser distinta a la actual."
        case "weak_password": return passwordDebil(motivos)
        case "reauthentication_needed", "reauthentication_not_valid": return "Por seguridad, volvé a iniciar sesión."
        case "session_not_found", "session_expired": return ErrorBackend.mensajeSesionExpirada
        case "over_request_rate_limit", "over_email_send_rate_limit": return "Demasiados intentos, probá de nuevo en unos minutos."
        default: return estado == 429 ? "Demasiados intentos, probá de nuevo en unos minutos." : porDefecto
        }
    }

    static func passwordDebil(_ motivos: [String]) -> String {
        let requisitos = motivos.compactMap { motivo -> String? in
            switch motivo {
            case "length": "es muy corta"
            case "characters": "tiene que combinar mayúsculas, minúsculas, números y símbolos"
            case "pwned": "apareció en filtraciones conocidas, elegí otra"
            default: nil
            }
        }
        return requisitos.isEmpty ? "La contraseña es demasiado débil." : "La contraseña es demasiado débil: \(requisitos.joined(separator: "; "))."
    }

    /// Un correo con forma válida (como `Patterns.EMAIL_ADDRESS` de Android, sin ser más estricto
    /// que Supabase).
    public static func emailValido(_ email: String) -> Bool {
        let texto = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return texto.range(of: #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    }
}

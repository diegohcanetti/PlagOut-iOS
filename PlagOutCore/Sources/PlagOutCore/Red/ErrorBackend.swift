import Foundation

/// Un error para mostrar: el mensaje ya está en castellano. Mismo criterio que
/// `ErroresBackend.kt` de Android, para que las dos apps digan lo mismo.
public struct ErrorBackend: Error, Equatable, Sendable {
    public let mensaje: String
    public let codigo: Int?
    public let detalle: String?
    /// Errores de validación (422) por campo, con el mensaje de cada uno.
    public let campos: [String: String]

    public init(mensaje: String, codigo: Int? = nil, detalle: String? = nil, campos: [String: String] = [:]) {
        self.mensaje = mensaje
        self.codigo = codigo
        self.detalle = detalle
        self.campos = campos
    }

    public static let mensajeGenerico = "Ocurrió un error, intentá de nuevo."
    public static let mensajeSesionExpirada = "Tu sesión expiró, iniciá sesión de nuevo."
    public static let mensajeSinConexion = "Sin conexión. Revisá tu conexión a internet e intentá de nuevo."
    public static let mensajeDatosInvalidos = "No se pudieron procesar los datos. Intentá de nuevo."
    public static let detalleCuentaSuspendida = "cuenta_suspendida"
    public static let mensajeCuentaSuspendida = "Tu cuenta está suspendida. Contactá al administrador."

    public static let sinConexion = ErrorBackend(mensaje: mensajeSinConexion)
    public static let generico = ErrorBackend(mensaje: mensajeGenerico)

    /// El error de una respuesta HTTP. `porDetalle` traduce el `detail` del backend (con `_` o
    /// espacios, sin distinguir mayúsculas); `porCodigo` pisa el mensaje por código.
    public static func deRespuesta(
        codigo: Int,
        cuerpo: Data,
        retryAfterSegundos: Int? = nil,
        porDetalle: [String: String] = [:],
        porCodigo: [Int: String] = [:]
    ) -> ErrorBackend {
        let json = (try? JSONSerialization.jsonObject(with: cuerpo)) as? [String: Any]
        // slowapi (429 de los listados) responde {"error": "..."} sin detail.
        let detalle = (json?["detail"] as? String) ?? (json?["error"] as? String)

        if let normalizado = detalle?.replacingOccurrences(of: "_", with: " ") {
            // Si coinciden varias claves gana la más larga (la más específica), así el resultado
            // no depende del orden del diccionario.
            let coincidente = porDetalle.keys
                .filter { normalizado.range(of: $0.replacingOccurrences(of: "_", with: " "), options: .caseInsensitive) != nil }
                .max { ($0.count, $1) < ($1.count, $0) }
            if let clave = coincidente {
                return ErrorBackend(mensaje: porDetalle[clave]!, codigo: codigo, detalle: detalle)
            }
        }
        if let mensaje = porCodigo[codigo] {
            return ErrorBackend(mensaje: mensaje, codigo: codigo, detalle: detalle)
        }
        if codigo == 422 {
            let campos = camposInvalidos(json)
            let mensaje = campos.primero?.mensaje ?? mensajeDatosInvalidos
            return ErrorBackend(mensaje: mensaje, codigo: codigo, detalle: detalle, campos: campos.diccionario)
        }
        let mensaje: String
        switch codigo {
        case 401: mensaje = mensajeSesionExpirada
        case 403: mensaje = detalle == detalleCuentaSuspendida ? mensajeCuentaSuspendida : "No tenés permiso para hacer esta operación."
        case 404: mensaje = "No encontramos lo que buscabas. Puede que ya no exista."
        case 413: mensaje = "Los datos enviados son demasiado grandes."
        case 429:
            if let segundos = retryAfterSegundos, segundos > 0 {
                mensaje = "Demasiados intentos, probá de nuevo en \(segundos) segundos."
            } else {
                mensaje = "Demasiados intentos, probá de nuevo en unos segundos."
            }
        case 503: mensaje = "Servicio no disponible momentáneamente. Intentá más tarde."
        default: mensaje = mensajeGenerico
        }
        return ErrorBackend(mensaje: mensaje, codigo: codigo, detalle: detalle)
    }

    private struct CamposOrdenados {
        var lista: [(campo: String, mensaje: String)] = []
        var primero: (campo: String, mensaje: String)? { lista.first }
        var diccionario: [String: String] { Dictionary(lista, uniquingKeysWith: { a, _ in a }) }
    }

    private static func camposInvalidos(_ json: [String: Any]?) -> CamposOrdenados {
        var resultado = CamposOrdenados()
        guard let errores = json?["errors"] as? [[String: Any]] else { return resultado }
        for error in errores {
            // El field puede venir como ruta ("body.nombre"): interesa el último tramo.
            let campo = (error["field"] as? String)?.split(separator: ".").last.map(String.init) ?? ""
            let code = error["code"] as? String ?? ""
            if !resultado.lista.contains(where: { $0.campo == campo }) {
                resultado.lista.append((campo, mensajeDeValidacion(campo: campo, code: code)))
            }
        }
        return resultado
    }

    static func mensajeDeValidacion(campo: String, code: String) -> String {
        guard let nombre = etiquetasCampos[campo] else { return mensajeDatosInvalidos }
        switch code {
        case "fecha_siembra_future": return "La fecha de siembra no puede ser futura."
        case "fecha_siembra_too_old": return "La fecha de siembra no puede ser de hace más de un año."
        case "report_observed_in_future": return "La fecha y hora del celular están adelantadas. Corregilas y volvé a intentar."
        case "report_observed_too_old": return "La alerta no puede ser de hace más de un año."
        case "missing": return "Falta completar \(nombre)."
        case "string_too_short": return "Revisá \(nombre): no puede quedar en blanco."
        case "string_too_long": return "Revisá \(nombre): tiene demasiados caracteres."
        case "greater_than", "greater_than_equal", "less_than", "less_than_equal":
            return campo == "latitud" || campo == "longitud"
                ? "La ubicación tiene que estar dentro de Argentina."
                : "Revisá \(nombre): está fuera del rango permitido."
        case "int_parsing", "float_parsing", "bool_parsing", "date_from_datetime_parsing",
             "date_parsing", "uuid_parsing", "finite_number":
            return "Revisá \(nombre): el valor no es válido."
        default: return mensajeDatosInvalidos
        }
    }

    private static let etiquetasCampos: [String: String] = [
        "nombre": "el nombre",
        "apellido": "el apellido",
        "email": "el correo",
        "cargo_id": "el cargo",
        "area_hectareas": "las hectáreas",
        "latitud": "la ubicación",
        "longitud": "la ubicación",
        "terreno_id": "el terreno",
        "plantacion_id": "la plantación",
        "cultivo_id": "el cultivo",
        "plaga_id": "la plaga",
        "fecha_siembra": "la fecha de siembra",
        "umbral_riesgo": "el umbral de riesgo",
        "radio_notificacion_km": "el radio de notificación",
        "observaciones": "las observaciones",
        "timestamp_ms": "la fecha de la alerta",
    ]
}

/// Traducciones de `detail` por pantalla, las mismas que en Android.
public enum Errores {
    public static let perfil: [String: String] = [
        "cargo_no_encontrado": "El cargo elegido ya no existe. Elegí otro.",
        "email does not match": "El correo no se puede cambiar desde acá.",
    ]

    public static let reporte: [String: String] = [
        "report_plantation_not_found": "No encontramos la plantación.",
        "report_pest_not_compatible": "La plaga no afecta a este cultivo.",
        "report_plantation_location_unavailable": "El terreno no tiene una ubicación válida.",
        "plaga_inactiva": "La plaga ya no está disponible.",
        "etapa_no_corresponde_a_la_plaga": "La etapa elegida no corresponde a esta plaga.",
    ]

    public static let tratamiento: [String: String] = [
        "monitoring_not_found": "El monitoreo ya no existe.",
        "monitoring_inactive": "El monitoreo está finalizado: no admite tratamientos nuevos.",
        "treatment_not_found": "El tratamiento ya no existe.",
        "treatment_application_date_invalid": "La fecha de aplicación tiene que estar entre el inicio del monitoreo y hoy.",
        "treatment_before_count_after_application": "El conteo previo tiene que ser antes de aplicar o el mismo día.",
        "treatment_after_count_date_invalid": "El conteo posterior tiene que ser después de aplicar y no puede ser futuro.",
        "treatment_after_count_incomplete": "Falta la fecha o el valor del conteo posterior.",
        "treatment_control_before_missing": "Falta el conteo previo de la franja sin tratar.",
        "treatment_idempotency_key_reused": "No se pudo registrar el tratamiento. Cargalo de nuevo.",
    ]

    public static let biofix: [String: String] = reporte.merging([
        "monitoring_not_found": "Monitoreo no encontrado.",
        "active_cycle_not_found": "El ciclo no existe.",
        "monitoring_inactive": "El monitoreo o la plantación están finalizados.",
        "cycle_not_active": "Ese ciclo ya no está activo.",
        "biofix_idempotency_key_reused": "No se pudo registrar el biofix. Intentá de nuevo.",
        "biofix_observation_date_invalid": "La fecha debe estar entre el inicio del monitoreo y hoy.",
        "biofix_observation_before_cycle": "La fecha es anterior al inicio del ciclo.",
        "biofix_thermal_parameters_missing": "Esta plaga no tiene datos térmicos configurados.",
    ]) { _, nuevo in nuevo }

    /// Cambios sobre un monitoreo (umbral, notas, alertas, finalizar).
    public static let edicionMonitoreo: [String: String] = [
        "monitoring_finalized": "El monitoreo ya fue finalizado y no puede reactivarse.",
        "ml_alert_model_unavailable": "Esta plaga todavía no tiene un modelo de alertas aprobado.",
    ]

    public static let archivarCiclo: [String: String] = [
        "cycle_not_found": "El ciclo no existe.",
        "cycle_completed": "El ciclo ya se completó.",
        "monitoring_inactive": "El monitoreo o la plantación están finalizados.",
        "cycle_below_risk_threshold": "El ciclo todavía no alcanzó el umbral de riesgo para archivarse.",
    ]
    public static let archivarCicloPorCodigo: [Int: String] = [500: "No se pudo finalizar el ciclo. Intentá de nuevo."]
}

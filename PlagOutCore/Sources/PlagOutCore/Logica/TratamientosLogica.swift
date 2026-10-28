import Foundation

// Mismas reglas y textos que `Tratamientos.kt` de Android: el backend calcula la cifra, la app
// valida antes de mandar y explica el resultado.

public struct FormularioTratamiento: Equatable, Sendable {
    public var fechaAplicacion: DiaCalendario?
    public var producto: String = ""
    public var unidad: UnidadConteo = .porMetroLineal
    public var conteoAntes: String = ""
    public var fechaConteoAntes: DiaCalendario?
    public var conTestigo = false
    public var testigoAntes: String = ""
    public var conDespues = false
    public var conteoDespues: String = ""
    public var fechaConteoDespues: DiaCalendario?
    public var testigoDespues: String = ""

    public init() {}

    public static func nuevo(hoy: DiaCalendario) -> FormularioTratamiento {
        var form = FormularioTratamiento()
        form.fechaAplicacion = hoy
        form.fechaConteoAntes = hoy
        return form
    }

    public static func desde(_ t: Tratamiento) -> FormularioTratamiento {
        var form = FormularioTratamiento()
        form.fechaAplicacion = t.fechaAplicacion
        form.producto = t.producto
        form.unidad = UnidadConteo(rawValue: t.unidadConteo) ?? .porMetroLineal
        form.conteoAntes = formatearConteo(t.conteoAntes)
        form.fechaConteoAntes = t.fechaConteoAntes
        form.conTestigo = t.testigoAntes != nil
        form.testigoAntes = t.testigoAntes.map(formatearConteo) ?? ""
        form.conDespues = t.conteoDespues != nil
        form.conteoDespues = t.conteoDespues.map(formatearConteo) ?? ""
        form.fechaConteoDespues = t.fechaConteoDespues
        form.testigoDespues = t.testigoDespues.map(formatearConteo) ?? ""
        return form
    }

    /// El alta, con los conteos posteriores si ya se cargaron.
    public func solicitud(clave: String = UUID().uuidString.lowercased()) -> SolicitudTratamiento {
        SolicitudTratamiento(
            idempotencyKey: clave,
            fechaAplicacion: fechaAplicacion!,
            producto: producto.trimmingCharacters(in: .whitespacesAndNewlines),
            unidadConteo: unidad.rawValue,
            conteoAntes: leerConteo(conteoAntes) ?? 0,
            fechaConteoAntes: fechaConteoAntes!,
            conteoDespues: conDespues ? leerConteo(conteoDespues) : nil,
            fechaConteoDespues: conDespues ? fechaConteoDespues : nil,
            testigoAntes: conTestigo ? leerConteo(testigoAntes) : nil,
            testigoDespues: conDespues && conTestigo ? leerConteo(testigoDespues) : nil
        )
    }
}

public enum CampoTratamiento: Hashable, Sendable {
    case fechaAplicacion, producto, conteoAntes, fechaConteoAntes, testigoAntes
    case conteoDespues, fechaConteoDespues, testigoDespues
}

let conteoMaximo = 100_000.0
let productoMaximo = 120

/// Acepta coma o punto decimal; nil si no es un número entre 0 y 100.000.
public func leerConteo(_ texto: String) -> Double? {
    let limpio = texto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    guard let valor = Double(limpio), valor.isFinite, (0...conteoMaximo).contains(valor) else { return nil }
    return valor
}

/// "12" para enteros, "12,5" con decimales.
public func formatearConteo(_ valor: Double) -> String {
    if valor.truncatingRemainder(dividingBy: 1) == 0 { return String(Int64(valor)) }
    return String(valor).replacingOccurrences(of: ".", with: ",")
}

/// Las mismas reglas que el backend, para no mandar algo que va a rechazar.
public func validarTratamiento(_ form: FormularioTratamiento, inicioMonitoreo: DiaCalendario?, hoy: DiaCalendario) -> [CampoTratamiento: String] {
    var errores: [CampoTratamiento: String] = [:]
    let conteoInvalido = "Un número entre 0 y 100.000"
    let aplicacion = form.fechaAplicacion
    if let aplicacion {
        if aplicacion > hoy {
            errores[.fechaAplicacion] = "No puede ser futura"
        } else if let inicio = inicioMonitoreo, aplicacion < inicio {
            errores[.fechaAplicacion] = "Es anterior al inicio del monitoreo"
        }
    } else {
        errores[.fechaAplicacion] = "Elegí la fecha"
    }
    let producto = form.producto.trimmingCharacters(in: .whitespacesAndNewlines)
    if producto.isEmpty {
        errores[.producto] = "Ingresá el producto"
    } else if producto.count > productoMaximo {
        errores[.producto] = "Hasta \(productoMaximo) caracteres"
    }
    if leerConteo(form.conteoAntes) == nil { errores[.conteoAntes] = conteoInvalido }
    if let antes = form.fechaConteoAntes {
        if let aplicacion, antes > aplicacion {
            errores[.fechaConteoAntes] = "Tiene que ser antes de aplicar o el mismo día"
        }
    } else {
        errores[.fechaConteoAntes] = "Elegí la fecha"
    }
    if form.conTestigo, leerConteo(form.testigoAntes) == nil { errores[.testigoAntes] = conteoInvalido }

    if form.conDespues {
        if leerConteo(form.conteoDespues) == nil { errores[.conteoDespues] = conteoInvalido }
        if let despues = form.fechaConteoDespues {
            if let aplicacion, despues <= aplicacion {
                errores[.fechaConteoDespues] = "Tiene que ser después de aplicar"
            } else if despues > hoy {
                errores[.fechaConteoDespues] = "No puede ser futura"
            }
        } else {
            errores[.fechaConteoDespues] = "Elegí la fecha"
        }
        // El testigo posterior es opcional: sin él, solo hay reducción observada.
        if form.conTestigo, !form.testigoDespues.trimmingCharacters(in: .whitespaces).isEmpty, leerConteo(form.testigoDespues) == nil {
            errores[.testigoDespues] = conteoInvalido
        }
    }
    return errores
}

/// Solo lo que cambió respecto de `original`, o nil si nada cambió. Quitar el conteo posterior o
/// el testigo manda null explícito, que el backend toma como "deshacer".
public func cambiosDeTratamiento(original: Tratamiento, form: FormularioTratamiento) -> [String: ValorJSON]? {
    let nuevo = form.solicitud(clave: "")
    var cambios: [String: ValorJSON] = [:]
    func texto(_ campo: String, _ valor: String?, _ anterior: String?) {
        if valor != anterior { cambios[campo] = valor.map(ValorJSON.texto) ?? .nulo }
    }
    func numero(_ campo: String, _ valor: Double?, _ anterior: Double?) {
        if valor != anterior { cambios[campo] = valor.map(ValorJSON.numero) ?? .nulo }
    }
    texto("fecha_aplicacion", nuevo.fechaAplicacion.description, original.fechaAplicacion.description)
    texto("producto", nuevo.producto, original.producto)
    texto("unidad_conteo", nuevo.unidadConteo, original.unidadConteo)
    numero("conteo_antes", nuevo.conteoAntes, original.conteoAntes)
    texto("fecha_conteo_antes", nuevo.fechaConteoAntes.description, original.fechaConteoAntes.description)
    numero("conteo_despues", nuevo.conteoDespues, original.conteoDespues)
    texto("fecha_conteo_despues", nuevo.fechaConteoDespues?.description, original.fechaConteoDespues?.description)
    numero("testigo_antes", nuevo.testigoAntes, original.testigoAntes)
    numero("testigo_despues", nuevo.testigoDespues, original.testigoDespues)
    return cambios.isEmpty ? nil : cambios
}

public struct ResultadoTratamiento: Equatable, Sendable {
    public let titulo: String
    public let detalle: String?
}

private func porcentaje(_ valor: Double) -> String {
    formatearConteo((valor * 10).rounded() / 10) + " %"
}

private let motivoSinTestigo = [
    "falta_testigo_despues": "Falta el conteo posterior de la franja sin tratar.",
    "testigo_antes_cero": "La franja sin tratar no tenía plaga antes de aplicar.",
    "testigo_despues_cero": "La franja sin tratar quedó sin plaga.",
]

public func resultadoDeTratamiento(_ t: Tratamiento) -> ResultadoTratamiento {
    if t.metodo == "henderson_tilton", let eficacia = t.eficaciaPct {
        return ResultadoTratamiento(
            titulo: eficacia < 0 ? "Sin efecto: la plaga aumentó frente al testigo" : "Eficacia: \(porcentaje(eficacia))",
            detalle: "Henderson-Tilton: compara con la franja sin tratar y descuenta lo que la población cambió sola."
        )
    }
    if t.metodo == "reduccion_observada", let reduccion = t.reduccionObservadaPct {
        let motivo = t.sinCalculo.flatMap { motivoSinTestigo[$0] }.map { "\($0) " } ?? ""
        return ResultadoTratamiento(
            titulo: reduccion < 0 ? "La plaga aumentó un \(porcentaje(-reduccion))" : "Reducción observada: \(porcentaje(reduccion))",
            detalle: motivo + "Incluye la mortalidad natural: para medir la eficacia hace falta una franja sin tratar."
        )
    }
    if t.sinCalculo == "conteo_antes_cero" {
        return ResultadoTratamiento(titulo: "Sin plaga antes de aplicar", detalle: "No se puede calcular una reducción.")
    }
    return ResultadoTratamiento(titulo: "Falta el conteo posterior", detalle: "Cargalo unos días después de aplicar.")
}

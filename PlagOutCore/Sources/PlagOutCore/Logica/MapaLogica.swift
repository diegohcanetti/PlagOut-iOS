import Foundation

// Lo que el mapa de alertas pide y cómo muestra lo que vuelve, fuera de la vista para poder testearlo.

extension PlagOutAPI.AreaMapa {
    /// La latitud máxima que acepta `/mapa/reportes`.
    public static let latitudMaxima = 85.0

    /// El área que acepta el backend para lo que muestra la pantalla, a partir de las esquinas del
    /// rectángulo visible (no del centro ± medio span: el mapa es Mercator y el centro de la pantalla
    /// no está a mitad de camino entre el norte y el sur). Latitudes dentro de ±85 y longitudes dentro
    /// de ±180. Si la vista cruza el antimeridiano se pide todo el ancho: una sola consulta
    /// no puede expresar los dos tramos sin perder una parte visible.
    public static func visible(norte: Double, oeste: Double, sur: Double, este: Double) -> PlagOutAPI.AreaMapa {
        func latitud(_ valor: Double) -> Double {
            valor.isFinite ? min(max(valor, -latitudMaxima), latitudMaxima) : 0
        }
        var desde = -180.0, hasta = 180.0
        if (0..<360).contains(este - oeste) {
            // El mapa puede estar corrido una o más vueltas: el oeste vuelve a [-180, 180).
            let desplazamiento = ((oeste + 180) / 360).rounded(.down) * 360
            let esteNormalizado = este - desplazamiento
            if esteNormalizado <= 180 {
                desde = oeste - desplazamiento
                hasta = esteNormalizado
            }
        }
        let a = latitud(norte), b = latitud(sur)
        return .init(sur: min(a, b), oeste: desde, norte: max(a, b), este: hasta)
    }
}

/// Uno o más reportes en la misma posición. Los ajenos llegan al centro de su celda de 0,1°, así
/// que varios comparten coordenadas: en un solo pin todos se pueden abrir.
public struct PinMapa: Identifiable, Sendable {
    public let latitud: Double
    public let longitud: Double
    public let reportes: [Reporte]

    public var id: String { reportes.map { String($0.id) }.joined(separator: "-") }
    /// Todos son del usuario: su ubicación es exacta.
    public var propio: Bool { reportes.allSatisfy(\.propio) }
    /// La severidad más alta del pin, para su color.
    public var severidadMaxima: String? {
        let orden = ["Bajo": 1, "Medio": 2, "Alto": 3]
        return reportes.map(\.nivelSeveridad).max { (orden[$0] ?? 0) < (orden[$1] ?? 0) }
    }
}

/// Separación en pantalla de lo que dibuja el mapa. Las distancias van en unidades Mercator: el
/// ancho del mundo es 1, así que una separación en puntos se pasa con `puntos * mundoPorPunto`.
public enum SeparacionMapa {
    /// Posición Mercator (x, y) en [0, 1].
    public static func mercator(latitud: Double, longitud: Double) -> (x: Double, y: Double) {
        let s = sin(min(max(latitud, -85.05112878), 85.05112878) * .pi / 180)
        return ((longitud + 180) / 360, 0.5 - log((1 + s) / (1 - s)) / (4 * .pi))
    }

    static func distancia(_ a: (latitud: Double, longitud: Double), _ b: (latitud: Double, longitud: Double)) -> Double {
        let p = mercator(latitud: a.latitud, longitud: a.longitud), q = mercator(latitud: b.latitud, longitud: b.longitud)
        return hypot(p.x - q.x, p.y - q.y)
    }

    /// Junta los elementos que quedarían a menos de `minimo`: el de más peso absorbe al vecino y la
    /// unión se repite hasta que no quede ningún par encimado (cada unión mueve el centro).
    static func juntar<T>(
        _ elementos: [T], minimo: Double,
        posicion: (T) -> (latitud: Double, longitud: Double), peso: (T) -> Int, unir: (T, T) -> T
    ) -> [T] {
        guard minimo > 0 else { return elementos }
        var actuales = elementos
        var unio = true
        while unio {
            unio = false
            var separados: [T] = []
            // Orden estable: por peso y, a igual peso, por orden de llegada.
            for elemento in actuales.enumerated().sorted(by: { peso($0.element) != peso($1.element) ? peso($0.element) > peso($1.element) : $0.offset < $1.offset }).map(\.element) {
                if let i = separados.firstIndex(where: { distancia(posicion($0), posicion(elemento)) < minimo }) {
                    separados[i] = unir(separados[i], elemento)
                    unio = true
                } else {
                    separados.append(elemento)
                }
            }
            actuales = separados
        }
        return actuales
    }

    /// Los índices de los lotes que no quedan debajo de un grupo o pin. En Android el grupo se
    /// dibuja encima del lote; MapKit decide el orden solo, así que el lote tapado no se dibuja.
    public static func lotesLibres(
        _ lotes: [(latitud: Double, longitud: Double)],
        marcas: [(latitud: Double, longitud: Double)],
        minimo: Double
    ) -> [Int] {
        lotes.indices.filter { i in !marcas.contains { distancia($0, lotes[i]) < minimo } }
    }
}

extension ReportesMapa {
    /// Los grupos del servidor, unidos los que quedarían a menos de `minimo` (unidades Mercator):
    /// dos grupos de celdas vecinas pueden caer pegados, uno a cada lado del borde.
    public func gruposSeparados(minimo: Double) -> [GrupoReportesMapa] {
        SeparacionMapa.juntar(
            grupos ?? [], minimo: minimo,
            posicion: { ($0.latitud, $0.longitud) }, peso: \.cantidad,
            unir: { a, b in
                let total = a.cantidad + b.cantidad
                let orden = ["Bajo": 1, "Medio": 2, "Alto": 3]
                return GrupoReportesMapa(
                    latitud: (a.latitud * Double(a.cantidad) + b.latitud * Double(b.cantidad)) / Double(total),
                    longitud: (a.longitud * Double(a.cantidad) + b.longitud * Double(b.cantidad)) / Double(total),
                    cantidad: total,
                    // Una severidad conocida manda sobre la desconocida.
                    severidadMax: (orden[a.severidadMax ?? ""] ?? 0) >= (orden[b.severidadMax ?? ""] ?? 0) ? a.severidadMax ?? b.severidadMax : b.severidadMax
                )
            }
        )
    }

    /// Los pines, unidos los que quedarían a menos de `minimo`: todos sus reportes se abren desde el menú.
    public func pinesSeparados(minimo: Double) -> [PinMapa] {
        SeparacionMapa.juntar(
            pines, minimo: minimo,
            posicion: { ($0.latitud, $0.longitud) }, peso: \.reportes.count,
            unir: { a, b in
                let na = Double(a.reportes.count), nb = Double(b.reportes.count)
                return PinMapa(
                    latitud: (a.latitud * na + b.latitud * nb) / (na + nb),
                    longitud: (a.longitud * na + b.longitud * nb) / (na + nb),
                    reportes: a.reportes + b.reportes
                )
            }
        )
    }

    /// Los reportes con coordenadas, juntos los que comparten posición, en el orden en que llegaron.
    public var pines: [PinMapa] {
        var orden: [String] = []
        var porPosicion: [String: (Double, Double, [Reporte])] = [:]
        for reporte in reportes ?? [] {
            guard let lat = reporte.latitud, let lon = reporte.longitud else { continue }
            let clave = String(format: "%.6f,%.6f", lat, lon)
            if porPosicion[clave] == nil {
                orden.append(clave)
                porPosicion[clave] = (lat, lon, [])
            }
            porPosicion[clave]?.2.append(reporte)
        }
        return orden.compactMap { porPosicion[$0] }.map { PinMapa(latitud: $0.0, longitud: $0.1, reportes: $0.2) }
    }

    /// Cuántas alertas hay en la zona: el total del backend o, si no vino, lo que se cuenta.
    public var totalEnZona: Int {
        total ?? (reportes?.count ?? grupos?.map(\.cantidad).reduce(0, +) ?? 0)
    }
}

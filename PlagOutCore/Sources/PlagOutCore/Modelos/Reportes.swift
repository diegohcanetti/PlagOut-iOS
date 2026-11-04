import Foundation

public struct NuevoReporte: Encodable, Sendable {
    public let plantacionId: Int
    public let plagaId: Int
    public let nivelSeveridad: String
    public let timestampMs: Int64
    public let etapaBiologica: String?

    public init(plantacionId: Int, plagaId: Int, severidad: Severidad, observadoEn: Date, etapa: EtapaBiologica?) {
        self.plantacionId = plantacionId
        self.plagaId = plagaId
        self.nivelSeveridad = severidad.rawValue
        self.timestampMs = Int64((observadoEn.timeIntervalSince1970 * 1000).rounded())
        self.etapaBiologica = etapa?.rawValue
    }
}

public struct ReporteCreado: Decodable, Sendable {
    public let id: Int
    public let plantacionId: Int?
    public let plagaId: Int
    public let nivelSeveridad: String
    public let latitud: Double?
    public let longitud: Double?
    public let timestampMs: Int64
}

public struct Reporte: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let plantacionId: Int?
    public let plagaId: Int
    public let plagaNombre: String
    public let terrenoNombre: String?
    public let cultivoNombre: String?
    public let etapaBiologica: String?
    public let nivelSeveridad: String
    public let latitud: Double?
    public let longitud: Double?
    public let timestampMs: Int64
    public let creadoEn: String?
    public let esPropio: Bool?
    public let terrenoMasCercanoId: Int?
    public let distanciaKm: Double?

    public var propio: Bool { esPropio ?? true }
    public var severidad: Severidad? { Severidad(rawValue: nivelSeveridad) }
    public var observadoEn: Date { Date(timeIntervalSince1970: Double(timestampMs) / 1000) }
}

public struct ConteoReportes: Codable, Hashable, Sendable {
    public let total: Int
    public let alto: Int
    public let medio: Int
    public let bajo: Int
}

/// `ambito` de los listados de reportes.
public enum AmbitoReportes: String, Sendable, CaseIterable {
    case propios
    case comunidad
}

/// Lo que devuelve el mapa: grupos con zoom lejano o reportes sueltos de cerca. Puede
/// responder grupos aunque se hayan pedido reportes (demasiados en la vista).
///
/// Un reporte o grupo que no se puede leer (le falta un campo obligatorio, trae un tipo
/// inesperado) se descarta y se cuenta en `descartados`: el resto del mapa se muestra igual.
/// Si lo que falla es la respuesta misma (`reportes` no es una lista), falla entera.
public struct ReportesMapa: Decodable, Sendable {
    public let nivel: String?
    public let grupos: [GrupoReportesMapa]?
    public let reportes: [Reporte]?
    public let total: Int?
    public let cultivos: [String]?
    /// Cuántos elementos de `grupos` y `reportes` vinieron y no se pudieron leer.
    public let descartados: Int

    private enum CodingKeys: String, CodingKey {
        case nivel, grupos, reportes, total, cultivos
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nivel = try c.decodeIfPresent(String.self, forKey: .nivel)
        total = try c.decodeIfPresent(Int.self, forKey: .total)
        cultivos = try c.decodeIfPresent([String].self, forKey: .cultivos)
        var descartados = 0
        grupos = try Self.legibles(GrupoReportesMapa.self, en: c, clave: .grupos, descartados: &descartados)
        reportes = try Self.legibles(Reporte.self, en: c, clave: .reportes, descartados: &descartados)
        self.descartados = descartados
    }

    private static func legibles<T: Decodable>(
        _: T.Type, en c: KeyedDecodingContainer<CodingKeys>, clave: CodingKeys, descartados: inout Int
    ) throws -> [T]? {
        guard try c.contains(clave) && !c.decodeNil(forKey: clave) else { return nil }
        var lista = try c.nestedUnkeyedContainer(forKey: clave)
        var leidos: [T] = []
        while !lista.isAtEnd {
            if let elemento = try? lista.decode(T.self) {
                leidos.append(elemento)
            } else {
                // Un decode fallido no avanza el contenedor: se consume el elemento para seguir.
                _ = try lista.decode(Salteado.self)
                descartados += 1
            }
        }
        return leidos
    }

    private struct Salteado: Decodable {
        init(from decoder: Decoder) throws {}
    }
}

public struct GrupoReportesMapa: Decodable, Hashable, Sendable {
    public let latitud: Double
    public let longitud: Double
    public let cantidad: Int
    public let severidadMax: String?

    public init(latitud: Double, longitud: Double, cantidad: Int, severidadMax: String?) {
        self.latitud = latitud
        self.longitud = longitud
        self.cantidad = cantidad
        self.severidadMax = severidadMax
    }
}

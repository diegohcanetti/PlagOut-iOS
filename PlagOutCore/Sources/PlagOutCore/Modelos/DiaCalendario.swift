import Foundation

/// Una fecha sin hora, como `LocalDate` en Android: el backend la manda como "2026-10-27".
/// Los días agrícolas se cuentan en hora de Argentina (`api/gdd_dates.agricultural_today`).
public struct DiaCalendario: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let anio: Int
    public let mes: Int
    public let dia: Int

    public init(anio: Int, mes: Int, dia: Int) {
        self.anio = anio
        self.mes = mes
        self.dia = dia
    }

    public init?(_ texto: String) {
        // Acepta también un datetime ("2026-10-27T10:00:00"): interesa solo el día.
        let partes = texto.prefix(10).split(separator: "-")
        guard partes.count == 3,
              let anio = Int(partes[0]), let mes = Int(partes[1]), let dia = Int(partes[2]),
              (1...12).contains(mes), (1...31).contains(dia) else { return nil }
        self.init(anio: anio, mes: mes, dia: dia)
    }

    public static let zonaArgentina = TimeZone(identifier: "America/Argentina/Buenos_Aires")!

    static var calendario: Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = zonaArgentina
        return calendario
    }

    /// El día de hoy en Argentina, que es el que usa el backend para validar fechas.
    public static func hoy(_ ahora: Date = Date()) -> DiaCalendario {
        DiaCalendario(fecha: ahora)
    }

    public init(fecha: Date) {
        let c = Self.calendario.dateComponents([.year, .month, .day], from: fecha)
        self.init(anio: c.year!, mes: c.month!, dia: c.day!)
    }

    /// Mediodía de ese día en Argentina: sirve para los selectores de fecha sin saltos por zona.
    public var fecha: Date {
        Self.calendario.date(from: DateComponents(year: anio, month: mes, day: dia, hour: 12))!
    }

    public func sumando(dias: Int) -> DiaCalendario {
        DiaCalendario(fecha: Self.calendario.date(byAdding: .day, value: dias, to: fecha)!)
    }

    public func dias(hasta otro: DiaCalendario) -> Int {
        Self.calendario.dateComponents([.day], from: fecha, to: otro.fecha).day!
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", anio, mes, dia)
    }

    /// "27/10/2026", como lo muestra la app Android.
    public var corto: String {
        String(format: "%02d/%02d/%04d", dia, mes, anio)
    }

    public static func < (a: DiaCalendario, b: DiaCalendario) -> Bool {
        (a.anio, a.mes, a.dia) < (b.anio, b.mes, b.dia)
    }

    public init(from decoder: Decoder) throws {
        let texto = try decoder.singleValueContainer().decode(String.self)
        guard let dia = DiaCalendario(texto) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Fecha inválida: \(texto)"))
        }
        self = dia
    }

    public func encode(to encoder: Encoder) throws {
        var contenedor = encoder.singleValueContainer()
        try contenedor.encode(description)
    }
}

/// Fecha y hora del backend: con zona ("2026-10-27T10:00:00+00:00", "…Z") o sin ella. Sin
/// zona se toma como UTC, que es como las guarda el backend.
public enum FechaHora {
    public static func leer(_ texto: String) -> Date? {
        let conFraccion = ISO8601DateFormatter()
        conFraccion.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let simple = ISO8601DateFormatter()
        simple.formatOptions = [.withInternetDateTime]
        if let fecha = conFraccion.date(from: texto) ?? simple.date(from: texto) { return fecha }
        return conFraccion.date(from: texto + "Z") ?? simple.date(from: texto + "Z")
    }
}

import Foundation

/// Respuesta paginada `{"items": [...], "total": N}`. También acepta un arreglo suelto, como el
/// deserializador de `RetrofitClient.kt`.
public struct Pagina<T: Decodable & Sendable>: Decodable, Sendable {
    public let items: [T]
    public let total: Int

    public init(items: [T], total: Int) {
        self.items = items
        self.total = total
    }

    private enum Claves: String, CodingKey { case items, total }

    public init(from decoder: Decoder) throws {
        if let lista = try? decoder.singleValueContainer().decode([T].self) {
            self.init(items: lista, total: lista.count)
            return
        }
        let c = try decoder.container(keyedBy: Claves.self)
        let items = try c.decodeIfPresent([T].self, forKey: .items) ?? []
        self.init(items: items, total: try c.decodeIfPresent(Int.self, forKey: .total) ?? items.count)
    }
}

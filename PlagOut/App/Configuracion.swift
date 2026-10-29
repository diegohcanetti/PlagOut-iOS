import Foundation

/// Las URLs y la clave publicable, que vienen de `Config.xcconfig` a través del Info.plist. Si
/// falta alguna, la app no arranca: mejor un error claro que pegarle a otro proyecto.
struct Configuracion {
    let backend: URL
    let supabase: URL
    let clavePublicable: String

    static let actual: Configuracion = {
        func valor(_ clave: String) -> String {
            guard let texto = Bundle.main.object(forInfoDictionaryKey: clave) as? String,
                  !texto.isEmpty, !texto.hasPrefix("$(") else {
                fatalError("Falta \(clave) en Config.xcconfig")
            }
            return texto
        }
        func url(_ clave: String) -> URL {
            let texto = valor(clave)
            guard texto.hasPrefix("https://"), let url = URL(string: texto) else {
                fatalError("\(clave) tiene que ser una URL https: \(texto)")
            }
            return url
        }
        return Configuracion(
            backend: url("PlagOutBackendURL"),
            supabase: url("PlagOutSupabaseURL"),
            clavePublicable: valor("PlagOutSupabaseKey")
        )
    }()

    static let panelWeb = URL(string: "https://plag-out-admin.vercel.app")!
}

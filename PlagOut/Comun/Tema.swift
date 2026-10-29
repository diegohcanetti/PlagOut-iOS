import SwiftUI

/// Paleta "Plag-Out" de la app Android (`ui/theme/Color.kt`): verdes de cultivo, tierras y cremas.
enum Paleta {
    static let bosque = Color(hex: 0x264A2B)
    static let bosqueOscuro = Color(hex: 0x17301B)
    static let hoja = Color(hex: 0x4C7A3D)
    static let hojaClara = Color(hex: 0x8FBF74)
    static let musgo = Color(hex: 0xA8C68F)

    static let sol = Color(hex: 0xDCA23A)
    static let terracota = Color(hex: 0xC1712F)
    static let corteza = Color(hex: 0x8A6B4F)
    static let cortezaClara = Color(hex: 0xC9AE8C)

    static let crema = Color(hex: 0xF6F1E4)
    static let cremaProfunda = Color(hex: 0xECE3CC)
    static let superficie = Color(hex: 0xFFFDF7)

    static let texto = Color(hex: 0x2A2318)
    static let textoSecundario = Color(hex: 0x7A705F)
    static let textoSobreOscuro = Color(hex: 0xF6F1E4)

    static let riesgoBajo = Color(hex: 0x4C8C4A)
    static let riesgoMedio = Color(hex: 0xC1861F)
    static let riesgoAlto = Color(hex: 0xAD4531)
    static let riesgoDesconocido = Color(hex: 0xA79A85)

    static let divisor = Color(hex: 0xE4D9BE)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

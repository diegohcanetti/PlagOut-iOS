import SwiftUI

/// Botón principal: verde bosque, ancho completo y con spinner mientras trabaja.
struct BotonPrincipal: View {
    let titulo: String
    var cargando = false
    var habilitado = true
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            ZStack {
                Text(titulo.uppercased())
                    .font(.headline)
                    .tracking(0.8)
                    .opacity(cargando ? 0 : 1)
                if cargando { ProgressView().tint(Paleta.textoSobreOscuro) }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Paleta.bosque)
        .clipShape(Capsule())
        .disabled(cargando || !habilitado)
    }
}

/// Campo de texto con etiqueta arriba y error abajo, como los de Android.
struct CampoTexto: View {
    let etiqueta: String
    @Binding var texto: String
    var seguro = false
    var teclado: UIKeyboardType = .default
    var contenido: UITextContentType?
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(etiqueta)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Paleta.textoSecundario)
            Group {
                if seguro {
                    SecureField(etiqueta, text: $texto)
                } else {
                    TextField(etiqueta, text: $texto)
                        .keyboardType(teclado)
                }
            }
            .textContentType(contenido)
            .textInputAutocapitalization(teclado == .emailAddress ? .never : .sentences)
            .autocorrectionDisabled(teclado == .emailAddress || seguro)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Paleta.superficie, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(error == nil ? Paleta.divisor : Paleta.riesgoAlto, lineWidth: 1)
            )
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Paleta.riesgoAlto)
            }
        }
    }
}

/// Tarjeta crema con borde suave: el contenedor de casi todo en la app.
struct Tarjeta<Contenido: View>: View {
    @ViewBuilder let contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { contenido }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Paleta.superficie, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Paleta.divisor, lineWidth: 1))
    }
}

/// Mensaje de error o de éxito dentro de un formulario.
struct MensajeEnLinea: View {
    let texto: String
    var esError = true

    var body: some View {
        Label(texto, systemImage: esError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(esError ? Paleta.riesgoAlto : Paleta.riesgoBajo)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background((esError ? Paleta.riesgoAlto : Paleta.riesgoBajo).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Estado vacío o de error de una lista, con un botón opcional.
struct EstadoVacio: View {
    let icono: String
    let titulo: String
    var detalle: String?
    var boton: String?
    var accion: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icono)
                .font(.system(size: 44))
                .foregroundStyle(Paleta.cortezaClara)
            Text(titulo)
                .font(.headline)
                .foregroundStyle(Paleta.texto)
            if let detalle {
                Text(detalle)
                    .font(.subheadline)
                    .foregroundStyle(Paleta.textoSecundario)
                    .multilineTextAlignment(.center)
            }
            if let boton, let accion {
                Button(boton, action: accion)
                    .buttonStyle(.bordered)
                    .tint(Paleta.bosque)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// Aviso flotante (el `Avisos` de Android): aparece arriba unos segundos.
struct Aviso: Equatable, Identifiable {
    let id = UUID()
    let texto: String
    var esError = true
}

struct AvisoFlotante: ViewModifier {
    @Binding var aviso: Aviso?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let aviso {
                Text(aviso.texto)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Paleta.textoSobreOscuro)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(aviso.esError ? Paleta.riesgoAlto : Paleta.bosque, in: Capsule())
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: aviso.id) {
                        try? await Task.sleep(for: .seconds(4))
                        withAnimation { self.aviso = nil }
                    }
                    .onTapGesture { withAnimation { self.aviso = nil } }
            }
        }
        .animation(.spring(duration: 0.3), value: aviso)
    }
}

extension View {
    func avisoFlotante(_ aviso: Binding<Aviso?>) -> some View {
        modifier(AvisoFlotante(aviso: aviso))
    }

    /// Fondo crema de las pantallas.
    func fondoCampo() -> some View {
        background(Paleta.crema.ignoresSafeArea())
    }
}

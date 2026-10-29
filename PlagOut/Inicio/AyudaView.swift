import SwiftUI

/// "¿Cómo funciona Plag-Out?" con los mismos textos que `ComoFuncionaSheet.kt`.
struct AyudaView: View {
    @Environment(\.dismiss) private var cerrar

    private let pasos: [(icono: String, titulo: String, texto: String)] = [
        ("map", "Cargá tus terrenos", "Nombre, hectáreas y ubicación en el mapa: de ahí sale el clima con el que se calcula todo lo demás."),
        ("leaf", "Agregá tus cultivos", "Qué cultivo sembraste en ese terreno y en qué fecha."),
        ("flask", "Iniciá monitoreos", "Elegí la plaga que querés seguir y el umbral de riesgo a partir del cual querés que te avisemos."),
        ("ant", "Confirmá la presencia de la plaga", "Si notás presencia no aislada de insectos adultos, se trata de un biofix, informalo para iniciar el acumulador de grados días. Nuestro modelo de Inteligencia Artificial busca predecir biofix, si recibís una alerta confirmala o negala."),
        ("exclamationmark.bubble", "Creá alertas", "Registrá lo que ves a campo: plaga, etapa biológica, severidad, ubicación y fecha. Queda un registro de lo que pasó y notifica a usuarios cercanos."),
        ("bell", "Recibí notificaciones", "Te avisamos si el desarrollo de un monitoreo supera tu umbral, si detectamos un posible biofix y si crean alertas cercanas a vos."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Plag-Out te ayuda a anticipar el riesgo de plagas en tus cultivos:")
                        .foregroundStyle(Paleta.textoSecundario)
                    ForEach(Array(pasos.enumerated()), id: \.offset) { indice, paso in
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle().fill(Paleta.bosque.opacity(0.12)).frame(width: 40, height: 40)
                                Image(systemName: paso.icono).foregroundStyle(Paleta.bosque)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(indice + 1). \(paso.titulo)").font(.headline)
                                Text(paso.texto).font(.subheadline).foregroundStyle(Paleta.textoSecundario)
                            }
                        }
                    }
                    Tarjeta {
                        Text("¿Qué es el biofix?").font(.headline)
                        Text("El biofix es el punto de partida del conteo: la fecha desde la que empezamos a acumular GDD para una plaga, marcada por un hecho biológico concreto —típicamente la primera aparición de adultos en la zona—. Todo el riesgo que ves se cuenta desde ahí: si el biofix se corre, se corre también el pronóstico.")
                            .font(.subheadline)
                        Text("Chicharrita del maíz: hoy podemos avisarte con unos 14 días de margen antes de que aparezcan los adultos. Es una estimación, no una garantía: el clima y la población de la zona pueden adelantarla o atrasarla.")
                            .font(.subheadline)
                            .foregroundStyle(Paleta.textoSecundario)
                    }
                    Tarjeta {
                        Text("Niveles de alerta").font(.headline)
                        Text("El nivel de alerta dice en qué etapa está la plaga según el calor acumulado y, con eso, cuándo conviene recorrer el lote.")
                            .font(.subheadline)
                        ForEach([-1, 0, 1, 2], id: \.self) { nivel in
                            let estilo = EstiloNivel.de(nivel: nivel)
                            VStack(alignment: .leading, spacing: 4) {
                                SelloNivel(estilo: estilo)
                                Text(estilo.descripcion).font(.caption)
                                if !estilo.recomendacion.isEmpty {
                                    Text(estilo.recomendacion).font(.caption).foregroundStyle(Paleta.textoSecundario)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .fondoCampo()
            .navigationTitle("¿Cómo funciona Plag-Out?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { cerrar() } } }
        }
    }
}

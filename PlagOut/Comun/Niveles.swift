import PlagOutCore
import SwiftUI

/// Cómo se ve cada nivel de alerta (`estiloDeNivel` en `CampoUI.kt`).
struct EstiloNivel: Equatable {
    let color: Color
    let etiqueta: String
    let icono: String
    var descripcion = ""
    var recomendacion = ""

    static func de(nivel: Int) -> EstiloNivel {
        switch nivel {
        case ..<0:
            EstiloNivel(color: Paleta.riesgoDesconocido, etiqueta: "Sin datos", icono: "questionmark.circle",
                        descripcion: "Todavía no hay monitoreos con datos suficientes para estimar la etapa.")
        case 0:
            EstiloNivel(color: Paleta.riesgoBajo, etiqueta: "En huevo", icono: "checkmark.circle.fill",
                        descripcion: "Según los grados-día acumulados, la plaga todavía está en huevo y falta para la eclosión.",
                        recomendacion: "Seguí el monitoreo con la frecuencia habitual.")
        case 1:
            EstiloNivel(color: Paleta.riesgoMedio, etiqueta: "Eclosión cerca", icono: "exclamationmark.triangle.fill",
                        descripcion: "Pasó tu umbral de aviso: la eclosión estimada está cerca.",
                        recomendacion: "Planificá recorrer el lote en los próximos días.")
        default:
            EstiloNivel(color: Paleta.riesgoAlto, etiqueta: "Eclosionó", icono: "exclamationmark.octagon.fill",
                        descripcion: "Según el modelo térmico ya eclosionaron: puede haber larvas o ninfas chicas en el lote.",
                        recomendacion: "Recorré el lote y contá. Las larvas chicas son las más sensibles al control; si aplicar o no se decide con el umbral de daño de tu cultivo.")
        }
    }

    /// Un monitoreo finalizado prevalece por sobre su nivel de alerta.
    static let finalizado = EstiloNivel(color: Paleta.corteza, etiqueta: "Finalizado", icono: "flag.fill",
                                        descripcion: "El monitoreo se cerró: ya no se calculan los grados-día ni se envían alertas.")

    static let esperandoBiofix = EstiloNivel(color: Paleta.textoSecundario, etiqueta: "Esperando biofix", icono: "hourglass",
                                             descripcion: "El monitoreo está activo pero todavía no arrancó ningún ciclo: el conteo empieza con el biofix.")

    static func de(_ monitoreo: Monitoreo) -> EstiloNivel {
        if !monitoreo.estaActivo { return .finalizado }
        if monitoreo.esperandoBiofix { return .esperandoBiofix }
        return .de(nivel: monitoreo.nivelAlertaEfectivo)
    }
}

/// Sello con ícono y etiqueta del nivel.
struct SelloNivel: View {
    let estilo: EstiloNivel

    var body: some View {
        Label(estilo.etiqueta, systemImage: estilo.icono)
            .font(.caption.weight(.semibold))
            .foregroundStyle(estilo.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(estilo.color.opacity(0.12), in: Capsule())
    }
}

/// Anillo de avance del ciclo hacia la eclosión.
struct AnilloProgreso: View {
    let progreso: Double
    let color: Color
    var tamano: CGFloat = 54

    var body: some View {
        ZStack {
            Circle().stroke(Paleta.cremaProfunda, lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(progreso / 100, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progreso.rounded()))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(Paleta.texto)
        }
        .frame(width: tamano, height: tamano)
    }
}

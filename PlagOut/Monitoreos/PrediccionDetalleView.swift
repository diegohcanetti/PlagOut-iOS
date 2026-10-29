import PlagOutCore
import SwiftUI

/// Una alerta del modelo y su verificación (`PrediccionDetalleScreen.kt`). Responder "presente"
/// registra además un biofix.
struct PrediccionDetalleView: View {
    @Environment(AppEstado.self) private var estado
    let id: Int
    @State private var prediccion: Prediccion?
    @State private var monitoreo: Monitoreo?
    @State private var cargando = true
    @State private var noDisponible = false
    @State private var error: String?
    @State private var enviando = false
    @State private var registrandoPresencia = false

    var body: some View {
        Group {
            if let prediccion {
                ScrollView {
                    VStack(spacing: 14) {
                        Tarjeta {
                            Label("Alerta predictiva", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Paleta.riesgoAlto)
                            Text("Riesgo de capturas elevadas").font(.title3.weight(.bold))
                            Text(prediccion.plagaNombreCientifico).italic().foregroundStyle(Paleta.textoSecundario)
                            if let monitoreo {
                                Text("\(monitoreo.cultivoNombre) · \(monitoreo.terrenoNombre)").foregroundStyle(Paleta.textoSecundario)
                            }
                            HStack {
                                Estadistica(titulo: "Probabilidad", valor: String(format: "%.0f %%", prediccion.probabilidadPorcentaje))
                                Divider().frame(height: 28)
                                Estadistica(titulo: "Umbral", valor: String(format: "%.0f %%", prediccion.umbralEfectivoPorcentaje ?? prediccion.umbralModeloRecomendadoPorcentaje))
                                Divider().frame(height: 28)
                                Estadistica(titulo: "Fecha", valor: prediccion.fecha.corto)
                            }
                            Text("Estimación a \(prediccion.horizonDays) días. No confirma presencia ni enfermedad: revisá el cultivo.")
                                .font(.caption)
                                .foregroundStyle(Paleta.textoSecundario)
                        }
                        verificacion(prediccion)
                        if let error { MensajeEnLinea(texto: error) }
                    }
                    .padding(16)
                }
            } else if cargando {
                ProgressView()
            } else if noDisponible {
                EstadoVacio(icono: "questionmark.folder", titulo: "Esta predicción no está disponible.",
                            detalle: "Puede no existir o pertenecer a otra cuenta.")
            } else {
                EstadoVacio(icono: "wifi.exclamationmark", titulo: "No pudimos cargar la predicción.", detalle: error,
                            boton: "Volver a cargar", accion: { Task { await cargar() } })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoCampo()
        .navigationTitle("Alerta predictiva")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
        .sheet(isPresented: $registrandoPresencia) {
            if let monitoreo, let prediccion {
                BiofixSheet(monitoreo: monitoreo, enviar: { biofix throws(ErrorBackend) in
                    _ = try await estado.api.confirmarPrediccion(id: prediccion.id, ConfirmacionPrediccion(respuesta: "presente", biofix: biofix, idempotencyKey: biofix.idempotencyKey), porDetalle: Errores.biofix)
                    return "Respuesta registrada"
                }, alTerminar: { await cargar() })
            }
        }
    }

    @ViewBuilder
    private func verificacion(_ prediccion: Prediccion) -> some View {
        let confirmacion = prediccion.confirmacion
        Tarjeta {
            switch confirmacion.estado {
            case "pendiente":
                Text("¿Pudiste verificar la presencia de la plaga?").font(.headline)
                if let expira = confirmacion.expiraEn.flatMap(FechaHora.leer) {
                    Text("Vigente hasta: \(DiaCalendario(fecha: expira).corto)").font(.caption).foregroundStyle(Paleta.textoSecundario)
                }
                BotonPrincipal(titulo: "Sí, está presente", habilitado: monitoreo != nil && !enviando) { registrandoPresencia = true }
                Button("Revisé y no la observé") { Task { await responder("no_observada") } }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity).disabled(enviando)
                Button("No pude verificar") { Task { await responder("no_verificada") } }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity).disabled(enviando)
                if enviando { ProgressView("Enviando…").frame(maxWidth: .infinity) }
                Text("No observarla o no verificarla no confirma ausencia ni significa que el modelo sea incorrecto.")
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
            case "respondida":
                Label("Respuesta registrada", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(Paleta.riesgoBajo)
                Text(textoRespuesta(confirmacion.respuesta)).foregroundStyle(Paleta.textoSecundario)
            case "vencida":
                Label("La solicitud venció", systemImage: "clock.badge.xmark").font(.headline).foregroundStyle(Paleta.corteza)
                Text("El período para responder esta alerta ya terminó.").foregroundStyle(Paleta.textoSecundario)
            default:
                Label("No requiere respuesta", systemImage: "info.circle").font(.headline)
                Text("Esta predicción no tiene una verificación pendiente.").foregroundStyle(Paleta.textoSecundario)
            }
        }
    }

    private func textoRespuesta(_ respuesta: String?) -> String {
        switch respuesta {
        case "presente": "Confirmaste que la plaga está presente."
        case "no_observada": "Revisaste y no la observaste."
        case "no_verificada": "No pudiste verificarla."
        default: ""
        }
    }

    private func cargar() async {
        defer { cargando = false }
        do {
            let leida = try await estado.api.prediccion(id: id)
            prediccion = leida
            noDisponible = false
            if let monitoreoId = leida.monitoreoId { monitoreo = try? await estado.api.monitoreo(id: monitoreoId) }
        } catch {
            if error.codigo == 404 { noDisponible = true } else { self.error = error.mensaje }
        }
    }

    private func responder(_ respuesta: String) async {
        guard let prediccion else { return }
        enviando = true
        defer { enviando = false }
        do {
            _ = try await estado.api.confirmarPrediccion(id: prediccion.id, ConfirmacionPrediccion(respuesta: respuesta))
            estado.avisar("Respuesta guardada", esError: false)
            error = nil
            await cargar()
        } catch {
            switch error.codigo {
            case 404: noDisponible = true; self.prediccion = nil
            case 422: self.error = "La aplicación no pudo enviar una respuesta válida. Actualizala e intentá nuevamente."
            default: self.error = error.mensaje
            }
        }
    }
}

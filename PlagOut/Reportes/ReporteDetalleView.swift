import MapKit
import PlagOutCore
import SwiftUI

/// Detalle de una alerta (`VerReporteScreen.kt`). Las propias se pueden eliminar.
struct ReporteDetalleView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    let id: Int
    @State private var reporte: Reporte?
    @State private var cargando = true
    @State private var error: String?
    @State private var confirmarEliminar = false
    @State private var eliminando = false

    var body: some View {
        Group {
            if let reporte {
                ScrollView {
                    VStack(spacing: 14) {
                        if let lat = reporte.latitud, let lon = reporte.longitud {
                            let punto = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            Map(initialPosition: .region(MKCoordinateRegion(center: punto, span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)))) {
                                Marker(reporte.plagaNombre, systemImage: "ant.fill", coordinate: punto)
                                    .tint(reporte.severidad.map(SelloSeveridad.color) ?? Paleta.riesgoDesconocido)
                            }
                            .mapStyle(.hybrid(elevation: .flat))
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        Tarjeta {
                            HStack {
                                Text(reporte.propio ? "Tu alerta" : "Alerta comunidad")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Paleta.textoSecundario)
                                Spacer()
                                SelloSeveridad(severidad: reporte.severidad, texto: reporte.nivelSeveridad)
                            }
                            Text(reporte.plagaNombre).font(.title3.weight(.bold))
                            Fila(titulo: "Etapa biológica", valor: reporte.etapaBiologica.map { ReglasReporte.etiqueta(etapa: $0) } ?? "No especificado")
                            Fila(titulo: "Fecha y hora", valor: reporte.observadoEn.formatted(.dateTime.day().month(.twoDigits).year().hour().minute().locale(Locale(identifier: "es_AR"))))
                            if reporte.propio {
                                Fila(titulo: "Terreno asignado", valor: reporte.terrenoNombre ?? "Terreno no especificado")
                            } else if let km = reporte.distanciaKm {
                                Fila(titulo: "Terreno más cercano", valor: (estado.datos.terreno(reporte.terrenoMasCercanoId ?? -1)?.terrenoNombre).map { "\($0) · a \(ReglasReporte.distancia(km: km))" } ?? "A \(ReglasReporte.distancia(km: km))")
                            }
                            if let cultivo = reporte.cultivoNombre { Fila(titulo: "Cultivo", valor: cultivo) }
                            if let lat = reporte.latitud, let lon = reporte.longitud {
                                Fila(titulo: "Ubicación", valor: String(format: "Lat: %.4f · Lon: %.4f", lat, lon))
                            } else {
                                Fila(titulo: "Ubicación", valor: "Sin coordenadas registradas")
                            }
                        }
                        if reporte.propio {
                            Button(role: .destructive) { confirmarEliminar = true } label: {
                                Label(eliminando ? "Eliminando alerta..." : "Eliminar alerta", systemImage: "trash")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .tint(Paleta.riesgoAlto)
                            .disabled(eliminando)
                        }
                    }
                    .padding(16)
                }
            } else if cargando {
                ProgressView()
            } else {
                EstadoVacio(icono: "questionmark.folder", titulo: "No se pudo cargar la alerta", detalle: error,
                            boton: "Reintentar", accion: { Task { await cargar() } })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoCampo()
        .navigationTitle("Detalle de Alerta")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
        .confirmationDialog("Eliminar alerta", isPresented: $confirmarEliminar, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { Task { await eliminar() } }
        } message: {
            Text("Deja de verse para los productores de tu zona.")
        }
    }

    private func cargar() async {
        defer { cargando = false }
        do {
            reporte = try await estado.api.reporte(id: id)
        } catch {
            self.error = error.mensaje
        }
    }

    private func eliminar() async {
        eliminando = true
        defer { eliminando = false }
        do {
            try await estado.api.eliminarReporte(id: id)
            estado.avisar("Alerta eliminada.", esError: false)
            cerrar()
        } catch {
            estado.avisar(error.mensaje)
        }
    }
}

private struct Fila: View {
    let titulo: String
    let valor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.caption).foregroundStyle(Paleta.textoSecundario)
            Text(valor).font(.subheadline).foregroundStyle(Paleta.texto)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

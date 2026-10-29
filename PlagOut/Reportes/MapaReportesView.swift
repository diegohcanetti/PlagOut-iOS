import MapKit
import PlagOutCore
import SwiftUI

/// Mapa de alertas (versión simplificada de `MapaReportesScreen.kt`): con zoom lejano muestra
/// grupos con la cantidad y la severidad máxima; de cerca, cada alerta.
struct MapaReportesView: View {
    enum Ambito: String, CaseIterable, Identifiable {
        case todos = "Todas"
        case propios = "Mías"
        case comunidad = "Comunidad"
        var id: String { rawValue }
        var parametro: String? { self == .todos ? nil : (self == .propios ? "propios" : "comunidad") }
    }

    @Environment(AppEstado.self) private var estado
    @State private var camara: MapCameraPosition = .automatic
    @State private var region: MKCoordinateRegion?
    @State private var resultado: ReportesMapa?
    @State private var ambito: Ambito = .todos
    @State private var dias = 30
    @State private var cargando = false
    @State private var error: String?

    var body: some View {
        Map(position: $camara) {
            ForEach(estado.datos.terrenos) { terreno in
                Annotation(terreno.terrenoNombre, coordinate: CLLocationCoordinate2D(latitude: terreno.terrenoLatitud, longitude: terreno.terrenoLongitud)) {
                    Image(systemName: "leaf.circle.fill").font(.title2).foregroundStyle(Paleta.bosque, .white)
                }
            }
            if let grupos = resultado?.grupos {
                ForEach(Array(grupos.enumerated()), id: \.offset) { _, grupo in
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: grupo.latitud, longitude: grupo.longitud)) {
                        Text("\(grupo.cantidad)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: tamano(grupo.cantidad), height: tamano(grupo.cantidad))
                            .background(color(grupo.severidadMax), in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
            if let reportes = resultado?.reportes {
                ForEach(reportes) { reporte in
                    if let lat = reporte.latitud, let lon = reporte.longitud {
                        Annotation(reporte.plagaNombre, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            NavigationLink(value: Destino.reporte(reporte.id)) {
                                Image(systemName: "ant.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(color(reporte.nivelSeveridad), .white)
                            }
                        }
                    }
                }
            }
        }
        .mapStyle(.hybrid(elevation: .flat))
        .onMapCameraChange(frequency: .onEnd) { contexto in
            region = contexto.region
        }
        .task(id: claveConsulta) { await consultar() }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                Picker("Ámbito", selection: $ambito) {
                    ForEach(Ambito.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Picker("Período", selection: $dias) {
                        Text("7 días").tag(7)
                        Text("30 días").tag(30)
                        Text("90 días").tag(90)
                    }
                    .pickerStyle(.segmented)
                    if cargando { ProgressView().padding(.leading, 6) }
                }
                Text(textoEstado).font(.caption.weight(.medium)).foregroundStyle(Paleta.texto)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 12)
        }
        .navigationTitle("Mapa de alertas")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: centrarEnTerrenos)
    }

    private var claveConsulta: String {
        guard let region else { return "sin-region-\(ambito)-\(dias)" }
        return String(format: "%.3f,%.3f,%.3f,%.3f-%@-%d", region.center.latitude, region.center.longitude,
                      region.span.latitudeDelta, region.span.longitudeDelta, ambito.rawValue, dias)
    }

    private var textoEstado: String {
        if let error { return error }
        guard let resultado else { return "Mové el mapa para ver las alertas" }
        let total = resultado.total ?? (resultado.reportes?.count ?? resultado.grupos?.map(\.cantidad).reduce(0, +) ?? 0)
        if total == 0 { return "No hay alertas en esta zona" }
        return total == 1 ? "1 alerta en la zona" : "\(total) alertas en la zona"
    }

    private func centrarEnTerrenos() {
        let terrenos = estado.datos.terrenos
        guard !terrenos.isEmpty else {
            camara = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -34, longitude: -62), span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)))
            return
        }
        let lats = terrenos.map(\.terrenoLatitud), lons = terrenos.map(\.terrenoLongitud)
        let centro = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let lado = max(lats.max()! - lats.min()!, lons.max()! - lons.min()!, 0.3) * 3
        camara = .region(MKCoordinateRegion(center: centro, span: MKCoordinateSpan(latitudeDelta: lado, longitudeDelta: lado)))
    }

    private func consultar() async {
        guard let region else { return }
        // Pequeña espera: no consultar en cada cuadro mientras el mapa se acomoda.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        let zoom = ReglasReporte.zoom(anchoEnGrados: region.span.longitudeDelta)
        let area = PlagOutAPI.AreaMapa(
            sur: region.center.latitude - region.span.latitudeDelta / 2,
            oeste: region.center.longitude - region.span.longitudeDelta / 2,
            norte: region.center.latitude + region.span.latitudeDelta / 2,
            este: region.center.longitude + region.span.longitudeDelta / 2
        )
        cargando = true
        defer { cargando = false }
        do {
            resultado = try await estado.api.reportesMapa(
                area: area, zoom: zoom, nivel: zoom >= 9 ? "reportes" : "grupos",
                ambito: ambito.parametro, dias: dias
            )
            error = nil
        } catch {
            if !Task.isCancelled { self.error = error.mensaje }
        }
    }

    private func color(_ severidad: String?) -> Color {
        severidad.flatMap(Severidad.init(rawValue:)).map(SelloSeveridad.color) ?? Paleta.riesgoDesconocido
    }

    private func tamano(_ cantidad: Int) -> CGFloat {
        cantidad >= 50 ? 46 : cantidad >= 20 ? 40 : cantidad >= 10 ? 34 : 28
    }
}

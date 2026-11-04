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
    /// Lo visible en grados (esquinas del rectángulo Mercator), sin recortar.
    @State private var visible: (norte: Double, oeste: Double, sur: Double, este: Double)?
    /// Se centra en los terrenos una sola vez: al volver de una alerta el mapa queda donde estaba.
    @State private var centrado = false
    /// La consulta vigente: una respuesta vieja no pisa a una más nueva.
    @State private var consultaVigente = 0
    @State private var resultado: ReportesMapa?
    @State private var ambito: Ambito = .todos
    @State private var dias = 30
    @State private var cargando = false
    @State private var error: String?
    /// Ancho del mapa en puntos y fracción del mundo que abarca: con eso, cuánto es un punto.
    @State private var anchoMapa: CGFloat = 0
    @State private var mundoVisible: Double = 0

    /// Separación mínima entre dos marcas, en puntos: el grupo más grande mide 46.
    private static let separacionPuntos = 48.0

    /// Lo que se dibuja: grupos y pines sin encimarse, y los lotes que no quedan debajo de ellos.
    private var dibujo: (lotes: [Terreno], grupos: [GrupoReportesMapa], pines: [PinMapa]) {
        let minimo = anchoMapa > 0 ? Self.separacionPuntos * mundoVisible / Double(anchoMapa) : 0
        let grupos = resultado?.gruposSeparados(minimo: minimo) ?? []
        let pines = resultado?.pinesSeparados(minimo: minimo) ?? []
        let terrenos = estado.datos.terrenos
        let marcas = grupos.map { ($0.latitud, $0.longitud) } + pines.map { ($0.latitud, $0.longitud) }
        let libres = SeparacionMapa.lotesLibres(
            terrenos.map { ($0.terrenoLatitud, $0.terrenoLongitud) }, marcas: marcas, minimo: minimo * 0.75
        )
        return (libres.map { terrenos[$0] }, grupos, pines)
    }

    var body: some View {
        let dibujo = dibujo
        Map(position: $camara) {
            ForEach(dibujo.lotes) { terreno in
                Annotation(terreno.terrenoNombre, coordinate: CLLocationCoordinate2D(latitude: terreno.terrenoLatitud, longitude: terreno.terrenoLongitud)) {
                    Image(systemName: "leaf.circle.fill").font(.title2).foregroundStyle(Paleta.bosque, .white)
                }
            }
            if !dibujo.grupos.isEmpty {
                let grupos = dibujo.grupos
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
            if !dibujo.pines.isEmpty {
                ForEach(dibujo.pines) { pin in
                    let coordenada = CLLocationCoordinate2D(latitude: pin.latitud, longitude: pin.longitud)
                    if let unico = pin.reportes.first, pin.reportes.count == 1 {
                        Annotation(unico.plagaNombre, coordinate: coordenada) {
                            NavigationLink(value: Destino.reporte(unico.id)) { icono(pin) }
                        }
                    } else {
                        // Varias alertas en el mismo punto (centro de celda): se elige cuál abrir.
                        Annotation("\(pin.reportes.count) alertas", coordinate: coordenada) {
                            Menu {
                                ForEach(pin.reportes) { reporte in
                                    NavigationLink(value: Destino.reporte(reporte.id)) {
                                        Text("\(reporte.plagaNombre) · \(reporte.nivelSeveridad)")
                                    }
                                }
                            } label: {
                                icono(pin).overlay(alignment: .topTrailing) {
                                    Text("\(pin.reportes.count)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Paleta.texto, in: Circle())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                    }
                }
            }
        }
        .mapStyle(.hybrid(elevation: .flat))
        .onMapCameraChange(frequency: .onEnd) { contexto in
            let rect = contexto.rect
            let noroeste = MKMapPoint(x: rect.minX, y: rect.minY).coordinate
            let sureste = MKMapPoint(x: rect.maxX, y: rect.maxY).coordinate
            // MKMapPoint.coordinate da la vuelta al mundo: el ancho sale del rectángulo, no de las esquinas.
            let ancho = rect.width / MKMapRect.world.width * 360
            visible = (noroeste.latitude, noroeste.longitude, sureste.latitude, noroeste.longitude + ancho)
            mundoVisible = rect.width / MKMapRect.world.width
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { anchoMapa = $0 }
        .onChange(of: ambito) { resultado = nil }
        .onChange(of: dias) { resultado = nil }
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
                    .accessibilityIdentifier("estadoMapa")
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 12)
        }
        .navigationTitle("Mapa de alertas")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !centrado else { return }
            centrado = true
            centrarEnTerrenos()
        }
    }

    private var claveConsulta: String {
        guard let visible else { return "sin-region-\(ambito)-\(dias)" }
        return String(format: "%.3f,%.3f,%.3f,%.3f-%@-%d", visible.norte, visible.oeste, visible.sur, visible.este,
                      ambito.rawValue, dias)
    }

    private var textoEstado: String {
        if let error { return error }
        guard let resultado else { return cargando ? "Buscando alertas…" : "Mové el mapa para ver las alertas" }
        let total = resultado.totalEnZona
        let texto = total == 0 ? "No hay alertas en esta zona"
            : total == 1 ? "1 alerta en la zona" : "\(total) alertas en la zona"
        switch resultado.descartados {
        case 0: return texto
        case 1: return texto + " · 1 no se pudo mostrar"
        case let n: return texto + " · \(n) no se pudieron mostrar"
        }
    }

    private func centrarEnTerrenos() {
        let terrenos = estado.datos.terrenos
        guard !terrenos.isEmpty else {
            camara = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -34, longitude: -62), span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)))
            return
        }
        let lats = terrenos.map(\.terrenoLatitud), lons = terrenos.map(\.terrenoLongitud)
        let centro = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let lado = min(max(lats.max()! - lats.min()!, lons.max()! - lons.min()!, 0.3) * 3, 120)
        camara = .region(MKCoordinateRegion(center: centro, span: MKCoordinateSpan(latitudeDelta: lado, longitudeDelta: lado)))
    }

    private func consultar() async {
        guard let visible else { return }
        // Pequeña espera: no consultar en cada cuadro mientras el mapa se acomoda.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        consultaVigente += 1
        let numero = consultaVigente
        let zoom = ReglasReporte.zoom(anchoEnGrados: visible.este - visible.oeste)
        let area = PlagOutAPI.AreaMapa.visible(norte: visible.norte, oeste: visible.oeste, sur: visible.sur, este: visible.este)
        cargando = true
        defer { if numero == consultaVigente { cargando = false } }
        do {
            let respuesta = try await estado.api.reportesMapa(
                area: area, zoom: zoom, nivel: zoom >= 9 ? "reportes" : "grupos",
                ambito: ambito.parametro, dias: dias
            )
            guard !Task.isCancelled, numero == consultaVigente else { return }
            resultado = respuesta
            error = nil
        } catch {
            guard !Task.isCancelled, numero == consultaVigente else { return }
            // Sin respuesta no quedan en pantalla las alertas de otra zona o de otro filtro.
            resultado = nil
            self.error = error.mensaje
        }
    }

    private func icono(_ pin: PinMapa) -> some View {
        // Relleno: la ubicación exacta de una alerta propia; contorno: el centro de celda de una ajena.
        Image(systemName: pin.propio ? "ant.circle.fill" : "ant.circle")
            .font(.title)
            .foregroundStyle(color(pin.severidadMaxima), .white)
            .background(Circle().fill(.white.opacity(pin.propio ? 0 : 0.85)))
    }

    private func color(_ severidad: String?) -> Color {
        severidad.flatMap(Severidad.init(rawValue:)).map(SelloSeveridad.color) ?? Paleta.riesgoDesconocido
    }

    private func tamano(_ cantidad: Int) -> CGFloat {
        cantidad >= 50 ? 46 : cantidad >= 20 ? 40 : cantidad >= 10 ? 34 : 28
    }
}

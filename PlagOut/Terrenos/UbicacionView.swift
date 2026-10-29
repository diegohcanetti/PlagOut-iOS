import CoreLocation
import MapKit
import PlagOutCore
import SwiftUI

/// Elegir dónde está el lote: tocando el mapa, con la ubicación actual o escribiendo las
/// coordenadas (`SelectLocationScreen.kt`).
struct SelectorUbicacion: View {
    @Binding var coordenada: CLLocationCoordinate2D?
    @State private var camara: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -34.6, longitude: -60.5),
        span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    ))
    @State private var ubicador = Ubicador()
    @State private var latitud = ""
    @State private var longitud = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MapReader { lector in
                Map(position: $camara) {
                    if let coordenada {
                        Marker("Terreno", systemImage: "leaf.fill", coordinate: coordenada).tint(Paleta.bosque)
                    }
                    UserAnnotation()
                }
                .mapStyle(.hybrid(elevation: .flat))
                .onTapGesture { punto in
                    if let tocado = lector.convert(punto, from: .local) { elegir(tocado, mover: false) }
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .topLeading) {
                Text("Tocá el mapa para marcar el lote")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .padding(10)
            }

            Button {
                Task {
                    if let actual = await ubicador.ubicacionActual() { elegir(actual, mover: true) }
                }
            } label: {
                Label(ubicador.buscando ? "Buscando…" : "Usar ubicación actual", systemImage: "location.fill")
            }
            .buttonStyle(.bordered)
            .tint(Paleta.bosque)
            .disabled(ubicador.buscando)
            if let error = ubicador.error {
                Text(error).font(.caption).foregroundStyle(Paleta.riesgoAlto)
            }

            Text("Ingresá las coordenadas").font(.subheadline.weight(.medium)).foregroundStyle(Paleta.textoSecundario)
            HStack {
                TextField("Latitud (Ej: -34.60)", text: $latitud).keyboardType(.numbersAndPunctuation)
                TextField("Longitud (Ej: -58.38)", text: $longitud).keyboardType(.numbersAndPunctuation)
            }
            .textFieldStyle(.roundedBorder)
            .onSubmit(desdeTexto)
            .onChange(of: latitud) { desdeTexto() }
            .onChange(of: longitud) { desdeTexto() }
        }
    }

    private func elegir(_ punto: CLLocationCoordinate2D, mover: Bool) {
        coordenada = punto
        latitud = String(format: "%.5f", punto.latitude)
        longitud = String(format: "%.5f", punto.longitude)
        if mover {
            camara = .region(MKCoordinateRegion(center: punto, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        }
    }

    private func desdeTexto() {
        guard let lat = Double(latitud.replacingOccurrences(of: ",", with: ".")),
              let lon = Double(longitud.replacingOccurrences(of: ",", with: ".")),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return }
        let punto = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        if coordenada?.latitude != lat || coordenada?.longitude != lon { coordenada = punto }
    }
}

/// La ubicación actual una vez, pidiendo permiso "cuando se usa" si hace falta.
@MainActor
@Observable
final class Ubicador: NSObject, CLLocationManagerDelegate {
    var buscando = false
    var error: String?
    private let gestor = CLLocationManager()
    private var espera: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        gestor.delegate = self
        gestor.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func ubicacionActual() async -> CLLocationCoordinate2D? {
        error = nil
        buscando = true
        defer { buscando = false }
        return await withCheckedContinuation { continuacion in
            espera = continuacion
            switch gestor.authorizationStatus {
            case .notDetermined: gestor.requestWhenInUseAuthorization()
            case .denied, .restricted: terminar(nil, error: "Permití el acceso a la ubicación en Ajustes para usarla.")
            default: gestor.requestLocation()
            }
        }
    }

    private func terminar(_ punto: CLLocationCoordinate2D?, error: String? = nil) {
        self.error = error
        espera?.resume(returning: punto)
        espera = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let estado = manager.authorizationStatus
        Task { @MainActor in
            guard espera != nil else { return }
            switch estado {
            case .authorizedWhenInUse, .authorizedAlways: gestor.requestLocation()
            case .denied, .restricted: terminar(nil, error: "Permití el acceso a la ubicación en Ajustes para usarla.")
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let punto = locations.last?.coordinate
        Task { @MainActor in terminar(punto) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in terminar(nil, error: "No se pudo obtener la ubicación actual.") }
    }
}

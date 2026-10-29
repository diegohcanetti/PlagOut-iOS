import PlagOutCore
import SwiftUI

/// Las notificaciones dentro de la app (`NotificacionesSheet.kt`). El backend devuelve solo las
/// no leídas: la cantidad es el número de la campana.
@MainActor
@Observable
final class NotificacionesModelo {
    var lista: [Notificacion] = []
    var cargando = false
    var error: String?

    func cargar(_ api: PlagOutAPI) async {
        cargando = lista.isEmpty
        defer { cargando = false }
        do {
            lista = try await api.notificaciones().sorted { ($0.fecha ?? .distantPast) > ($1.fecha ?? .distantPast) }
            error = nil
        } catch {
            self.error = error.mensaje
        }
    }

    /// La saca de la lista enseguida; si el backend falla, vuelve.
    func marcarLeida(_ notificacion: Notificacion, _ api: PlagOutAPI) async -> String? {
        lista.removeAll { $0.id == notificacion.id }
        do {
            _ = try await api.marcarLeida(id: notificacion.id)
            return nil
        } catch {
            if error.codigo == 404 { return nil }
            lista.append(notificacion)
            return error.mensaje
        }
    }

    static func haceCuanto(_ fecha: Date?, ahora: Date = Date()) -> String {
        guard let fecha else { return "" }
        let segundos = ahora.timeIntervalSince(fecha)
        if segundos < 60 { return "Recién" }
        if segundos < 3600 { return "Hace \(Int(segundos / 60)) min" }
        if segundos < 86_400 { return "Hace \(Int(segundos / 3600)) h" }
        if segundos < 7 * 86_400 { return "Hace \(Int(segundos / 86_400)) d" }
        return DiaCalendario(fecha: fecha).corto
    }
}

/// Ayuda y campana arriba de las pestañas principales.
struct BarraSuperior: ViewModifier {
    @Environment(AppEstado.self) private var estado
    @State private var mostrarNotificaciones = false
    @State private var mostrarAyuda = false

    func body(content: Content) -> some View {
        let cantidad = estado.notificaciones.lista.count
        content
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Ayuda", systemImage: "questionmark.circle") { mostrarAyuda = true }
                    Button {
                        mostrarNotificaciones = true
                    } label: {
                        Image(systemName: cantidad > 0 ? "bell.badge" : "bell")
                    }
                    .accessibilityLabel("Notificaciones")
                    .accessibilityValue(cantidad == 1 ? "1 aviso sin leer" : "\(cantidad) avisos sin leer")
                }
            }
            .sheet(isPresented: $mostrarNotificaciones) { NotificacionesView() }
            .sheet(isPresented: $mostrarAyuda) { AyudaView() }
    }
}

extension View {
    func barraSuperior() -> some View { modifier(BarraSuperior()) }
}

struct NotificacionesView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        let modelo = estado.notificaciones
        NavigationStack {
            List {
                if modelo.cargando {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let error = modelo.error, modelo.lista.isEmpty {
                    EstadoVacio(icono: "wifi.exclamationmark", titulo: "No se pudieron cargar los avisos", detalle: error,
                                boton: "Reintentar", accion: { Task { await modelo.cargar(estado.api) } })
                } else if modelo.lista.isEmpty {
                    EstadoVacio(icono: "checkmark.seal", titulo: "Estás al día",
                                detalle: "No tenés avisos pendientes. Te avisamos acá cuando el riesgo de alguno de tus monitoreos supere tu umbral.")
                } else {
                    Section {
                        ForEach(modelo.lista) { notificacion in
                            Button { abrir(notificacion) } label: { FilaNotificacion(notificacion: notificacion) }
                                .swipeActions {
                                    Button("Leída", systemImage: "checkmark") { Task { await leer(notificacion) } }
                                        .tint(Paleta.bosque)
                                }
                        }
                    } header: {
                        Text(modelo.lista.count == 1 ? "1 aviso sin leer" : "\(modelo.lista.count) avisos sin leer")
                    } footer: {
                        Text("Deslizá una notificación para marcarla como leída")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .fondoCampo()
            .navigationTitle("Notificaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { cerrar() } } }
            .refreshable { await modelo.cargar(estado.api) }
            .task { await modelo.cargar(estado.api) }
        }
    }

    private func leer(_ notificacion: Notificacion) async {
        if let error = await estado.notificaciones.marcarLeida(notificacion, estado.api) { estado.avisar(error) }
    }

    /// Tocarla la marca como leída y lleva a lo que avisa.
    private func abrir(_ notificacion: Notificacion) {
        Task { await leer(notificacion) }
        if let destino = Destino.de(notificacion) {
            cerrar()
            estado.destinoPendiente = destino
        }
    }
}

private struct FilaNotificacion: View {
    let notificacion: Notificacion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icono)
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(notificacion.titulo).font(.subheadline.weight(.semibold)).foregroundStyle(Paleta.texto)
                Text(notificacion.mensaje).font(.subheadline).foregroundStyle(Paleta.textoSecundario)
                Text(NotificacionesModelo.haceCuanto(notificacion.fecha)).font(.caption).foregroundStyle(Paleta.textoSecundario)
            }
        }
        .padding(.vertical, 4)
    }

    private var tipo: String { notificacion.tipo.uppercased() }
    private var icono: String {
        if tipo.contains("ML") { return "chart.line.uptrend.xyaxis" }
        if tipo.contains("REPORTE") { return "ant" }
        if tipo.contains("BIOFIX") { return "leaf" }
        return "thermometer.medium"
    }
    private var color: Color {
        if tipo.contains("ML") || tipo.contains("ALERTA") { return Paleta.riesgoAlto }
        if tipo.contains("REPORTE") { return Paleta.terracota }
        return Paleta.bosque
    }
}

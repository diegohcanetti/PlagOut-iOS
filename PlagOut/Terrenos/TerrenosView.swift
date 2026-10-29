import MapKit
import PlagOutCore
import SwiftUI

/// Rutas propias de la pestaña Terrenos.
enum RutaCampo: Hashable {
    case terreno(Int)
    case mapaReportes
}

struct TerrenosView: View {
    @Environment(AppEstado.self) private var estado
    @State private var creando = false

    var body: some View {
        let datos = estado.datos
        ScrollView {
            LazyVStack(spacing: 12) {
                if datos.cargando || (!datos.cargado && datos.error == nil) {
                    ProgressView().padding(40)
                } else if let error = datos.error, !datos.cargado {
                    EstadoVacio(icono: "wifi.exclamationmark", titulo: "No se pudieron cargar los terrenos", detalle: error,
                                boton: "Reintentar", accion: { Task { await datos.cargar(estado.api) } })
                } else if datos.terrenos.isEmpty {
                    EstadoVacio(icono: "map", titulo: "No hay terrenos cargados",
                                detalle: "Comenzá registrando tu primer lote de tierra para monitorear plagas y cultivos.",
                                boton: "Nuevo Terreno", accion: { creando = true })
                } else {
                    Resumen(terrenos: datos.terrenos, monitoreos: datos.monitoreos)
                    ForEach(datos.terrenos) { terreno in
                        NavigationLink(value: RutaCampo.terreno(terreno.id)) {
                            TarjetaTerreno(terreno: terreno, monitoreos: datos.monitoreos(deTerreno: terreno.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .fondoCampo()
        .navigationTitle("Mis Terrenos")
        .barraSuperior()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nuevo Terreno", systemImage: "plus") { creando = true }
            }
        }
        .sheet(isPresented: $creando) { NuevoTerrenoView() }
        .refreshable { await datos.cargar(estado.api) }
        .task { if !datos.cargado { await datos.cargar(estado.api) } }
    }
}

private struct Resumen: View {
    let terrenos: [Terreno]
    let monitoreos: [Monitoreo]

    var body: some View {
        let area = terrenos.map(\.terrenoArea).reduce(0, +)
        let activos = monitoreos.filter(\.estaActivo).count
        Tarjeta {
            Text("Gestión de Campo").font(.caption.weight(.semibold)).foregroundStyle(Paleta.textoSecundario)
            HStack {
                Estadistica(titulo: "Terrenos", valor: "\(terrenos.count)")
                Divider().frame(height: 28)
                Estadistica(titulo: "Área total", valor: "\(formatoHectareas(area)) ha")
                Divider().frame(height: 28)
                Estadistica(titulo: activos == 1 ? "monitoreo activo" : "monitoreos activos", valor: "\(activos)")
            }
        }
    }
}

struct TarjetaTerreno: View {
    let terreno: Terreno
    let monitoreos: [Monitoreo]

    var body: some View {
        let activos = monitoreos.filter(\.estaActivo)
        let estilo = estiloDelTerreno(activos: activos, hayMonitoreos: !monitoreos.isEmpty)
        Tarjeta {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(terreno.terrenoNombre).font(.headline).foregroundStyle(Paleta.texto)
                    Label("\(formatoHectareas(terreno.terrenoArea)) ha", systemImage: "square.dashed")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                    Label(activos.count == 1 ? "1 monitoreo activo" : "\(activos.count) monitoreos activos", systemImage: "flask")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                }
                Spacer()
                SelloNivel(estilo: estilo)
            }
        }
    }

    /// El nivel más alto de sus monitoreos activos (`TerrenoScreen.kt`).
    private func estiloDelTerreno(activos: [Monitoreo], hayMonitoreos: Bool) -> EstiloNivel {
        if !hayMonitoreos { return EstiloNivel(color: Paleta.riesgoDesconocido, etiqueta: "Sin monitoreos", icono: "minus.circle") }
        if activos.isEmpty { return EstiloNivel(color: Paleta.corteza, etiqueta: "Todos finalizados", icono: "flag.fill") }
        if activos.allSatisfy(\.esperandoBiofix) { return .esperandoBiofix }
        let nivel = activos.map(\.nivelAlertaEfectivo).max() ?? -1
        return nivel <= 0 ? EstiloNivel(color: Paleta.riesgoBajo, etiqueta: "Todo en orden", icono: "checkmark.circle.fill") : .de(nivel: nivel)
    }
}

/// Hectáreas con hasta dos decimales y coma: "42", "12,5", "0,01".
func formatoHectareas(_ valor: Double) -> String {
    valor.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "es_AR")))
}

/// Alta de un terreno: nombre, hectáreas y ubicación en el mapa.
struct NuevoTerrenoView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var hectareas = ""
    @State private var coordenada: CLLocationCoordinate2D?
    @State private var enviando = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Dale un nombre a tu lote y contanos cuántas hectáreas ocupa.")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                    Tarjeta {
                        CampoTexto(etiqueta: "Nombre del terreno", texto: $nombre)
                        CampoTexto(etiqueta: "Hectáreas", texto: $hectareas, teclado: .decimalPad)
                    }
                    Tarjeta {
                        Text("Ubicación del terreno").font(.headline)
                        SelectorUbicacion(coordenada: $coordenada)
                    }
                    if let error { MensajeEnLinea(texto: error) }
                    BotonPrincipal(titulo: "Guardar terreno", cargando: enviando) { Task { await guardar() } }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .fondoCampo()
            .navigationTitle("Nuevo Terreno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
        }
    }

    private func guardar() async {
        if let problema = ReglasCampo.errorTerreno(nombre: nombre, hectareas: hectareas) {
            error = problema
            return
        }
        guard let coordenada else {
            error = "Debe seleccionar la ubicación"
            return
        }
        guard ReglasCampo.enArgentina(latitud: coordenada.latitude, longitud: coordenada.longitude) else {
            error = "Ubicación fuera de la República Argentina"
            return
        }
        enviando = true
        defer { enviando = false }
        do {
            _ = try await estado.api.crearTerreno(NuevoTerreno(
                nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
                latitud: coordenada.latitude, longitud: coordenada.longitude,
                areaHectareas: ReglasCampo.leerHectareas(hectareas) ?? 0
            ))
            estado.avisar("Terreno creado.", esError: false)
            await estado.datos.cargar(estado.api)
            cerrar()
        } catch {
            self.error = error.mensaje
        }
    }
}

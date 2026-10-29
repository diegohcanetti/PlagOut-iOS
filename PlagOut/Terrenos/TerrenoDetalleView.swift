import MapKit
import PlagOutCore
import SwiftUI

/// Un terreno con sus cultivos (`PlantacionesScreen.kt`): editar, eliminar y agregar cultivos.
struct TerrenoDetalleView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    let id: Int
    @State private var editando = false
    @State private var agregandoCultivo = false
    @State private var confirmarEliminar = false

    var body: some View {
        let datos = estado.datos
        Group {
            if let terreno = datos.terreno(id) {
                ScrollView {
                    VStack(spacing: 14) {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: terreno.terrenoLatitud, longitude: terreno.terrenoLongitud),
                            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                        ))) {
                            Marker(terreno.terrenoNombre, systemImage: "leaf.fill",
                                   coordinate: CLLocationCoordinate2D(latitude: terreno.terrenoLatitud, longitude: terreno.terrenoLongitud))
                                .tint(Paleta.bosque)
                        }
                        .mapStyle(.hybrid(elevation: .flat))
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .allowsHitTesting(false)

                        Tarjeta {
                            HStack {
                                Estadistica(titulo: "Hectáreas", valor: formatoHectareas(terreno.terrenoArea))
                                Divider().frame(height: 28)
                                Estadistica(titulo: "Cultivos activos", valor: "\(datos.plantaciones(deTerreno: id).filter(\.activa).count)")
                                Divider().frame(height: 28)
                                Estadistica(titulo: "Monitoreos activos", valor: "\(datos.monitoreos(deTerreno: id).filter(\.estaActivo).count)")
                            }
                            Text(String(format: "%.4f, %.4f", terreno.terrenoLatitud, terreno.terrenoLongitud))
                                .font(.caption)
                                .foregroundStyle(Paleta.textoSecundario)
                        }

                        HStack {
                            Text("Cultivos").font(.headline)
                            Spacer()
                            Button("Nuevo Cultivo", systemImage: "plus") { agregandoCultivo = true }
                                .buttonStyle(.bordered)
                                .tint(Paleta.bosque)
                        }
                        let plantaciones = datos.plantaciones(deTerreno: id)
                        if plantaciones.isEmpty {
                            EstadoVacio(icono: "leaf", titulo: "Sin cultivos registrados",
                                        detalle: "Registrá un cultivo en este terreno para empezar a monitorear plagas.")
                        }
                        ForEach(plantaciones) { plantacion in
                            NavigationLink(value: Destino.plantacion(plantacion.id)) {
                                TarjetaPlantacion(plantacion: plantacion, monitoreos: datos.monitoreos(dePlantacion: plantacion.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .refreshable { await datos.cargar(estado.api) }
                .navigationTitle(terreno.terrenoNombre)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Editar terreno", systemImage: "pencil") { editando = true }
                            Button("Eliminar terreno", systemImage: "trash", role: .destructive) { confirmarEliminar = true }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                .sheet(isPresented: $editando) { EditarTerrenoView(terreno: terreno) }
                .sheet(isPresented: $agregandoCultivo) { NuevaPlantacionView(terreno: terreno) }
                .confirmationDialog("Eliminar terreno", isPresented: $confirmarEliminar, titleVisibility: .visible) {
                    Button("Eliminar", role: .destructive) { Task { await eliminar() } }
                } message: {
                    Text("Borra sus cultivos y monitoreos.")
                }
            } else {
                EstadoVacio(icono: "questionmark.folder", titulo: "No disponible", detalle: "Este terreno ya no existe.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoCampo()
    }

    private func eliminar() async {
        do {
            try await estado.api.eliminarTerreno(id: id)
            estado.avisar("Terreno eliminado.", esError: false)
            cerrar()
            await estado.datos.cargar(estado.api)
        } catch {
            estado.avisar(error.mensaje)
        }
    }
}

struct TarjetaPlantacion: View {
    let plantacion: Plantacion
    let monitoreos: [Monitoreo]

    var body: some View {
        let activos = monitoreos.filter(\.estaActivo).count
        let dias = plantacion.fechaSiembra.dias(hasta: .hoy())
        Tarjeta {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plantacion.activa ? "CULTIVO ACTIVO" : "CULTIVO FINALIZADO")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(plantacion.activa ? Paleta.hoja : Paleta.corteza)
                    Text(plantacion.cultivoNombre).font(.headline)
                    Text(plantacion.cultivoNombreCientifico).font(.caption).italic().foregroundStyle(Paleta.textoSecundario)
                    Text("Sembrado el \(plantacion.fechaSiembra.corto) · \(dias) días")
                        .font(.subheadline)
                        .foregroundStyle(Paleta.textoSecundario)
                }
                Spacer()
                VStack {
                    Text("\(activos)").font(.title2.weight(.bold)).foregroundStyle(Paleta.bosque)
                    Text(activos == 1 ? "monitoreo\nactivo" : "monitoreos\nactivos")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Paleta.textoSecundario)
                }
            }
        }
    }
}

private struct EditarTerrenoView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    let terreno: Terreno
    @State private var nombre: String
    @State private var hectareas: String
    @State private var enviando = false
    @State private var error: String?

    init(terreno: Terreno) {
        self.terreno = terreno
        _nombre = State(initialValue: terreno.terrenoNombre)
        _hectareas = State(initialValue: formatoHectareas(terreno.terrenoArea))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("El nuevo nombre se verá también en sus cultivos y monitoreos.")
                    .font(.subheadline)
                    .foregroundStyle(Paleta.textoSecundario)
                CampoTexto(etiqueta: "Nombre del terreno", texto: $nombre)
                CampoTexto(etiqueta: "Hectáreas", texto: $hectareas, teclado: .decimalPad)
                if let error { MensajeEnLinea(texto: error) }
                BotonPrincipal(titulo: "Guardar", cargando: enviando) { Task { await guardar() } }
                Spacer()
            }
            .padding(20)
            .fondoCampo()
            .navigationTitle("Editar terreno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
        }
        .presentationDetents([.medium])
    }

    private func guardar() async {
        if let problema = ReglasCampo.errorTerreno(nombre: nombre, hectareas: hectareas) {
            error = problema
            return
        }
        let nuevoNombre = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let nuevaArea = ReglasCampo.leerHectareas(hectareas)
        let cambios = CambiosTerreno(
            nombre: nuevoNombre == terreno.terrenoNombre ? nil : nuevoNombre,
            areaHectareas: nuevaArea == terreno.terrenoArea ? nil : nuevaArea
        )
        guard cambios.nombre != nil || cambios.areaHectareas != nil else {
            cerrar()
            return
        }
        enviando = true
        defer { enviando = false }
        do {
            _ = try await estado.api.actualizarTerreno(id: terreno.id, cambios)
            estado.avisar("Terreno actualizado.", esError: false)
            await estado.datos.cargar(estado.api)
            cerrar()
        } catch {
            self.error = error.mensaje
        }
    }
}

/// Alta de un cultivo (plantación) en un terreno: qué se sembró y cuándo.
struct NuevaPlantacionView: View {
    @Environment(AppEstado.self) private var estado
    @Environment(\.dismiss) private var cerrar
    let terreno: Terreno
    @State private var cultivo: Cultivo?
    @State private var fecha = DiaCalendario.hoy().fecha
    @State private var enviando = false
    @State private var error: String?

    var body: some View {
        let rango = ReglasCampo.rangoSiembra(hoy: .hoy())
        NavigationStack {
            Form {
                Section {
                    Text("Elegí qué se sembró y cuándo empezó el ciclo.").foregroundStyle(Paleta.textoSecundario)
                }
                Section("Detalle del cultivo") {
                    Picker("Cultivo", selection: $cultivo) {
                        Text("Seleccionar cultivo").tag(Cultivo?.none)
                        ForEach(estado.datos.cultivos) { Text($0.nombre).tag(Optional($0)) }
                    }
                    DatePicker("Fecha de siembra", selection: $fecha, in: rango.lowerBound.fecha...rango.upperBound.fecha, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "es_AR"))
                        .environment(\.timeZone, DiaCalendario.zonaArgentina)
                }
                if let error { Section { MensajeEnLinea(texto: error) } }
            }
            .navigationTitle("Nuevo cultivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando { ProgressView() } else {
                        Button("Guardar") { Task { await guardar() } }.disabled(cultivo == nil)
                    }
                }
            }
        }
    }

    private func guardar() async {
        guard let cultivo else {
            error = "Debe seleccionar un cultivo"
            return
        }
        enviando = true
        defer { enviando = false }
        do {
            _ = try await estado.api.crearPlantacion(NuevaPlantacion(terrenoId: terreno.id, cultivoId: cultivo.id, fechaSiembra: DiaCalendario(fecha: fecha)))
            estado.avisar("Cultivo agregado.", esError: false)
            await estado.datos.cargar(estado.api)
            cerrar()
        } catch {
            self.error = error.mensaje
        }
    }
}

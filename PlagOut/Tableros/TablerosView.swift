import Charts
import PlagOutCore
import SwiftUI

/// Tableros de control del productor (`AdminMetricasScreen.kt` sin el modo global): se calculan
/// con sus monitoreos, terrenos y plantaciones.
struct TablerosView: View {
    enum Seccion: String, CaseIterable, Identifiable {
        case productor = "Productor"
        case control = "Control"
        case historico = "Histórico"
        var id: String { rawValue }
    }

    @Environment(AppEstado.self) private var estado
    @State private var seccion: Seccion = .productor
    @State private var campaniaElegida: String?

    var body: some View {
        let datos = estado.datos
        ScrollView {
            VStack(spacing: 14) {
                Picker("Sección", selection: $seccion) {
                    ForEach(Seccion.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if datos.cargando || (!datos.cargado && datos.error == nil) {
                    ProgressView().padding(40)
                } else if datos.monitoreos.isEmpty {
                    EstadoVacio(icono: "chart.pie", titulo: "Sin datos registrados",
                                detalle: "Cuando des de alta lotes y monitoreos, tus tableros analíticos se generarán automáticamente.")
                } else {
                    switch seccion {
                    case .productor: productor(datos)
                    case .control: control(datos)
                    case .historico: historico(datos)
                    }
                }
            }
            .padding(16)
        }
        .fondoCampo()
        .navigationTitle("Tableros de Control")
        .barraSuperior()
        .refreshable { await datos.cargar(estado.api) }
        .task { if !datos.cargado { await datos.cargar(estado.api) } }
    }

    // MARK: Productor

    @ViewBuilder
    private func productor(_ datos: DatosCampo) -> some View {
        let semaforo = Tableros.semaforo(datos.monitoreos, terrenos: datos.terrenos)
        Tarjeta {
            Titulo("Superficie por etapa de la plaga", "Hectáreas según la etapa más avanzada de cada lote")
            if semaforo.totalLotes == 0 {
                Text("No hay monitoreos activos con mediciones.").font(.subheadline).foregroundStyle(Paleta.textoSecundario)
            } else {
                Chart(EtapaTermica.allCases, id: \.self) { etapa in
                    SectorMark(angle: .value("Hectáreas", max(semaforo.hectareas[etapa] ?? 0, semaforo.totalHectareas == 0 ? Double(semaforo.lotes[etapa] ?? 0) : 0)),
                               innerRadius: .ratio(0.6), angularInset: 2)
                        .foregroundStyle(EstiloNivel.de(nivel: etapa.rawValue).color)
                }
                .frame(height: 180)
                .overlay {
                    VStack {
                        Text("\(formatoHectareas(semaforo.totalHectareas)) ha").font(.headline)
                        Text(semaforo.totalLotes == 1 ? "1 lote" : "\(semaforo.totalLotes) lotes").font(.caption).foregroundStyle(Paleta.textoSecundario)
                    }
                }
                ForEach(EtapaTermica.allCases, id: \.self) { etapa in
                    HStack {
                        Circle().fill(EstiloNivel.de(nivel: etapa.rawValue).color).frame(width: 10, height: 10)
                        Text(etapa.etiqueta).font(.subheadline)
                        Spacer()
                        Text("\(formatoHectareas(semaforo.hectareas[etapa] ?? 0)) ha · \(semaforo.lotes[etapa] ?? 0) lotes")
                            .font(.subheadline)
                            .foregroundStyle(Paleta.textoSecundario)
                    }
                }
            }
            if semaforo.lotesEsperandoBiofix > 0 {
                Text("Esperando biofix: \(semaforo.lotesEsperandoBiofix) lote(s), \(formatoHectareas(semaforo.hectareasEsperandoBiofix)) ha")
                    .font(.caption).foregroundStyle(Paleta.textoSecundario)
            }
            if semaforo.lotesSinMonitoreo > 0 {
                Text("Sin monitoreo activo: \(semaforo.lotesSinMonitoreo) lote(s), \(formatoHectareas(semaforo.hectareasSinMonitoreo)) ha")
                    .font(.caption).foregroundStyle(Paleta.textoSecundario)
            }
        }
        let cultivos = Tableros.plagasPorCultivo(datos.monitoreos, terrenos: datos.terrenos, plantaciones: datos.plantaciones)
        Tarjeta {
            Titulo("Plagas incidentes por cultivo", "Prevalencia de plagas en los lotes monitoreados")
            if cultivos.isEmpty {
                Text("No hay cultivos registrados con monitoreos.").font(.subheadline).foregroundStyle(Paleta.textoSecundario)
            }
            ForEach(cultivos) { cultivo in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(cultivo.nombre) · \(cultivo.lotes == 1 ? "1 lote" : "\(cultivo.lotes) lotes") · \(formatoHectareas(cultivo.hectareas)) ha"
                         + (cultivo.diasDesdeSiembra.map { " · \($0) días" } ?? ""))
                        .font(.subheadline.weight(.semibold))
                    ForEach(cultivo.plagas, id: \.nombre) { plaga in
                        BarraPorcentaje(titulo: plaga.nombre, porcentaje: plaga.porcentaje, detalle: "\(Int(plaga.porcentaje))% · \(plaga.lotes) \(plaga.lotes == 1 ? "lote" : "lotes")")
                    }
                }
            }
        }
    }

    // MARK: Control

    @ViewBuilder
    private func control(_ datos: DatosCampo) -> some View {
        let lotes = Tableros.lotesPorEtapa(datos.monitoreos)
        Tarjeta {
            Titulo("Etapas de los monitoreos activos", "Cuántos monitoreos con mediciones hay en cada etapa según los grados-día acumulados.")
            Chart(EtapaTermica.allCases, id: \.self) { etapa in
                BarMark(x: .value("Etapa", etapa.etiqueta), y: .value("Monitoreos", lotes.filter { $0.etapa == etapa }.count))
                    .foregroundStyle(EstiloNivel.de(nivel: etapa.rawValue).color)
                    .annotation(position: .top) {
                        Text("\(lotes.filter { $0.etapa == etapa }.count)").font(.caption.weight(.semibold))
                    }
            }
            .chartYAxis(.hidden)
            .frame(height: 160)
        }
        Tarjeta {
            Titulo("Lotes por etapa", "Del más avanzado al menos avanzado según la etapa y el avance hacia la eclosión")
            if lotes.isEmpty {
                Text("No hay monitoreos activos con mediciones.").font(.subheadline).foregroundStyle(Paleta.textoSecundario)
            }
            ForEach(lotes) { lote in
                NavigationLink(value: Destino.monitoreo(lote.monitoreoId)) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lote.terreno).font(.subheadline.weight(.semibold)).foregroundStyle(Paleta.texto)
                            Text("\(lote.cultivo) • \(lote.plaga)").font(.caption).foregroundStyle(Paleta.textoSecundario)
                            Text(lote.etapa.recomendacion).font(.caption).foregroundStyle(Paleta.textoSecundario)
                        }
                        Spacer()
                        AnilloProgreso(progreso: lote.progreso, color: EstiloNivel.de(nivel: lote.etapa.rawValue).color, tamano: 48)
                    }
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        Tarjeta {
            Titulo("Eficacia de tratamientos", nil)
            Text("Registrá cada tratamiento con el conteo de la plaga antes y después desde el detalle del monitoreo, en la pestaña Tratamientos. Ahí se calcula su eficacia.")
                .font(.subheadline)
                .foregroundStyle(Paleta.textoSecundario)
        }
    }

    // MARK: Histórico

    @ViewBuilder
    private func historico(_ datos: DatosCampo) -> some View {
        let campanias = Tableros.campanias(datos.monitoreos, terrenos: datos.terrenos)
        let actual = campanias.first { $0.nombre == campaniaElegida } ?? campanias.first
        Tarjeta {
            Text("HISTÓRICO CONSOLIDADO").font(.caption.weight(.semibold)).foregroundStyle(Paleta.textoSecundario)
            HStack {
                Estadistica(titulo: "Campañas", valor: "\(campanias.count)")
                Divider().frame(height: 28)
                Estadistica(titulo: "Monitoreos", valor: "\(datos.monitoreos.count)")
                Divider().frame(height: 28)
                Estadistica(titulo: "Hectáreas", valor: formatoHectareas(Set(datos.monitoreos.map(\.terrenoId)).compactMap { datos.terreno($0)?.terrenoArea }.reduce(0, +)))
            }
        }
        if let actual {
            Picker("Campaña", selection: Binding(get: { actual.nombre }, set: { campaniaElegida = $0 })) {
                ForEach(campanias) { Text($0.nombre).tag($0.nombre) }
            }
            .pickerStyle(.segmented)
            Tarjeta {
                Titulo("Campaña \(actual.nombre)", "\(actual.plagas.count) plagas monitoreadas • \(actual.monitoreos) seguimientos")
                if let lider = actual.plagaPredominante {
                    Text("PLAGA PREDOMINANTE DE LA CAMPAÑA").font(.caption2.weight(.semibold)).foregroundStyle(Paleta.textoSecundario)
                    Text(lider.nombre).font(.headline)
                    Text("\(lider.monitoreos) \(lider.monitoreos == 1 ? "monitoreo" : "monitoreos") · \(lider.cultivos.count) \(lider.cultivos.count == 1 ? "cultivo afectado" : "cultivos afectados")")
                        .font(.caption)
                        .foregroundStyle(Paleta.textoSecundario)
                }
                Chart {
                    BarMark(x: .value("Monitoreos", actual.riesgoBajo)).foregroundStyle(Paleta.riesgoBajo)
                    BarMark(x: .value("Monitoreos", actual.riesgoModerado)).foregroundStyle(Paleta.riesgoMedio)
                    BarMark(x: .value("Monitoreos", actual.riesgoAlto)).foregroundStyle(Paleta.riesgoAlto)
                }
                .chartXAxis(.hidden)
                .frame(height: 26)
                Text("En huevo \(actual.riesgoBajo) · Eclosión cerca \(actual.riesgoModerado) · Eclosionó \(actual.riesgoAlto)")
                    .font(.caption)
                    .foregroundStyle(Paleta.textoSecundario)
            }
            Tarjeta {
                Titulo("Prevalencia de plagas en la campaña", nil)
                ForEach(actual.plagas) { plaga in
                    BarraPorcentaje(titulo: plaga.nombre, porcentaje: plaga.incidencia,
                                    detalle: "\(plaga.monitoreos) \(plaga.monitoreos == 1 ? "monitoreo" : "monitoreos") · Afecta: \(plaga.cultivos.joined(separator: ", "))")
                }
            }
            Tarjeta {
                Titulo("Monitoreos por cultivo y plaga", "Total de monitoreos registrados en la campaña (activos y finalizados)")
                ForEach(actual.cultivos) { cultivo in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(cultivo.nombre) · \(cultivo.monitoreos) \(cultivo.monitoreos == 1 ? "monitoreo" : "monitoreos")").font(.subheadline.weight(.semibold))
                        ForEach(cultivo.plagas, id: \.nombre) { plaga in
                            Text("\(plaga.nombre): \(plaga.monitoreos)").font(.caption).foregroundStyle(Paleta.textoSecundario)
                        }
                    }
                }
            }
        }
    }
}

private struct Titulo: View {
    let titulo: String
    let detalle: String?

    init(_ titulo: String, _ detalle: String?) {
        self.titulo = titulo
        self.detalle = detalle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.headline)
            if let detalle { Text(detalle).font(.caption).foregroundStyle(Paleta.textoSecundario) }
        }
    }
}

private struct BarraPorcentaje: View {
    let titulo: String
    let porcentaje: Double
    let detalle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(titulo).font(.subheadline)
                Spacer()
                Text("\(Int(porcentaje.rounded()))%").font(.subheadline.weight(.semibold))
            }
            GeometryReader { lector in
                ZStack(alignment: .leading) {
                    Capsule().fill(Paleta.cremaProfunda)
                    Capsule().fill(Paleta.hoja).frame(width: lector.size.width * min(max(porcentaje / 100, 0), 1))
                }
            }
            .frame(height: 8)
            Text(detalle).font(.caption).foregroundStyle(Paleta.textoSecundario)
        }
    }
}

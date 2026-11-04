import Foundation
import Testing
@testable import PlagOutCore

/// Viviparous aphids have no egg: their levels count toward a new generation (`hito`).
struct HitoTests {
    private func ciclo(id: Int, nivel: Int, hito: String?, estadio: String = "NINFA") -> [String: Any] {
        var ciclo: [String: Any] = [
            "id": id, "monitoreo_id": id, "fecha_biofix": "2026-11-04", "estado": "activo",
            "fecha_actualizacion": "2026-11-04", "gdd_diario": 0.0, "gdd_acumulado": 0.0, "gdd_eclosion": 148.0,
            "gdd_generacion": 148.0, "progreso": 10.0, "estadio_biologico": estadio, "nivel_alerta": nivel,
            "fecha_eclosion": NSNull(), "dias_pendientes": 0,
        ]
        if let hito { ciclo["hito"] = hito }
        return ciclo
    }

    private func monitoreo(id: Int, terreno: Int = 1, nivel: Int, hito: String?, estadio: String = "NINFA") throws -> Monitoreo {
        let json: [String: Any] = [
            "id": id, "plantacion_id": 1, "terreno_id": terreno, "terreno_nombre": "Lote", "cultivo_nombre": "Trigo",
            "plaga_id": 1, "plaga_nombre": "Plaga", "plaga_nombre_cientifico": NSNull(), "gdd_objetivo": 148.0,
            "fecha_inicio": "2026-11-04", "umbral_riesgo": 80, "activo": true, "observaciones": NSNull(),
            "alertas_ml_activas": false, "ciclos": [ciclo(id: id, nivel: nivel, hito: hito, estadio: estadio)],
        ]
        return try JSON.decoder.decode(Monitoreo.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test func elCicloLeeElHitoYToleraQueFalte() throws {
        let conHito = try JSON.decoder.decode(CicloGDD.self, from: JSONSerialization.data(withJSONObject: ciclo(id: 1, nivel: 0, hito: "generacion")))
        let sinHito = try decodificar(CicloGDD.self, "ciclo")
        #expect(conHito.hito == Hito.generacion)
        #expect(sinHito.hito == nil)
    }

    @Test func unPulgonNoSeDescribeConHuevoNiEclosion() {
        let palabras = (0...2).compactMap { PalabrasDeNivel.para(nivel: $0, hitos: [Hito.generacion]) }
        #expect(palabras.map(\.etiqueta) == ["En desarrollo", "Generación cerca", "Nueva generación"])
        for palabra in palabras {
            let texto = (palabra.etiqueta + " " + palabra.descripcion + " " + (palabra.recomendacion ?? "")).lowercased()
            #expect(!texto.contains("huevo") && !texto.contains("eclosi") && !texto.contains("larva"), "\(texto)")
        }
    }

    @Test func sinPulgonesValenLasPalabrasDeSiempre() {
        #expect(PalabrasDeNivel.para(nivel: 1, hitos: [Hito.eclosion, nil]) == nil)
        #expect(PalabrasDeNivel.para(nivel: 0, hitos: []) == nil)
        #expect(PalabrasDeNivel.para(nivel: -1, hitos: [Hito.generacion]) == nil)
        #expect(EtapaTermica.huevo.etiqueta(hitos: [nil]) == "En huevo")
    }

    @Test func unaMezclaUsaPalabrasQueValenParaAmbos() {
        let mezcla = PalabrasDeNivel.para(nivel: 1, hitos: [Hito.eclosion, Hito.generacion])
        #expect(mezcla?.etiqueta == "Objetivo cerca")
        #expect(mezcla?.descripcion.contains("eclosión o la nueva generación") == true)
    }

    @Test func losResumenesMiranSoloLoQueCuentaCadaNivel() throws {
        let oruga = try monitoreo(id: 1, nivel: 0, hito: Hito.eclosion, estadio: "HUEVO")
        let chinche = try monitoreo(id: 2, nivel: 1, hito: Hito.eclosion, estadio: "HUEVO")
        let pulgon = try monitoreo(id: 3, nivel: 0, hito: Hito.generacion)
        let todos = [oruga, chinche, pulgon]
        #expect(pulgon.hito == Hito.generacion)
        #expect(EtapaTermica.huevo.etiqueta(hitos: todos.hitos(enNivel: 0)) == "En desarrollo")
        #expect(EtapaTermica.eclosionCerca.etiqueta(hitos: todos.hitos(enNivel: 1)) == "Eclosión cerca")
    }

    @Test func elTableroDelProductorRotulaLaEtapaDeCadaLote() throws {
        let pulgon = try monitoreo(id: 3, terreno: 7, nivel: 0, hito: Hito.generacion, estadio: "")
        let lote = try #require(Tableros.lotesPorEtapa([pulgon]).first)
        #expect(lote.hito == Hito.generacion)
        #expect(lote.estadio == "Ninfa")
        #expect(!lote.etapa.recomendacion(hito: lote.hito).lowercased().contains("eclosion"))
        let terreno = try JSON.decoder.decode(Terreno.self, from: Data(
            #"{"id": 7, "terreno_nombre": "Lote", "terreno_latitud": -34.3, "terreno_longitud": -60.2, "terreno_area": 12}"#.utf8))
        let semaforo = Tableros.semaforo([pulgon], terrenos: [terreno])
        #expect(EtapaTermica.huevo.etiqueta(hitos: semaforo.hitos[.huevo] ?? []) == "En desarrollo")
    }
}

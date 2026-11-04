import Foundation
import Testing
@testable import PlagOutCore

/// The map asks the backend only for areas it accepts, and every report it shows can be opened.
struct MapaTests {
    @Test func elAreaVisibleQuedaDentroDeLoQueAceptaElBackend() {
        // Zoomed far out: more than the world wide and past the poles.
        let mundo = PlagOutAPI.AreaMapa.visible(norte: 89, oeste: -242, sur: -89, este: 118)
        #expect((mundo.sur, mundo.oeste, mundo.norte, mundo.este) == (-85, -180, 85, 180))
        // Over the antimeridian the map can report the west edge one turn away.
        let corrido = PlagOutAPI.AreaMapa.visible(norte: -30, oeste: 300, sur: -40, este: 310)
        #expect((corrido.oeste, corrido.este) == (-60, -50))
        // The API does not wrap: the request must cover both sides of the meridian.
        let borde = PlagOutAPI.AreaMapa.visible(norte: 10, oeste: 170, sur: 0, este: 190)
        #expect((borde.oeste, borde.este) == (-180, 180))
        // Argentina at a normal zoom passes untouched.
        let campo = PlagOutAPI.AreaMapa.visible(norte: -27.8, oeste: -68, sur: -39.8, este: -56)
        #expect((campo.sur, campo.oeste, campo.norte, campo.este) == (-39.8, -68, -27.8, -56))
        #expect(PlagOutAPI.AreaMapa.visible(norte: .nan, oeste: .nan, sur: 0, este: 1).oeste == -180)
    }

    @Test func unaVistaQueCruzaElAntimeridianoIncluyeLaParteVisibleDeArgentina() {
        // 310° E es 50° O: Buenos Aires es visible en el segundo tramo de la pantalla.
        let area = PlagOutAPI.AreaMapa.visible(norte: -20, oeste: 150, sur: -55, este: 310)
        #expect(area.oeste <= -58.4 && area.este >= -58.4)
        #expect((area.sur, area.norte) == (-55, -20))
    }

    @Test func lasAlertasEnElMismoPuntoSeJuntanEnUnPinQueLasAbreATodas() throws {
        let mapa = try decodificar(ReportesMapa.self, "mapa_reportes")
        let pines = mapa.pines
        #expect(pines.count == 2)
        let compartido = try #require(pines.first)
        #expect(compartido.reportes.map(\.id) == [99, 98])
        #expect(compartido.severidadMaxima == "Medio")
        #expect(!compartido.propio)
        #expect(pines[1].reportes.map(\.id) == [93])
        #expect(Set(pines.map(\.id)).count == pines.count)
    }

    @Test func elTotalDeLaZonaUsaElDelBackendYSinoCuenta() throws {
        #expect(try decodificar(ReportesMapa.self, "mapa_reportes").totalEnZona == 29)
        let grupos = try JSON.decoder.decode(ReportesMapa.self, from: Data(
            #"{"nivel":"grupos","grupos":[{"latitud":-34,"longitud":-60,"cantidad":3,"severidad_max":null},{"latitud":-35,"longitud":-61,"cantidad":2,"severidad_max":"Alto"}]}"#.utf8))
        #expect(grupos.totalEnZona == 5)
        #expect(grupos.grupos?.first?.severidadMax == nil)
        #expect(grupos.pines.isEmpty)
    }

    @Test func unReporteIlegibleNoTiraElMapaEntero() throws {
        // The second report lacks plaga_nombre and the second group has a string count.
        let mapa = try JSON.decoder.decode(ReportesMapa.self, from: Data(#"""
            {"nivel":"reportes","total":3,"reportes":[
              {"id":1,"plaga_id":2,"plaga_nombre":"Chicharrita","nivel_severidad":"Alto","latitud":-34.6,"longitud":-58.4,"timestamp_ms":1730000000000,"es_propio":false},
              {"id":2,"plaga_id":2,"nivel_severidad":"Bajo","latitud":-34.7,"longitud":-58.5,"timestamp_ms":1730000000000},
              {"id":3,"plaga_id":5,"plaga_nombre":"Oruga","nivel_severidad":"Medio","latitud":-34.8,"longitud":-58.6,"timestamp_ms":1730000000000,"es_propio":true}
            ],"grupos":[{"latitud":-34,"longitud":-60,"cantidad":3},{"latitud":-35,"longitud":-61,"cantidad":"dos"}]}
            """#.utf8))
        #expect(mapa.reportes?.map(\.id) == [1, 3])
        #expect(mapa.grupos?.map(\.cantidad) == [3])
        #expect(mapa.descartados == 2)
        #expect(mapa.totalEnZona == 3, "the backend total still counts the unreadable report")
        #expect(mapa.pines.map(\.reportes.first?.id) == [1, 3])
    }

    @Test func unaRespuestaRotaSigueFallando() {
        // Only elements are skipped: a response whose list is not a list is a contract break.
        #expect(throws: DecodingError.self) {
            try JSON.decoder.decode(ReportesMapa.self, from: Data(#"{"nivel":"reportes","reportes":{"id":1}}"#.utf8))
        }
        #expect(throws: DecodingError.self) {
            try JSON.decoder.decode(ReportesMapa.self, from: Data(#"{"nivel":"reportes","total":"tres"}"#.utf8))
        }
    }

    /// A world-wide view on a 400-point-wide map: one point is 1/400 of the world.
    static let minimoMundo = 48.0 / 400

    @Test func dosGruposPegadosAUnoYOtroLadoDelBordeSeDibujanComoUno() throws {
        // Two server cells next to each other: their groups land a few km apart.
        let mapa = try JSON.decoder.decode(ReportesMapa.self, from: Data(#"""
            {"nivel":"grupos","total":15,"grupos":[
              {"latitud":-34.60,"longitud":-60.10,"cantidad":12,"severidad_max":"Medio"},
              {"latitud":-34.62,"longitud":-60.06,"cantidad":3,"severidad_max":"Alto"},
              {"latitud":-24.80,"longitud":-65.40,"cantidad":2,"severidad_max":null}
            ]}
            """#.utf8))
        // Regional view: about 4 degrees across 400 points.
        let regional = mapa.gruposSeparados(minimo: 48.0 / 400 * 4 / 360)
        #expect(regional.count == 2)
        let unido = try #require(regional.first)
        #expect(unido.cantidad == 15)
        #expect(unido.severidadMax == "Alto")
        #expect(abs(unido.latitud - (-34.60 * 12 - 34.62 * 3) / 15) < 1e-9)
        #expect(regional.map(\.cantidad).reduce(0, +) == 17, "no alert is lost")
        // Zoomed in, the same groups stay apart.
        #expect(mapa.gruposSeparados(minimo: 48.0 / 400 * 0.01 / 360).count == 3)
        // Without a map width yet, nothing is merged.
        #expect(mapa.gruposSeparados(minimo: 0).count == 3)
    }

    @Test func ningunParDeMarcasQuedaEncimado() {
        var generador = SystemRandomNumberGenerator()
        let grupos = (0..<300).map { _ in
            GrupoReportesMapa(latitud: Double.random(in: -36 ... -32, using: &generador),
                              longitud: Double.random(in: -62 ... -58, using: &generador),
                              cantidad: Int.random(in: 1...9, using: &generador), severidadMax: "Bajo")
        }
        let total = grupos.map(\.cantidad).reduce(0, +)
        for minimo in [0.0005, 0.002, 0.01, Self.minimoMundo] {
            let separados = SeparacionMapa.juntar(grupos, minimo: minimo, posicion: { ($0.latitud, $0.longitud) }, peso: \.cantidad) { a, b in
                GrupoReportesMapa(latitud: (a.latitud + b.latitud) / 2, longitud: (a.longitud + b.longitud) / 2,
                                  cantidad: a.cantidad + b.cantidad, severidadMax: a.severidadMax)
            }
            #expect(separados.map(\.cantidad).reduce(0, +) == total)
            for i in separados.indices {
                for j in separados.indices where j > i {
                    #expect(SeparacionMapa.distancia((separados[i].latitud, separados[i].longitud), (separados[j].latitud, separados[j].longitud)) >= minimo)
                }
            }
        }
    }

    @Test func pinesCercanosSeAbrenDesdeUnMismoMenu() throws {
        let mapa = try decodificar(ReportesMapa.self, "mapa_reportes")
        // Seen from far away, every report of the fixture fits in one pin.
        let lejos = mapa.pinesSeparados(minimo: Self.minimoMundo)
        #expect(lejos.count == 1)
        #expect(Set(lejos[0].reportes.map(\.id)) == Set(mapa.pines.flatMap { $0.reportes.map(\.id) }))
        // Up close they keep their own positions.
        #expect(mapa.pinesSeparados(minimo: 1e-9).count == mapa.pines.count)
    }

    @Test func elLoteDebajoDeUnGrupoNoTapaSuNumero() {
        // At world zoom 48 points are about 43 degrees: only a lot on another continent stays clear.
        let lotes = [(latitud: -34.29, longitud: -60.25), (latitud: 40.4, longitud: -3.7)]
        // World view: a group over Buenos Aires covers the first lot, not the one in Madrid.
        let libres = SeparacionMapa.lotesLibres(lotes, marcas: [(-34.5, -60.0)], minimo: Self.minimoMundo * 0.75)
        #expect(libres == [1])
        // Close up, nothing is hidden.
        #expect(SeparacionMapa.lotesLibres(lotes, marcas: [(-34.5, -60.0)], minimo: 1e-6) == [0, 1])
    }
}

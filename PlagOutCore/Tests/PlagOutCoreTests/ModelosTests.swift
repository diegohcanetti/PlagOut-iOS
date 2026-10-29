import Foundation
import Testing
@testable import PlagOutCore

func fixture(_ nombre: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: nombre, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

func decodificar<T: Decodable>(_ tipo: T.Type, _ nombre: String) throws -> T {
    try JSON.decoder.decode(T.self, from: fixture(nombre))
}

/// Las respuestas del backend se decodifican con los modelos. Los catálogos, el usuario y el mapa
/// salen de producción (sin datos personales); el resto sigue los presenters del backend.
struct ModelosTests {
    @Test func catalogosDeProduccion() throws {
        let plagas = try decodificar([Plaga].self, "plagas")
        #expect(plagas.count == 11)
        let barrenador = try #require(plagas.first { $0.nombreCientifico == "Diatraea saccharalis" })
        #expect(barrenador.etapas == ["HUEVO", "LARVA", "ADULTO"])
        #expect(barrenador.admiteMonitoreo)
        #expect(barrenador.afecta(cultivoId: 3))
        #expect(try !decodificar([Cultivo].self, "cultivos").isEmpty)
        #expect(try !decodificar([Cargo].self, "cargos").isEmpty)
    }

    @Test func usuarioYConsentimiento() throws {
        let usuario = try decodificar(Usuario.self, "usuario")
        #expect(usuario.nombreCompleto == "Ana Productora")
        #expect(usuario.radioKm > 0)
        let consentimiento = try decodificar(ConsentimientoModelo.self, "consentimiento")
        #expect(consentimiento.versionContrato == "report-ml-consent-v1")
    }

    @Test func monitoreosConCiclos() throws {
        let pagina = try decodificar(Pagina<Monitoreo>.self, "monitoreos")
        #expect(pagina.total == 2)
        let conCiclos = pagina.items[0]
        #expect(conCiclos.fechaInicio == DiaCalendario(anio: 2026, mes: 9, dia: 1))
        #expect(conCiclos.cicloQueDescribe?.id == 41)
        #expect(conCiclos.cicloVigente?.id == 41)
        #expect(conCiclos.ciclosFinalizados.map(\.id) == [30])
        #expect(conCiclos.nivelAlertaEfectivo == 2)
        #expect(conCiclos.ciclosEnAlerta == 1)
        // Sin modelo térmico citado no hay objetivo, y sin ciclos espera el biofix.
        let esperando = pagina.items[1]
        #expect(esperando.gddObjetivo == nil)
        #expect(esperando.esperandoBiofix)
        #expect(esperando.nivelAlertaEfectivo == -1)
    }

    @Test func cicloBiofixYPrediccion() throws {
        let ciclo = try decodificar(CicloGDD.self, "ciclo")
        #expect(ciclo.acumuladoHuevo == 95)
        #expect(ciclo.objetivo(delMonitoreo: nil) == 120)
        let biofix = try decodificar(ResultadoBiofix.self, "biofix")
        #expect(biofix.cicloCreado && biofix.ciclo.id == 41)
        let prediccion = try decodificar(Prediccion.self, "prediccion")
        #expect(prediccion.confirmacion.estado == "pendiente")
        #expect(prediccion.horizonDays == 7)
    }

    @Test func terrenosPlantacionesYTratamientos() throws {
        #expect(try decodificar(Pagina<Terreno>.self, "terrenos").items.first?.terrenoArea == 42.5)
        #expect(try decodificar(TerrenoCreado.self, "terreno_creado").comoTerreno.terrenoNombre == "Lote Sur")
        #expect(try decodificar(Pagina<Plantacion>.self, "plantaciones").items.first?.fechaSiembra.corto == "01/09/2026")
        let tratamientos = try decodificar([Tratamiento].self, "tratamientos")
        #expect(tratamientos.map(\.metodo) == ["henderson_tilton", nil])
        #expect(tratamientos[1].sinCalculo == "falta_conteo_despues")
    }

    @Test func notificacionesConYSinZona() throws {
        let notificaciones = try decodificar([Notificacion].self, "notificaciones")
        #expect(notificaciones.allSatisfy { $0.fecha != nil })
        #expect(Destino.de(notificaciones[0]) == .monitoreo(12))
        #expect(Destino.de(notificaciones[1]) == .reportes)
    }

    @Test func mapaDeProduccion() throws {
        let grupos = try decodificar(ReportesMapa.self, "mapa_grupos")
        #expect(grupos.nivel == "grupos" && grupos.grupos?.isEmpty == false)
        let reportes = try decodificar(ReportesMapa.self, "mapa_reportes")
        let primero = try #require(reportes.reportes?.first)
        #expect(primero.severidad != nil)
        #expect(!primero.propio)
        #expect(try decodificar(ConteoReportes.self, "resumen").total >= 0)
    }

    @Test func paginaAceptaUnArregloSuelto() throws {
        let pagina = try JSON.decoder.decode(Pagina<Cargo>.self, from: Data(#"[{"id":1,"tipo":"Productor"}]"#.utf8))
        #expect(pagina.total == 1)
    }

    @Test func losPedidosViajanEnSnakeCaseSinLosNil() throws {
        let cuerpo = try JSON.encoder.encode(CambiosUsuario(radioNotificacionKm: 35))
        #expect(String(decoding: cuerpo, as: UTF8.self) == #"{"radio_notificacion_km":35}"#)
        let biofix = SolicitudBiofix(idempotencyKey: "k", fechaObservacion: DiaCalendario(anio: 2026, mes: 10, dia: 27), accion: .iniciarCiclo, nivelSeveridad: .medio)
        let json = try #require(try JSONSerialization.jsonObject(with: JSON.encoder.encode(biofix)) as? [String: Any])
        #expect(json["fecha_observacion"] as? String == "2026-10-27")
        #expect(json["version_contrato"] as? String == "biofix-v1")
        #expect(json["nivel_severidad"] as? String == "Medio")
        #expect(json["ciclo_id"] == nil)
    }

    @Test func diaCalendarioEnHoraArgentina() throws {
        // 02:30 UTC del 28/10 todavía es 27/10 en Argentina (UTC-3).
        let fecha = try #require(FechaHora.leer("2026-10-28T02:30:00Z"))
        #expect(DiaCalendario.hoy(fecha) == DiaCalendario(anio: 2026, mes: 10, dia: 27))
        #expect(DiaCalendario("2026-10-27")!.sumando(dias: 5).description == "2026-11-01")
        #expect(DiaCalendario("2026-02-30") != nil) // el backend valida; acá solo se lee
        #expect(DiaCalendario("hoy") == nil)
    }
}

struct CiclosTests {
    @Test func diasAlObjetivoYNumeracion() throws {
        let ciclo = try decodificar(CicloGDD.self, "ciclo")
        // 95 GDD del huevo en 21 días (5/10 → 26/10): faltan 25 a ~4,52 por día → 6 días.
        #expect(ciclo.diasEstimados(objetivoMonitoreo: nil) == 6)
        #expect(!ciclo.eclosiono)
        let monitoreo = try decodificar(Pagina<Monitoreo>.self, "monitoreos").items[0]
        let ciclos = try #require(monitoreo.ciclos)
        #expect(ciclos.numeros == [30: 1, 41: 2])
        #expect(ciclos.porProgreso.map(\.id) == [30, 41])
        let archivado = try #require(ciclos.first { $0.id == 30 })
        #expect(archivado.eclosiono)
        #expect(archivado.diasEstimados(objetivoMonitoreo: nil) == nil)
        #expect(archivado.actualizacionVisible.description == "2026-09-14")
    }
}

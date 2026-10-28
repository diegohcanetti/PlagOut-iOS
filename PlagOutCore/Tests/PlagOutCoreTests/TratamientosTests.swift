import Foundation
import Testing
@testable import PlagOutCore

/// Los mismos casos que `TratamientosTest.kt` de Android.
struct TratamientosTests {
    let hoy = DiaCalendario(anio: 2026, mes: 10, dia: 22)
    let inicio = DiaCalendario(anio: 2026, mes: 9, dia: 1)

    var valido: FormularioTratamiento {
        var form = FormularioTratamiento()
        form.fechaAplicacion = DiaCalendario(anio: 2026, mes: 10, dia: 1)
        form.producto = "  Clorantraniliprole "
        form.conteoAntes = "12"
        form.fechaConteoAntes = DiaCalendario(anio: 2026, mes: 9, dia: 30)
        return form
    }

    var enviado: Tratamiento {
        get throws { try decodificar([Tratamiento].self, "tratamientos")[0] }
    }

    @Test func unFormularioValidoNoTieneErroresYElAltaRecortaElProducto() {
        #expect(validarTratamiento(valido, inicioMonitoreo: inicio, hoy: hoy).isEmpty)
        let alta = valido.solicitud(clave: "clave")
        #expect(alta.producto == "Clorantraniliprole")
        #expect(alta.fechaAplicacion.description == "2026-10-01")
        #expect(alta.conteoDespues == nil)
        #expect(alta.testigoAntes == nil)
    }

    @Test func validaFechasYConteosConLasReglasDelBackend() {
        var form = valido
        form.fechaAplicacion = DiaCalendario(anio: 2026, mes: 8, dia: 31) // antes del inicio
        form.producto = ""
        form.conteoAntes = "-1"
        form.conTestigo = true
        form.testigoAntes = "x"
        form.conDespues = true
        form.conteoDespues = "100001"
        form.fechaConteoDespues = DiaCalendario(anio: 2026, mes: 8, dia: 31)
        let errores = validarTratamiento(form, inicioMonitoreo: inicio, hoy: hoy)
        #expect(Set(errores.keys) == [.fechaAplicacion, .producto, .conteoAntes, .fechaConteoAntes, .testigoAntes, .conteoDespues, .fechaConteoDespues])

        var futura = valido
        futura.fechaAplicacion = hoy.sumando(dias: 1)
        #expect(validarTratamiento(futura, inicioMonitoreo: inicio, hoy: hoy)[.fechaAplicacion] == "No puede ser futura")

        // El conteo posterior el mismo día de la aplicación no sirve.
        var mismoDia = valido
        mismoDia.conDespues = true
        mismoDia.conteoDespues = "2"
        mismoDia.fechaConteoDespues = valido.fechaAplicacion
        #expect(validarTratamiento(mismoDia, inicioMonitoreo: inicio, hoy: hoy)[.fechaConteoDespues] == "Tiene que ser después de aplicar")
    }

    @Test func elTestigoPosteriorEsOpcionalYLaComaDecimalVale() {
        var form = valido
        form.conTestigo = true
        form.testigoAntes = "10,5"
        form.conDespues = true
        form.conteoDespues = "2,5"
        form.fechaConteoDespues = hoy
        #expect(validarTratamiento(form, inicioMonitoreo: inicio, hoy: hoy).isEmpty)
        let alta = form.solicitud(clave: "k")
        #expect(alta.testigoAntes == 10.5)
        #expect(alta.conteoDespues == 2.5)
        #expect(alta.testigoDespues == nil)
    }

    @Test func laEdicionMandaSoloLoCambiadoYNullExplicitoParaDeshacer() throws {
        let original = try enviado
        let sinCambios = FormularioTratamiento.desde(original)
        #expect(cambiosDeTratamiento(original: original, form: sinCambios) == nil)

        var sinPosterior = sinCambios
        sinPosterior.conDespues = false
        #expect(cambiosDeTratamiento(original: original, form: sinPosterior) == ["conteo_despues": .nulo, "fecha_conteo_despues": .nulo, "testigo_despues": .nulo])
        let cuerpo = JSON.conNulos(try #require(cambiosDeTratamiento(original: original, form: sinPosterior)))
        #expect(String(decoding: cuerpo, as: UTF8.self) == #"{"conteo_despues":null,"fecha_conteo_despues":null,"testigo_despues":null}"#)

        var otroProducto = sinCambios
        otroProducto.producto = "Spinetoram"
        #expect(cambiosDeTratamiento(original: original, form: otroProducto) == ["producto": .texto("Spinetoram")])
    }

    @Test func elResultadoDiceQueMetodoUsoYPorQueFaltaLaCifra() throws {
        let base = try enviado
        func con(metodo: String?, eficacia: Double? = nil, reduccion: Double? = nil, sinCalculo: String? = nil) -> Tratamiento {
            Tratamiento(
                id: base.id, monitoreoId: base.monitoreoId, fechaAplicacion: base.fechaAplicacion, producto: base.producto,
                unidadConteo: base.unidadConteo, conteoAntes: base.conteoAntes, fechaConteoAntes: base.fechaConteoAntes,
                conteoDespues: base.conteoDespues, fechaConteoDespues: base.fechaConteoDespues, testigoAntes: base.testigoAntes,
                testigoDespues: base.testigoDespues, metodo: metodo, reduccionObservadaPct: reduccion, eficaciaPct: eficacia,
                sinCalculo: sinCalculo, cita: nil
            )
        }
        let ht = resultadoDeTratamiento(con(metodo: "henderson_tilton", eficacia: 87.5, reduccion: 90))
        #expect(ht.titulo == "Eficacia: 87,5 %")
        #expect(ht.detalle?.contains("franja sin tratar") == true)

        let reduccion = resultadoDeTratamiento(con(metodo: "reduccion_observada", reduccion: 75))
        #expect(reduccion.titulo == "Reducción observada: 75 %")
        #expect(reduccion.detalle?.contains("mortalidad natural") == true)

        let sinTestigo = resultadoDeTratamiento(con(metodo: "reduccion_observada", reduccion: 75, sinCalculo: "falta_testigo_despues"))
        #expect(sinTestigo.detalle?.hasPrefix("Falta el conteo posterior de la franja sin tratar.") == true)

        #expect(resultadoDeTratamiento(con(metodo: "reduccion_observada", reduccion: -50)).titulo == "La plaga aumentó un 50 %")
        #expect(resultadoDeTratamiento(con(metodo: nil, sinCalculo: "falta_conteo_despues")).titulo == "Falta el conteo posterior")
        #expect(resultadoDeTratamiento(con(metodo: nil, sinCalculo: "conteo_antes_cero")).titulo == "Sin plaga antes de aplicar")
    }

    @Test func conteos() {
        #expect(leerConteo(" 3,5 ") == 3.5)
        #expect(leerConteo("100000") == 100_000)
        #expect(leerConteo("100000,1") == nil)
        #expect(leerConteo("nan") == nil)
        #expect(formatearConteo(12) == "12")
        #expect(formatearConteo(2.5) == "2,5")
    }
}

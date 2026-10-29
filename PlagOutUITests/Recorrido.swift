import XCTest

/// Recorre la app contra producción con la cuenta de demo y guarda una captura por paso en
/// PLAGOUT_CAPTURAS (una carpeta de la Mac: el simulador la ve). No modifica datos salvo que la
/// prueba lo diga en su nombre.
@MainActor
final class Recorrido: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let entorno = ProcessInfo.processInfo.environment
        guard let email = entorno["PLAGOUT_DEMO_EMAIL"], let clave = entorno["PLAGOUT_DEMO_PASSWORD"] else {
            throw XCTSkip("Sin cuenta de demo")
        }
        app = XCUIApplication()
        app.launchEnvironment["PLAGOUT_DEMO_EMAIL"] = email
        app.launchEnvironment["PLAGOUT_DEMO_PASSWORD"] = clave
        if let abrir = entorno["PLAGOUT_ABRIR"] { app.launchEnvironment["PLAGOUT_ABRIR"] = abrir }
        app.launch()
    }

    func captura(_ nombre: String) {
        guard let carpeta = ProcessInfo.processInfo.environment["PLAGOUT_CAPTURAS"] else { return }
        let datos = XCUIScreen.main.screenshot().pngRepresentation
        try? datos.write(to: URL(fileURLWithPath: carpeta).appendingPathComponent("\(nombre).png"))
    }

    /// Un selector de formulario: su botón se llama "Etiqueta, valor actual".
    func selector(_ etiqueta: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", etiqueta + ",")).firstMatch
    }

    func esperar(_ elemento: XCUIElement, _ segundos: TimeInterval = 20) {
        XCTAssertTrue(elemento.waitForExistence(timeout: segundos), "No apareció \(elemento)")
    }

    func testMonitoreoYSusPestanas() {
        esperar(app.navigationBars["Mis Monitoreos"])
        captura("r01-monitoreos")
        app.buttons["Todos"].tap()
        let tarjeta = app.staticTexts["Chicharrita del maíz"].firstMatch
        esperar(tarjeta)
        tarjeta.tap()
        esperar(app.navigationBars["Monitoreo de plaga"])
        sleep(2)
        captura("r02-ciclos")
        app.buttons["Tratamientos"].tap()
        sleep(3)
        captura("r03-tratamientos")
        app.buttons["Detalle"].tap()
        sleep(1)
        captura("r04-detalle")
    }

    func testFormulariosSinGuardar() {
        esperar(app.navigationBars["Mis Monitoreos"])
        let tarjeta = app.staticTexts["Barrenador del tallo"].firstMatch
        esperar(tarjeta)
        tarjeta.tap()
        esperar(app.navigationBars["Monitoreo de plaga"])
        app.buttons["REGISTRAR BIOFIX"].tap()
        esperar(app.navigationBars["Registrar presencia"])
        captura("f01-biofix")
        app.buttons["Cancelar"].tap()
        app.buttons["Tratamientos"].tap()
        let registrar = app.buttons["REGISTRAR TRATAMIENTO"]
        esperar(registrar)
        registrar.tap()
        esperar(app.navigationBars["Registrar tratamiento"])
        captura("f02-tratamiento")
        app.buttons["Guardar"].tap()
        sleep(1)
        captura("f03-tratamiento-errores")
        app.buttons["Cancelar"].tap()
    }

    /// Escribe en producción: registra un tratamiento de prueba y lo borra.
    func testTratamientoSeCreaYSeBorra() {
        esperar(app.navigationBars["Mis Monitoreos"])
        let tarjeta = app.staticTexts["Barrenador del tallo"].firstMatch
        esperar(tarjeta)
        tarjeta.tap()
        esperar(app.navigationBars["Monitoreo de plaga"])
        app.buttons["Tratamientos"].tap()
        let registrar = app.buttons["REGISTRAR TRATAMIENTO"]
        esperar(registrar)
        registrar.tap()
        esperar(app.navigationBars["Registrar tratamiento"])
        let producto = app.textFields["Ej: Clorantraniliprole"]
        producto.tap()
        producto.typeText("Prueba iOS")
        let conteo = app.textFields["0"].firstMatch
        conteo.tap()
        conteo.typeText("12")
        app.buttons["Guardar"].tap()
        let creada = app.staticTexts["Prueba iOS"]
        esperar(creada)
        sleep(1)
        captura("t01-tratamiento-creado")
        app.buttons["Más"].firstMatch.tap()
        app.buttons["Eliminar"].tap()
        app.buttons["Eliminar"].firstMatch.tap()
        sleep(3)
        XCTAssertFalse(app.staticTexts["Prueba iOS"].exists)
        captura("t02-tratamiento-borrado")
    }

    func testTerrenosYAltasSinGuardar() {
        esperar(app.navigationBars["Mis Monitoreos"])
        app.buttons["Nuevo Monitoreo"].tap()
        esperar(app.navigationBars["Nuevo Monitoreo"])
        captura("c01-nuevo-monitoreo")
        app.buttons["Cancelar"].tap()
        app.tabBars.buttons["Terrenos"].tap()
        esperar(app.navigationBars["Mis Terrenos"])
        sleep(1)
        captura("c02-terrenos")
        app.staticTexts["Phase 6 provenance smoke"].firstMatch.tap()
        sleep(2)
        captura("c03-terreno")
        app.staticTexts["Maíz"].firstMatch.tap()
        esperar(app.navigationBars["Detalle de cultivo"])
        sleep(1)
        captura("c04-cultivo")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Nuevo Cultivo"].tap()
        esperar(app.navigationBars["Nuevo cultivo"])
        captura("c05-nuevo-cultivo")
        app.buttons["Cancelar"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Nuevo Terreno"].tap()
        esperar(app.navigationBars["Nuevo Terreno"])
        sleep(2)
        captura("c06-nuevo-terreno")
        app.buttons["Cancelar"].tap()
    }

    func testNotificacionesYAyuda() {
        esperar(app.navigationBars["Mis Monitoreos"])
        app.buttons["Notificaciones"].tap()
        esperar(app.navigationBars["Notificaciones"])
        sleep(2)
        captura("n01-notificaciones")
        app.buttons["Listo"].tap()
        app.buttons["Ayuda"].tap()
        sleep(1)
        captura("n02-ayuda")
        app.buttons["Listo"].tap()
    }

    func testPrediccionInexistente() {
        esperar(app.navigationBars["Alerta predictiva"])
        sleep(3)
        captura("n03-prediccion")
    }

    func testReportesYMapa() {
        esperar(app.navigationBars["Mis Monitoreos"])
        app.tabBars.buttons["Reportes"].tap()
        esperar(app.navigationBars["Alertas de plagas"])
        sleep(2)
        captura("p01-mis-alertas")
        app.buttons["Comunidad"].tap()
        sleep(3)
        captura("p02-comunidad")
        app.buttons["Mapa de alertas"].tap()
        esperar(app.navigationBars["Mapa de alertas"])
        sleep(5)
        captura("p03-mapa")
    }

    /// Escribe en producción: envía una alerta de prueba y la elimina.
    func testAlertaSeCreaYSeBorra() {
        esperar(app.navigationBars["Mis Monitoreos"])
        app.tabBars.buttons["Reportes"].tap()
        esperar(app.navigationBars["Alertas de plagas"])
        app.buttons["Nueva Alerta"].firstMatch.tap()
        esperar(app.navigationBars["Nueva Alerta"])
        selector("Terreno").tap()
        app.buttons["Phase 6 provenance smoke"].tap()
        sleep(1)
        selector("Plaga").tap()
        app.buttons["Barrenador del tallo"].tap()
        selector("Etapa").tap()
        app.buttons["Adulto"].tap()
        captura("p04-nueva-alerta")
        app.buttons["Enviar"].tap()
        esperar(app.navigationBars["Alertas de plagas"])
        sleep(2)
        captura("p05-alerta-enviada")
        app.staticTexts["Barrenador del tallo"].firstMatch.tap()
        esperar(app.navigationBars["Detalle de Alerta"])
        sleep(2)
        captura("p06-detalle-alerta")
        app.buttons["Eliminar alerta"].tap()
        app.buttons["Eliminar"].firstMatch.tap()
        esperar(app.navigationBars["Alertas de plagas"])
        sleep(2)
        captura("p07-alerta-borrada")
    }

    func testPerfilSinGuardar() {
        esperar(app.navigationBars["Mis Monitoreos"])
        app.tabBars.buttons["Perfil"].tap()
        esperar(app.navigationBars["Mi perfil"])
        sleep(2)
        captura("u01-perfil")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Rango de alerta")).firstMatch.tap()
        sleep(1)
        captura("u02-radio")
        app.buttons["Cancelar"].tap()
        app.buttons["Editar perfil"].tap()
        esperar(app.navigationBars["Editar perfil"])
        sleep(1)
        captura("u03-editar")
        app.buttons["Cancelar"].tap()
        app.swipeUp()
        app.buttons["Eliminar cuenta"].tap()
        sleep(1)
        captura("u04-eliminar")
        app.buttons["Cancelar"].tap()
    }

    func testTableros() {
        esperar(app.navigationBars["Mis Monitoreos"])
        app.tabBars.buttons["Tableros"].tap()
        esperar(app.navigationBars["Tableros de Control"])
        sleep(2)
        captura("k01-productor")
        app.buttons["Control"].tap()
        sleep(1)
        captura("k02-control")
        app.buttons["Histórico"].tap()
        sleep(1)
        captura("k03-historico")
    }
}

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
        let aparecio = elemento.waitForExistence(timeout: segundos)
        if !aparecio { captura("fallo-\(name.replacingOccurrences(of: " ", with: "_"))") }
        XCTAssertTrue(aparecio, "No apareció \(elemento)")
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

    /// Elige ayer en el selector de fecha número `indice` del formulario.
    func elegirAyer(_ indice: Int) {
        app.datePickers.element(boundBy: indice).tap()
        let calendario = app.datePickers.collectionViews.firstMatch
        esperar(calendario)
        let dias = calendario.buttons.allElementsBoundByIndex
        let hoy = dias.firstIndex { $0.label.hasPrefix("Hoy") }!
        if hoy > 0 {
            dias[hoy - 1].tap()
        } else {
            app.buttons["DatePicker.PreviousMonth"].tap()
            sleep(1)
            calendario.buttons.allElementsBoundByIndex.last!.tap()
        }
        app.buttons["PopoverDismissRegion"].tap()
    }

    func testTratamientoConTestigoMuestraLaEficacia() {
        esperar(app.navigationBars["Mis Monitoreos"])
        let tarjeta = app.staticTexts["Barrenador del tallo"].firstMatch
        esperar(tarjeta)
        tarjeta.tap()
        esperar(app.navigationBars["Monitoreo de plaga"])
        app.buttons["Tratamientos"].tap()
        app.buttons["REGISTRAR TRATAMIENTO"].tap()
        esperar(app.navigationBars["Registrar tratamiento"])
        // Aplicado y contado ayer; el conteo posterior queda con la fecha que muestra (hoy).
        elegirAyer(0)
        let producto = app.textFields["Ej: Clorantraniliprole"]
        producto.tap()
        producto.typeText("Prueba testigo iOS")
        let antes = app.textFields["Conteo antes"]
        antes.tap()
        antes.typeText("20")
        elegirAyer(1)
        app.switches["Dejé una franja sin tratar (testigo)"].switches.firstMatch.tap()
        let testigoAntes = app.textFields["Testigo antes"]
        esperar(testigoAntes)
        testigoAntes.tap()
        testigoAntes.typeText("20")
        app.swipeUp()
        app.switches["Ya tengo el conteo posterior"].switches.firstMatch.tap()
        let despues = app.textFields["Conteo después"]
        esperar(despues)
        despues.tap()
        despues.typeText("5")
        let testigoDespues = app.textFields["Testigo después (opcional)"]
        testigoDespues.tap()
        testigoDespues.typeText("20")
        captura("t03-tratamiento-con-testigo")
        app.buttons["Guardar"].tap()
        let creada = app.staticTexts["Prueba testigo iOS"]
        esperar(creada)
        // Henderson-Tilton: 1 − (5 × 20) / (20 × 20) = 75 %.
        let eficacia = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Eficacia: 75'")).firstMatch
        esperar(eficacia)
        sleep(1)
        captura("t04-eficacia")
        app.buttons["Más"].firstMatch.tap()
        app.buttons["Eliminar"].tap()
        app.buttons["Eliminar"].firstMatch.tap()
        sleep(3)
        XCTAssertFalse(app.staticTexts["Prueba testigo iOS"].exists)
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

    /// Necesita una alerta predictiva en la cuenta de demo; si no hay, se saltea.
    func testNotificacionAbreLaPrediccion() throws {
        esperar(app.navigationBars["Mis Monitoreos"])
        app.buttons["Notificaciones"].tap()
        esperar(app.navigationBars["Notificaciones"])
        let aviso = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Posible brote severo'")).firstMatch
        guard aviso.waitForExistence(timeout: 15) else { throw XCTSkip("La cuenta de demo no tiene alertas predictivas") }
        captura("p01-notificacion")
        aviso.tap()
        esperar(app.navigationBars["Alerta predictiva"])
        esperar(app.buttons["Revisé y no la observé"])
        sleep(1)
        captura("p02-prediccion")
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

    /// Escribe en producción: terreno → cultivo → monitoreo → biofix, y borra el terreno (se
    /// llevan su cultivo y su monitoreo).
    func testAltaCompletaYBorrado() {
        esperar(app.navigationBars["Mis Monitoreos"])
        app.tabBars.buttons["Terrenos"].tap()
        esperar(app.navigationBars["Mis Terrenos"])
        app.buttons["Nuevo Terreno"].firstMatch.tap()
        esperar(app.navigationBars["Nuevo Terreno"])
        let nombre = app.textFields["Nombre del terreno"]
        nombre.tap()
        nombre.typeText("Prueba iOS")
        let hectareas = app.textFields["Hectáreas"]
        hectareas.tap()
        hectareas.typeText("3")
        let latitud = app.textFields["Latitud (Ej: -34.60)"]
        latitud.tap()
        latitud.typeText("-34.6")
        let longitud = app.textFields["Longitud (Ej: -58.38)"]
        longitud.tap()
        longitud.typeText("-60.9\n")
        app.swipeUp()
        app.buttons["GUARDAR TERRENO"].tap()
        let terreno = app.staticTexts["Prueba iOS"].firstMatch
        esperar(terreno)
        captura("e01-terreno-creado")
        terreno.tap()
        app.buttons["Nuevo Cultivo"].tap()
        esperar(app.navigationBars["Nuevo cultivo"])
        selector("Cultivo").tap()
        app.buttons["Maíz"].tap()
        app.buttons["Guardar"].tap()
        let cultivo = app.staticTexts["Maíz"].firstMatch
        esperar(cultivo)
        captura("e02-cultivo-creado")
        cultivo.tap()
        esperar(app.navigationBars["Detalle de cultivo"])
        app.buttons["Nuevo Monitoreo"].tap()
        esperar(app.navigationBars["Nuevo Monitoreo"])
        selector("Plaga").tap()
        app.buttons["Chicharrita del maíz"].tap()
        captura("e03-nuevo-monitoreo")
        app.buttons["Crear"].tap()
        esperar(app.navigationBars["Monitoreo de plaga"])
        let biofix = app.buttons["REGISTRAR BIOFIX"]
        esperar(biofix)
        biofix.tap()
        esperar(app.navigationBars["Registrar presencia"])
        app.buttons["Medio"].tap()
        app.buttons["Confirmar"].tap()
        esperar(app.staticTexts["Ciclo 1"], 30)
        sleep(1)
        captura("e04-biofix")
        // La pestaña Terrenos quedó en el detalle del cultivo: se reabre la app para volver a la lista.
        app.terminate()
        app.launch()
        borrarTerrenoDePrueba()
        captura("e05-terreno-borrado")
    }

    func borrarTerrenoDePrueba() {
        esperar(app.navigationBars["Mis Monitoreos"])
        app.tabBars.buttons["Terrenos"].tap()
        esperar(app.navigationBars["Mis Terrenos"])
        let terreno = app.staticTexts["Prueba iOS"].firstMatch
        guard terreno.waitForExistence(timeout: 10) else { return }
        terreno.tap()
        app.buttons["Más"].firstMatch.tap()
        app.buttons["Eliminar terreno"].tap()
        app.buttons["Eliminar"].firstMatch.tap()
        esperar(app.navigationBars["Mis Terrenos"])
        sleep(3)
        XCTAssertFalse(app.staticTexts["Prueba iOS"].exists)
        // El biofix creó una alerta que sobrevive al terreno ("Terreno eliminado"): se borra.
        app.tabBars.buttons["Reportes"].tap()
        esperar(app.navigationBars["Alertas de plagas"])
        let huerfana = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Terreno eliminado")).firstMatch
        if huerfana.waitForExistence(timeout: 8) {
            huerfana.tap()
            esperar(app.navigationBars["Detalle de Alerta"])
            app.buttons["Eliminar alerta"].tap()
            app.buttons["Eliminar"].firstMatch.tap()
            esperar(app.navigationBars["Alertas de plagas"])
        }
    }

    /// Por si una prueba de escritura se cortó a la mitad.
    func testLimpiarDatosDePrueba() {
        borrarTerrenoDePrueba()
    }

    func testCerrarSesion() {
        esperar(app.navigationBars["Mis Monitoreos"])
        app.tabBars.buttons["Perfil"].tap()
        esperar(app.navigationBars["Mi perfil"])
        app.swipeUp()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Cerrar sesión")).firstMatch.tap()
        app.buttons["Cerrar sesión"].firstMatch.tap()
        esperar(app.staticTexts["Bienvenido"])
        captura("s01-sesion-cerrada")
    }

    func testEnlaceDeRecuperacionVencido() {
        esperar(app.staticTexts["Enlace no válido o ya utilizado"])
        captura("s02-enlace-vencido")
        app.buttons["VOLVER AL INICIO DE SESIÓN"].tap()
        // Había entrado con la cuenta de demo: vuelve a la app, no al login.
        esperar(app.navigationBars["Mis Monitoreos"])
    }
}

/// Recorre el mapa de alertas con la sesión que ya tenga el simulador (o con la cuenta de demo, si
/// se pasa). Solo lee: mueve el mapa, cambia el período y abre alertas. Deja en el log el texto de
/// estado de cada paso y guarda capturas en PLAGOUT_CAPTURAS.
@MainActor
final class RecorridoMapa: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        let entorno = ProcessInfo.processInfo.environment
        if let email = entorno["PLAGOUT_DEMO_EMAIL"], let clave = entorno["PLAGOUT_DEMO_PASSWORD"] {
            app.launchEnvironment["PLAGOUT_DEMO_EMAIL"] = email
            app.launchEnvironment["PLAGOUT_DEMO_PASSWORD"] = clave
        }
        app.launch()
        guard app.navigationBars["Mis Monitoreos"].waitForExistence(timeout: 30) else {
            throw XCTSkip("Sin sesión: iniciá sesión en el simulador o pasá la cuenta de demo")
        }
    }

    func captura(_ nombre: String) {
        guard let carpeta = ProcessInfo.processInfo.environment["PLAGOUT_CAPTURAS"] else { return }
        let datos = XCUIScreen.main.screenshot().pngRepresentation
        try? datos.write(to: URL(fileURLWithPath: carpeta).appendingPathComponent("\(nombre).png"))
    }

    var estado: XCUIElement { app.staticTexts["estadoMapa"] }

    /// Espera a que el mapa termine de consultar y devuelve el texto de estado.
    @discardableResult
    func esperarEstado(_ paso: String) -> String {
        let fin = Date().addingTimeInterval(25)
        sleep(2)
        while Date() < fin {
            let texto = estado.label
            if !texto.hasPrefix("Buscando"), !texto.hasPrefix("Mové"), !app.activityIndicators.firstMatch.exists {
                print("MAPA[\(paso)]: \(texto)")
                captura(paso)
                return texto
            }
            sleep(1)
        }
        print("MAPA[\(paso)]: sin terminar: \(estado.label)")
        captura(paso)
        return estado.label
    }

    func testMapaDePuntos() {
        app.tabBars.buttons["Reportes"].tap()
        XCTAssertTrue(app.navigationBars["Alertas de plagas"].waitForExistence(timeout: 20))
        app.buttons["Mapa de alertas"].tap()
        XCTAssertTrue(app.navigationBars["Mapa de alertas"].waitForExistence(timeout: 20))
        let mapa = app.maps.firstMatch

        let regional = esperarEstado("m01-lotes")
        XCTAssertFalse(regional.hasPrefix("No se"), regional)
        // De cerca, alertas sueltas: los ajenos comparten el centro de su celda.
        for _ in 0..<2 { mapa.pinch(withScale: 3, velocity: 2); sleep(1) }
        let inicio = esperarEstado("m01b-cerca")
        let pines = app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES '^[0-9]+ alertas$'"))
        print("MAPA[pines-compartidos]: \(pines.count)")

        // Varias alertas en el mismo punto: el pin abre un menú con cada una.
        if pines.count > 0 {
            pines.firstMatch.tap()
            sleep(1)
            captura("m02-menu-pin")
            let opcion = app.buttons.matching(NSPredicate(format: "label CONTAINS ' · '")).firstMatch
            if opcion.waitForExistence(timeout: 5) {
                print("MAPA[menu]: \(opcion.label)")
                opcion.tap()
                sleep(3)
                captura("m03-detalle")
                app.navigationBars.buttons.element(boundBy: 0).tap()
                // Al volver el mapa no se recentra: el estado tiene que ser el mismo.
                let vuelta = esperarEstado("m04-vuelta")
                print("MAPA[vuelta-igual]: \(vuelta == inicio)")
            }
        }

        // Mundo entero: más de una vuelta y los polos.
        for _ in 0..<4 { mapa.pinch(withScale: 0.15, velocity: -3); sleep(1) }
        let mundo = esperarEstado("m05-mundo")
        XCTAssertFalse(mundo.hasPrefix("No se"), mundo)
        XCTAssertFalse(mundo.hasPrefix("No hay"), "con el mundo a la vista: \(mundo)")

        // Sobre el antimeridiano.
        for _ in 0..<3 { mapa.swipeLeft(velocity: .slow); sleep(1) }
        let pacifico = esperarEstado("m06-antimeridiano")
        XCTAssertFalse(pacifico.hasPrefix("No se"), pacifico)

        // Cambiar el período limpia lo anterior y vuelve a pedir.
        app.buttons["7 días"].tap()
        let semana = esperarEstado("m07-siete-dias")
        XCTAssertFalse(semana.hasPrefix("No se"), semana)
    }
}

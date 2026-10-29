# Plag-Out para iPhone

Versión de [Plag-Out](https://github.com/rami-nava/PF-PLAG-OUT-26) para el productor, hecha en SwiftUI. Usa el mismo backend de producción y la misma cuenta que la app Android: lo que se carga en una se ve en la otra.

**Incluye:**
- cuenta: login, registro y recuperación de contraseña;
- terrenos y cultivos (con mapa);
- monitoreos: ciclos, biofix, alerta predictiva y tratamientos;
- alertas de plagas con mapa;
- notificaciones dentro de la app;
- tableros;
- perfil.

La administración se hace desde el [panel web](https://plag-out-admin.vercel.app); si entra una cuenta admin, la app la manda ahí.

**Diferencias con Android:**
- No hay notificaciones push: Apple las exige con una cuenta de desarrollador paga. Los avisos se ven en la campana y se actualizan al abrir la app.
- No hay modo sin conexión: sin red se muestra el error y se reintenta.

## Instalar en un iPhone (gratis, desde esta Mac)

No hace falta pagar la cuenta de desarrollador. La instalación gratis **vence a los 7 días**, así que conviene hacerla uno o dos días antes de mostrarla.

1. En la Mac: `brew install xcodegen`, y después, en la carpeta del repo, `xcodegen generate`.
2. Abrí `PlagOut.xcodeproj` en Xcode.
3. En Xcode → Settings → Accounts, agregá tu Apple ID (uno común sirve).
4. En el proyecto, target **PlagOut** → Signing & Capabilities:
   - **Team:** tu nombre (Personal Team).
   - Si Xcode se queja de que el **Bundle Identifier** está tomado, cambialo por uno propio, por ejemplo `ar.plagout.ios.tunombre`.
5. Conectá el iPhone por cable y desbloquealo. Si pregunta, tocá **Confiar en esta computadora**.
6. En el iPhone: Ajustes → Privacidad y seguridad → **Modo desarrollador** → activarlo. Se reinicia.
7. En Xcode, elegí el iPhone arriba (al lado de ▶) y apretá **▶ Run**.
8. La primera vez, el iPhone no la deja abrir. Ajustes → General → **VPN y gestión de dispositivos** → tu Apple ID → **Confiar**. Después abrí Plag-Out.

Si no hay iPhone a mano, apretá ▶ eligiendo un simulador (por ejemplo, iPhone 17).

## Guion de la demo (unos 5 minutos)

Con una cuenta de productor que ya tenga un terreno y un monitoreo:

1. **Login** con la misma cuenta que en Android.
2. **Monitoreos:** la lista con el nivel de cada uno → entrar a uno → pestañas Ciclos, Tratamientos y Detalle.
3. **Registrar presencia (biofix):** fecha y severidad → se crea el ciclo y empieza el conteo de grados-día.
4. **Tratamientos:** registrar uno con conteo antes y testigo; al cargar el conteo posterior se ve la eficacia (Henderson-Tilton).
5. **Terrenos:** el mapa del lote, sus cultivos, y crear un monitoreo desde un cultivo.
6. **Tableros:** superficie por etapa, etapas y campañas.
7. **Alertas:** la comunidad cerca de tus lotes, el mapa con los grupos y crear una alerta.
8. Para cerrar, abrir la **app Android** con la misma cuenta: está todo lo que se cargó en el iPhone.

## Estructura

- `PlagOutCore/`: paquete Swift sin pantallas, que se prueba sin simulador.
  - `PlagOutCore`: modelos, cliente de la API, errores y reglas, las mismas que en Android.
  - `PlagOutAuth`: la sesión de Supabase Auth.
- `PlagOut/`: la app SwiftUI. El proyecto de Xcode se genera desde `project.yml`, y la configuración (URLs y clave publicable) está en `PlagOut/Recursos/Config.xcconfig`.
- `PlagOutUITests/`: recorridos de pantalla contra producción con una cuenta de demo. Se corren a mano.

## Pruebas

```sh
cd PlagOutCore && swift test          # reglas, modelos y cliente; no necesita simulador
```

Los recorridos de pantalla usan una cuenta de productor de prueba. Algunos escriben datos y los borran al terminar; el nombre del test lo dice.

```sh
TEST_RUNNER_PLAGOUT_DEMO_EMAIL=... TEST_RUNNER_PLAGOUT_DEMO_PASSWORD=... \
TEST_RUNNER_PLAGOUT_CAPTURAS=/ruta/capturas \
xcodebuild test -project PlagOut.xcodeproj -scheme PlagOut \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PlagOutUITests
```

En compilaciones Debug, la app también entra sola si se lanza con `PLAGOUT_DEMO_EMAIL` y `PLAGOUT_DEMO_PASSWORD`, y abre una pantalla con `PLAGOUT_ABRIR=plagout://monitoreo/<id>`. Sin esas variables no hace nada distinto, y en Release no existe.

El CI de GitHub corre `swift test` y compila la app para el simulador en cada PR.

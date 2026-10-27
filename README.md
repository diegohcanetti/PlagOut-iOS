# Plag-Out para iPhone

Versión acotada de [Plag-Out](https://github.com/rami-nava/PF-PLAG-OUT-26) para el productor, hecha en SwiftUI. Usa el mismo backend y la misma cuenta que la app Android.

Incluye cuenta, terrenos y plantaciones, monitoreos (ciclos, biofix, predicción y tratamientos), reportes con mapa, notificaciones dentro de la app y perfil. La administración se hace desde el [panel web](https://plag-out-admin.vercel.app).

No hay notificaciones push: Apple las exige con una cuenta de desarrollador paga.

## Estructura

- `PlagOutCore/`: paquete Swift sin pantallas.
  - `PlagOutCore`: modelos, cliente de la API, errores y reglas (las mismas que Android).
  - `PlagOutAuth`: la sesión de Supabase Auth.
- `PlagOut/`: la app SwiftUI. El proyecto de Xcode se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen) desde `project.yml`.

## Probar

```sh
cd PlagOutCore && swift test     # no necesita simulador
```

// swift-tools-version:6.0
import PackageDescription

// Lo que no depende de la pantalla: modelos, cliente de la API y reglas (PlagOutCore), y la
// sesión de Supabase (PlagOutAuth). Se prueba con `swift test` en la Mac, sin simulador.
let package = Package(
    name: "PlagOutCore",
    defaultLocalization: "es",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PlagOutCore", targets: ["PlagOutCore"]),
        .library(name: "PlagOutAuth", targets: ["PlagOutAuth"]),
    ],
    dependencies: [
        // Versión exacta: una actualización de Auth se prueba antes de subirla.
        .package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.55.3"),
    ],
    targets: [
        .target(name: "PlagOutCore"),
        .target(
            name: "PlagOutAuth",
            dependencies: ["PlagOutCore", .product(name: "Auth", package: "supabase-swift")]
        ),
        .testTarget(
            name: "PlagOutCoreTests",
            dependencies: ["PlagOutCore", "PlagOutAuth"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

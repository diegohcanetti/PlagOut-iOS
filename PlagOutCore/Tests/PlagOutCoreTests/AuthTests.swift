import Foundation
import Testing
@testable import PlagOutAuth
@testable import PlagOutCore

struct AuthTests {
    @Test func mensajesDeSupabaseAuth() {
        #expect(MensajesAuth.mensaje(codigo: "invalid_credentials", estado: 400, porDefecto: "x") == "Correo o contraseña incorrectos.")
        #expect(MensajesAuth.mensaje(codigo: "user_banned", estado: 400, porDefecto: "x") == ErrorBackend.mensajeCuentaSuspendida)
        #expect(MensajesAuth.mensaje(codigo: "weak_password", estado: 422, motivos: ["length", "pwned"], porDefecto: "x")
            == "La contraseña es demasiado débil: es muy corta; apareció en filtraciones conocidas, elegí otra.")
        #expect(MensajesAuth.mensaje(codigo: "unexpected_failure", estado: 429, porDefecto: "x") == "Demasiados intentos, probá de nuevo en unos minutos.")
        #expect(MensajesAuth.mensaje(codigo: "unexpected_failure", estado: 500, porDefecto: "Por defecto") == "Por defecto")
    }

    @Test func correos() {
        #expect(MensajesAuth.emailValido(" ana@example.com "))
        #expect(!MensajesAuth.emailValido("ana@"))
        #expect(!MensajesAuth.emailValido("sin arroba.com"))
    }

    @Test func elEnlaceVencidoTraeElErrorEnElFragmento() throws {
        let vencido = try #require(URL(string: "plagout://reset-password#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid"))
        #expect(SesionSupabase.errorEnEnlace(vencido) == "access_denied")
        let valido = try #require(URL(string: "plagout://reset-password#access_token=a&refresh_token=b&type=recovery"))
        #expect(SesionSupabase.errorEnEnlace(valido) == nil)
    }
}

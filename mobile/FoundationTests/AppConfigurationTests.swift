import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct AppConfigurationTests {
    @Test("accepts an absolute HTTP endpoint")
    func acceptsAbsoluteHTTPEndpoint() throws {
        let configuration = try AppConfiguration(
            environment: "development",
            apiBaseURLString: "https://api.example.test/v1"
        )

        #expect(configuration.environment == "development")
        #expect(configuration.apiBaseURL.absoluteString == "https://api.example.test/v1")
    }

    @Test("rejects an endpoint without scheme or host")
    func rejectsInvalidEndpoint() {
        #expect(throws: AppConfigurationError.invalidAPIBaseURL) {
            try AppConfiguration(environment: "development", apiBaseURLString: "api.example.test")
        }
    }
}

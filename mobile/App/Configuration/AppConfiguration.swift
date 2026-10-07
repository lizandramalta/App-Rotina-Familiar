import Foundation

struct AppConfiguration: Sendable, Equatable {
    let environment: String
    let apiBaseURL: URL

    init(environment: String, apiBaseURLString: String) throws {
        guard let apiBaseURL = URL(string: apiBaseURLString),
              apiBaseURL.scheme != nil,
              apiBaseURL.host != nil else {
            throw AppConfigurationError.invalidAPIBaseURL
        }

        self.environment = environment
        self.apiBaseURL = apiBaseURL
    }
}

enum AppConfigurationError: Error, Equatable {
    case invalidAPIBaseURL
}

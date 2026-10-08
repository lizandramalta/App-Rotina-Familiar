import Foundation

struct AppConfiguration: Sendable, Equatable {
    private enum InfoDictionaryKey {
        static let environment = "AppEnvironment"
        static let apiBaseURL = "APIBaseURL"
    }

    let environment: String
    let apiBaseURL: URL

    init(bundle: Bundle = .main) throws {
        try self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) throws {
        guard let environment = infoDictionary[InfoDictionaryKey.environment] as? String,
              !environment.isEmpty else {
            throw AppConfigurationError.missingValue(InfoDictionaryKey.environment)
        }

        guard let apiBaseURLString = infoDictionary[InfoDictionaryKey.apiBaseURL] as? String,
              !apiBaseURLString.isEmpty else {
            throw AppConfigurationError.missingValue(InfoDictionaryKey.apiBaseURL)
        }

        try self.init(environment: environment, apiBaseURLString: apiBaseURLString)
    }

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
    case missingValue(String)
    case invalidAPIBaseURL
}

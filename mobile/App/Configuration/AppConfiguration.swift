import Foundation

struct AppConfiguration: Sendable, Equatable {
    private enum InfoDictionaryKey {
        static let environment = "AppEnvironment"
        static let apiBaseURL = "APIBaseURL"
        static let inviteLinkBaseURL = "InviteLinkBaseURL"
    }

    let environment: String
    let apiBaseURL: URL
    let inviteLinkBaseURL: URL

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

        guard let inviteLinkBaseURLString = infoDictionary[InfoDictionaryKey.inviteLinkBaseURL] as? String,
              !inviteLinkBaseURLString.isEmpty else {
            throw AppConfigurationError.missingValue(InfoDictionaryKey.inviteLinkBaseURL)
        }

        try self.init(
            environment: environment,
            apiBaseURLString: apiBaseURLString,
            inviteLinkBaseURLString: inviteLinkBaseURLString
        )
    }

    init(
        environment: String,
        apiBaseURLString: String,
        inviteLinkBaseURLString: String = "https://example.invalid"
    ) throws {
        guard let apiBaseURL = URL(string: apiBaseURLString),
              apiBaseURL.scheme != nil,
              apiBaseURL.host != nil else {
            throw AppConfigurationError.invalidAPIBaseURL
        }

        self.environment = environment
        self.apiBaseURL = apiBaseURL

        guard let inviteLinkBaseURL = URL(string: inviteLinkBaseURLString),
              inviteLinkBaseURL.scheme == "https",
              inviteLinkBaseURL.host != nil,
              inviteLinkBaseURL.user == nil,
              inviteLinkBaseURL.password == nil,
              inviteLinkBaseURL.query == nil,
              inviteLinkBaseURL.fragment == nil else {
            throw AppConfigurationError.invalidInviteLinkBaseURL
        }
        self.inviteLinkBaseURL = inviteLinkBaseURL
    }
}

enum AppConfigurationError: Error, Equatable {
    case missingValue(String)
    case invalidAPIBaseURL
    case invalidInviteLinkBaseURL
}

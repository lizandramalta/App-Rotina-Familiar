import Foundation

nonisolated struct InviteLinkParser: Sendable {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func token(from url: URL) -> String? {
        guard url.scheme == "https",
              url.host?.lowercased() == baseURL.host?.lowercased(),
              url.port == baseURL.port,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil else {
            return nil
        }

        let basePath = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let expectedPrefix = basePath.isEmpty ? "/invite/" : "/\(basePath)/invite/"
        guard url.path.hasPrefix(expectedPrefix) else {
            return nil
        }
        let token = String(url.path.dropFirst(expectedPrefix.count))
        guard !token.isEmpty, token.count <= 256,
              token.utf8.allSatisfy({ byte in
                  (65 ... 90).contains(byte) || (97 ... 122).contains(byte)
                      || (48 ... 57).contains(byte) || byte == 45 || byte == 95
              }) else {
            return nil
        }
        return token
    }
}

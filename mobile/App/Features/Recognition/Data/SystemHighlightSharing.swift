import UIKit

/// Opens WhatsApp's own compose screen with the edited text; the person picks the recipient and
/// confirms there (RN65). Requires `whatsapp` in `LSApplicationQueriesSchemes` for `canOpenURL`.
@MainActor
final class SystemHighlightSharing: HighlightSharing {
    var canOpenWhatsApp: Bool {
        guard let url = URL(string: "whatsapp://send") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    func openWhatsApp(text: String) async -> Bool {
        var components = URLComponents()
        components.scheme = "whatsapp"
        components.host = "send"
        components.queryItems = [URLQueryItem(name: "text", value: text)]
        guard let url = components.url else { return false }
        return await UIApplication.shared.open(url)
    }

    func copy(text: String) {
        UIPasteboard.general.string = text
    }
}

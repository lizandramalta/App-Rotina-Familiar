import Foundation

enum TimeZoneDisplay {
    /// "America/Sao_Paulo" → "Sao Paulo".
    static func city(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier)
            .replacingOccurrences(of: "_", with: " ")
    }
}

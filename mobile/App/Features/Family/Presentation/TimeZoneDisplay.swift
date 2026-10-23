import Foundation

nonisolated struct FamilyTimeZoneOption: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let identifier: String

    var subtitle: String { identifier }
}

nonisolated enum TimeZoneDisplay {
    /// Curated list matching Figma TEL-053 and Brazilian/Portuguese context
    static let standardOptions: [FamilyTimeZoneOption] = [
        FamilyTimeZoneOption(id: "America/Sao_Paulo", name: "Horário de Brasília", identifier: "America/Sao_Paulo"),
        FamilyTimeZoneOption(id: "America/Manaus", name: "Horário do Amazonas", identifier: "America/Manaus"),
        FamilyTimeZoneOption(id: "America/Rio_Branco", name: "Horário do Acre", identifier: "America/Rio_Branco"),
        FamilyTimeZoneOption(id: "America/Noronha", name: "Fernando de Noronha", identifier: "America/Noronha"),
        FamilyTimeZoneOption(id: "Europe/Lisbon", name: "Horário de Lisboa", identifier: "Europe/Lisbon"),
    ]

    static func displayName(for identifier: String) -> String {
        if let option = standardOptions.first(where: { $0.identifier == identifier }) {
            return option.name
        }
        return city(identifier)
    }

    /// "America/Sao_Paulo" → "Sao Paulo".
    static func city(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier)
            .replacingOccurrences(of: "_", with: " ")
    }
}

import Foundation

enum FoundationTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case explore
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home:
            String(localized: "foundation.tab.home")
        case .explore:
            String(localized: "foundation.tab.explore")
        case .settings:
            String(localized: "foundation.tab.settings")
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .explore:
            "safari"
        case .settings:
            "gearshape"
        }
    }

    var initialRoute: FoundationRoute {
        .placeholder(tab: self)
    }
}

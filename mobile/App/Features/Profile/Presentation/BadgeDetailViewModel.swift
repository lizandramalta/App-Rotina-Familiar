import Foundation
import Observation

/// TEL-054 — Detalhe do marco (SPEC-006 CA-11, UX-006 §5.3). Only reachable from a conquered milestone.
@MainActor
@Observable
final class BadgeDetailViewModel: Identifiable {
    enum State: Equatable {
        case loading
        case loaded(BadgeDetail)
        case error
    }

    private let item: BadgeDisplayItem
    private let awardID: UUID
    private let role: MemberRole
    private let repository: any ProfileRepository
    private let sessionStore: AppSessionStore

    private(set) var state: State = .loading
    /// Opens the typed TEL-021 placeholder; closing it returns to this screen.
    var selectedMission: ContributingMission?

    init(
        item: BadgeDisplayItem,
        awardID: UUID,
        role: MemberRole,
        repository: any ProfileRepository,
        sessionStore: AppSessionStore
    ) {
        self.item = item
        self.awardID = awardID
        self.role = role
        self.repository = repository
        self.sessionStore = sessionStore
    }

    func load() async {
        state = .loading
        guard let accessToken = sessionStore.accessToken else {
            state = .error
            return
        }
        do {
            let detail = try await repository.getBadgeDetail(awardID: awardID, accessToken: accessToken)
            guard !Task.isCancelled else { return }
            state = .loaded(detail)
        } catch {
            guard !Task.isCancelled else { return }
            state = .error
        }
    }

    var tier: BadgeTier { item.tier }

    var headerTitle: String {
        String(
            format: String(localized: "profile.badge_detail.title"),
            ProfileViewModel.tierName(item.tier),
            item.requiredMissionCount
        )
    }

    var awardedDateText: String {
        guard case let .loaded(detail) = state else {
            return String(localized: "profile.badge_detail.loading_date")
        }
        return String(format: String(localized: "profile.badge_detail.awarded_at"), Self.formatted(detail.awardedAt))
    }

    var sectionTitle: String {
        role == .kid
            ? String(localized: "profile.badge_detail.section_kids")
            : String(localized: "profile.badge_detail.section")
    }

    var missions: [ContributingMission] {
        guard case let .loaded(detail) = state else { return [] }
        return detail.contributingMissions
    }

    func completedDateText(for mission: ContributingMission) -> String {
        String(format: String(localized: "profile.badge_detail.completed_at"), Self.formatted(mission.completedAt))
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(Locale(identifier: "pt_BR")))
    }
}

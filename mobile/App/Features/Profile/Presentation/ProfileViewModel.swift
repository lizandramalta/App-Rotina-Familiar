import Foundation
import Observation

/// TEL-030 — Meu perfil (SPEC-006 CA-01/CA-10, UX-006 §5.1). Editing (MOD-009) and the milestone detail
/// (TEL-054) hook into `isShowingEditor` and `selectedBadgeForDetail`.
@MainActor
@Observable
final class ProfileViewModel {
    enum State: Equatable {
        case loading
        case loaded
        case error
    }

    private let repository: any ProfileRepository
    private let familyRepository: (any FamilyRepository)?
    private let sessionStore: AppSessionStore
    private let photoNormalizer: any ProfilePhotoNormalizing
    let session: ActiveFamilySession

    private(set) var state: State = .loading
    private(set) var profile: OwnProfile?
    private(set) var badges: BadgesOverview?
    private(set) var avatarData: Data?
    private(set) var badgeItems: [BadgeDisplayItem] = []

    var selectedBadgeForDetail: BadgeDisplayItem?
    /// MOD-009 is presented while this is set (`.sheet(item:)`).
    private(set) var editor: OwnProfileEditorViewModel?
    var isShowingLeaveAdminPlaceholder = false
    private(set) var isLeavingAdministration = false
    private(set) var leaveAdministrationFailed = false

    private var avatarMediaID: String?

    init(
        repository: any ProfileRepository,
        sessionStore: AppSessionStore,
        session: ActiveFamilySession,
        familyRepository: (any FamilyRepository)? = nil,
        photoNormalizer: any ProfilePhotoNormalizing = ProfilePhotoNormalizer()
    ) {
        self.repository = repository
        self.familyRepository = familyRepository
        self.sessionStore = sessionStore
        self.photoNormalizer = photoNormalizer
        self.session = session
    }

    var isKid: Bool { session.role == .kid }

    var isShowingEditor: Bool {
        get { editor != nil }
        set {
            if newValue { startEditing() } else { editor = nil }
        }
    }

    /// Opens MOD-009 with the data on screen; saving updates this screen at once (UX-006 §4).
    func startEditing() {
        guard let profile, editor == nil else { return }
        editor = OwnProfileEditorViewModel(
            initialProfile: profile,
            initialAvatarData: avatarData,
            role: session.role,
            repository: repository,
            photoNormalizer: photoNormalizer,
            sessionStore: sessionStore,
            onSaved: { [weak self] updated, avatar in
                self?.applyUpdatedProfile(updated, avatarData: avatar)
            },
            onDismiss: { [weak self] in
                self?.editor = nil
            }
        )
    }

    func makeBadgeDetailViewModel(for item: BadgeDisplayItem) -> BadgeDetailViewModel? {
        guard let awardID = item.awardID else { return nil }
        return BadgeDetailViewModel(
            item: item,
            awardID: awardID,
            role: session.role,
            repository: repository,
            sessionStore: sessionStore
        )
    }

    func dismissEditor() {
        editor = nil
    }

    // MARK: Loading

    func load() async {
        if state != .loaded {
            state = .loading
        }
        guard let accessToken = sessionStore.accessToken else {
            state = .error
            return
        }

        do {
            async let loadedProfile = repository.getOwnProfile(accessToken: accessToken)
            async let loadedBadges = repository.getOwnBadges(accessToken: accessToken)
            let (profile, badges) = try await (loadedProfile, loadedBadges)
            guard !Task.isCancelled else { return }
            self.profile = profile
            self.badges = badges
            badgeItems = badges.displayItems()
            state = .loaded
            await loadAvatar(for: profile, accessToken: accessToken)
        } catch {
            guard !Task.isCancelled else { return }
            // A refresh failure keeps the content already on screen; only the first load shows the error card.
            if profile == nil || badges == nil {
                state = .error
            }
        }
    }

    /// Best effort: a photo that cannot be downloaded keeps the default avatar instead of failing the screen.
    private func loadAvatar(for profile: OwnProfile, accessToken: String) async {
        guard let mediaID = profile.photoMediaID else {
            avatarData = nil
            avatarMediaID = nil
            return
        }
        guard mediaID != avatarMediaID || avatarData == nil else { return }
        let data = try? await repository.getMediaContent(mediaID: mediaID, accessToken: accessToken)
        guard !Task.isCancelled else { return }
        avatarData = data
        avatarMediaID = data == nil ? nil : mediaID
    }

    /// Called by MOD-009 after saving. `avatarData`: `nil` keeps the current bytes, `.some(nil)` removes them.
    func applyUpdatedProfile(_ updated: OwnProfile, avatarData newAvatarData: Data?? = nil) {
        profile = updated
        if let newAvatarData {
            avatarData = newAvatarData
            avatarMediaID = newAvatarData == nil ? nil : updated.photoMediaID
        }
        if updated.photoMediaID == nil {
            avatarData = nil
            avatarMediaID = nil
        }
    }

    // MARK: Identity

    var roleTitle: String {
        switch session.role {
        case .administrator: String(localized: "family.member.role.administrator")
        case .member: String(localized: "family.member.role.member")
        case .kid: String(localized: "family.member.role.kids")
        }
    }

    var displayTitle: String {
        guard let profile else { return "" }
        return profile.nickname ?? profile.name
    }

    var displaySubtitle: String {
        guard let profile else { return "" }
        if profile.nickname != nil {
            return String(format: String(localized: "profile.identity.subtitle_name_role"), profile.name, roleTitle)
        }
        return String(format: String(localized: "profile.identity.subtitle_role_family"), roleTitle, profile.familyName)
    }

    // MARK: Role in the family (adults only)

    var showsRoleSection: Bool { !isKid }

    var canLeaveAdministration: Bool {
        session.role == .administrator && !session.isFamilyCreator
    }

    /// SPEC-003 CA-05: only a confirmed response changes the local role.
    func leaveAdministration() async {
        guard canLeaveAdministration, !isLeavingAdministration,
              let familyRepository, let token = sessionStore.accessToken else { return }
        isLeavingAdministration = true
        leaveAdministrationFailed = false
        defer { isLeavingAdministration = false }
        do {
            let confirmed = try await familyRepository.leaveAdministration(accessToken: token)
            guard confirmed.id == session.memberID, confirmed.role == .member else {
                leaveAdministrationFailed = true
                return
            }
            isShowingLeaveAdminPlaceholder = false
            sessionStore.applyConfirmedRole(.member)
        } catch {
            leaveAdministrationFailed = true
        }
    }

    var roleFooter: String {
        if session.role == .member {
            return String(localized: "profile.role.footer_member")
        }
        return canLeaveAdministration
            ? String(localized: "profile.role.footer_admin")
            : String(localized: "profile.role.footer_creator")
    }

    // MARK: Achievements

    var totalParticipations: Int { badges?.totalParticipations ?? profile?.totalParticipations ?? 0 }

    var totalText: String {
        let count = totalParticipations
        switch (isKid, count == 1) {
        case (false, true): return String(localized: "profile.badges.total_one")
        case (true, true): return String(localized: "profile.badges.total_kids_one")
        case (false, false): return String(format: String(localized: "profile.badges.total"), count)
        case (true, false): return String(format: String(localized: "profile.badges.total_kids"), count)
        }
    }

    var nextTierText: String {
        guard let next = badges?.nextTier else {
            return String(localized: "profile.badges.all_conquered")
        }
        return String(
            format: String(localized: "profile.badges.next_tier"),
            next.remaining,
            Self.targetName(of: next.code)
        )
    }

    /// Share of the way to the next milestone, 1 once every milestone is conquered.
    var progressFraction: Double {
        guard let next = badges?.nextTier, next.requiredMissionCount > 0 else { return 1 }
        return min(max(Double(totalParticipations) / Double(next.requiredMissionCount), 0), 1)
    }

    var badgesFooter: String {
        if isKid {
            return String(localized: "profile.badges.footer_kids")
        }
        return totalParticipations == 0
            ? String(localized: "profile.badges.footer_empty")
            : String(localized: "profile.badges.footer")
    }

    func missionsRemaining(for item: BadgeDisplayItem) -> Int {
        max(item.requiredMissionCount - totalParticipations, 0)
    }

    func selectBadge(_ item: BadgeDisplayItem) {
        // UX-04: only a conquered milestone opens TEL-054; pending ones are not tappable.
        guard item.isConquered, item.awardID != nil else { return }
        selectedBadgeForDetail = item
    }

    static func tierName(_ tier: BadgeTier) -> String {
        switch tier {
        case .bronze: String(localized: "profile.tier.bronze")
        case .silver: String(localized: "profile.tier.silver")
        case .gold: String(localized: "profile.tier.gold")
        case .diamond: String(localized: "profile.tier.diamond")
        }
    }

    /// Carries the article ("o ouro", "a prata") the "Faltam N para …" sentence needs.
    static func targetName(of tier: BadgeTier) -> String {
        switch tier {
        case .bronze: String(localized: "profile.tier.bronze.target")
        case .silver: String(localized: "profile.tier.silver.target")
        case .gold: String(localized: "profile.tier.gold.target")
        case .diamond: String(localized: "profile.tier.diamond.target")
        }
    }
}

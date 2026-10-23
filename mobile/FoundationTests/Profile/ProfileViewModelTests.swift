import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct ProfileViewModelTests {
    // MARK: Loading (CA-01, CA-15)

    @Test("SPEC-006 CA-01 loads profile and badges with the session token and ends loaded")
    func loadSuccess() async {
        let harness = Harness()

        #expect(harness.viewModel.state == .loading)
        await harness.viewModel.load()

        #expect(harness.viewModel.state == .loaded)
        #expect(harness.viewModel.profile?.familyName == "Família Silva")
        #expect(harness.viewModel.badgeItems.map(\.tier) == [.bronze, .silver, .gold, .diamond])
        #expect(await harness.repository.tokens == ["access-1", "access-1"])
    }

    @Test("SPEC-006 CA-15 downloads the photo when the profile has one")
    func loadsAvatar() async {
        let bytes = Data([0xFF, 0xD8])
        let harness = Harness(profile: Fixtures.profile(photoMediaID: "media-1"), mediaResult: .success(bytes))

        await harness.viewModel.load()

        #expect(harness.viewModel.avatarData == bytes)
        #expect(await harness.repository.requestedMedia == ["media-1"])
    }

    @Test("SPEC-006 CA-15 a failed photo download keeps the screen loaded with the default avatar")
    func avatarFailureIsBestEffort() async {
        let harness = Harness(
            profile: Fixtures.profile(photoMediaID: "media-1"),
            mediaResult: .failure(ProfileError.notFound)
        )

        await harness.viewModel.load()

        #expect(harness.viewModel.state == .loaded)
        #expect(harness.viewModel.avatarData == nil)
    }

    @Test("a profile without photo never asks for media content")
    func noPhotoNoDownload() async {
        let harness = Harness()

        await harness.viewModel.load()

        #expect(await harness.repository.requestedMedia.isEmpty)
        #expect(harness.viewModel.avatarData == nil)
    }

    @Test("loading failure shows the error state and a retry recovers")
    func errorThenRetry() async {
        let harness = Harness(profileResults: [.failure(ProfileError.network), .success(Fixtures.profile())])

        await harness.viewModel.load()
        #expect(harness.viewModel.state == .error)

        await harness.viewModel.load()
        #expect(harness.viewModel.state == .loaded)
        #expect(harness.viewModel.profile != nil)
    }

    @Test("a badges failure also ends in the error state")
    func badgesFailure() async {
        let harness = Harness(badgesResult: .failure(ProfileError.unavailable))

        await harness.viewModel.load()

        #expect(harness.viewModel.state == .error)
    }

    @Test("without an access token the load ends in the error state")
    func noToken() async {
        let harness = Harness(signedIn: false)

        await harness.viewModel.load()

        #expect(harness.viewModel.state == .error)
    }

    // MARK: Identity (E-04)

    @Test("SPEC-006 E-04 without nickname the title is the name and the subtitle is role · family")
    func identityWithoutNickname() async {
        for (role, subtitle) in [
            (MemberRole.administrator, "Administrador · Família Silva"),
            (.member, "Membro · Família Silva"),
            (.kid, "Kids · Família Silva"),
        ] {
            let harness = Harness(role: role)
            await harness.viewModel.load()
            #expect(harness.viewModel.displayTitle == "Maria Silva")
            #expect(harness.viewModel.displaySubtitle == subtitle)
        }
    }

    @Test("SPEC-006 E-04 with nickname the title is the nickname and the subtitle is name · role")
    func identityWithNickname() async {
        let profile = Fixtures.profile(name: "Jô", nickname: "Jojô")
        for (role, subtitle) in [
            (MemberRole.administrator, "Jô · Administrador"),
            (.member, "Jô · Membro"),
            (.kid, "Jô · Kids"),
        ] {
            let harness = Harness(role: role, profile: profile)
            await harness.viewModel.load()
            #expect(harness.viewModel.displayTitle == "Jojô")
            #expect(harness.viewModel.displaySubtitle == subtitle)
        }
    }

    // MARK: Role in the family

    @Test("the creator sees the role section without the leave action")
    func roleCreator() {
        let harness = Harness(role: .administrator, isCreator: true)

        #expect(harness.viewModel.showsRoleSection)
        #expect(!harness.viewModel.canLeaveAdministration)
        #expect(harness.viewModel.roleFooter == "O Criador da família não pode deixar a administração.")
    }

    @Test("a non-creator administrator can leave the administration")
    func roleAdmin() {
        let harness = Harness(role: .administrator, isCreator: false)

        #expect(harness.viewModel.showsRoleSection)
        #expect(harness.viewModel.canLeaveAdministration)
        #expect(
            harness.viewModel.roleFooter
                == "Ao deixar a administração, você passa a ser Membro. Para voltar, outro Administrador precisa promover você."
        )
    }

    @Test("a member sees the role section with the management footer and no leave action")
    func roleMember() {
        let harness = Harness(role: .member)

        #expect(harness.viewModel.showsRoleSection)
        #expect(!harness.viewModel.canLeaveAdministration)
        #expect(harness.viewModel.roleFooter == "A gestão de membros e das configurações da família fica com os Administradores.")
    }

    @Test("Kids never see the role section")
    func roleKids() {
        let harness = Harness(role: .kid)

        #expect(!harness.viewModel.showsRoleSection)
        #expect(!harness.viewModel.canLeaveAdministration)
    }

    // MARK: Achievements (CA-10)

    @Test("SPEC-006 CA-10 with no participations: zero total, bronze target, starter footer")
    func emptyAchievements() async {
        let harness = Harness(badges: Fixtures.badges(total: 0, awards: [], next: (.bronze, 5, 5)))
        await harness.viewModel.load()

        #expect(harness.viewModel.totalText == "0 missões com participação")
        #expect(harness.viewModel.nextTierText == "Faltam 5 para o bronze")
        #expect(harness.viewModel.progressFraction == 0)
        #expect(harness.viewModel.badgesFooter == "Participe de uma missão da família para começar. Cada missão encerrada com a sua participação conta uma vez.")
        #expect(harness.viewModel.badgeItems.allSatisfy { !$0.isConquered })
        #expect(harness.viewModel.missionsRemaining(for: harness.viewModel.badgeItems[0]) == 5)
    }

    @Test("with achievements the cumulative footer, next tier and progress follow the data")
    func achievements() async {
        let harness = Harness()
        await harness.viewModel.load()

        #expect(harness.viewModel.totalText == "7 missões com participação")
        #expect(harness.viewModel.nextTierText == "Faltam 3 para a prata")
        #expect(harness.viewModel.progressFraction == 0.7)
        #expect(harness.viewModel.badgesFooter == "Cada missão encerrada com a sua participação conta uma vez. Os marcos são cumulativos.")
    }

    @Test("Kids get the kid wording for total and footer")
    func kidsWording() async {
        let harness = Harness(role: .kid)
        await harness.viewModel.load()

        #expect(harness.viewModel.totalText == "7 missões com você")
        #expect(harness.viewModel.badgesFooter == "Cada missão da família em que você ajudou conta uma vez.")
    }

    @Test("once every milestone is conquered the progress is complete and there is no next target")
    func allConquered() async {
        let awards = BadgeTier.allCases.map {
            BadgeAward(awardID: UUID(), tier: $0, requiredMissionCount: $0.requiredMissionCount, awardedAt: .now)
        }
        let harness = Harness(badges: BadgesOverview(totalParticipations: 50, nextTier: nil, awards: awards))
        await harness.viewModel.load()

        #expect(harness.viewModel.nextTierText == "Todos os marcos conquistados")
        #expect(harness.viewModel.progressFraction == 1)
    }

    @Test("singular wording for one participation")
    func singular() async {
        let harness = Harness(badges: Fixtures.badges(total: 1, awards: [], next: (.bronze, 5, 4)))
        await harness.viewModel.load()

        #expect(harness.viewModel.totalText == "1 missão com participação")
    }

    // MARK: Selection (UX-04)

    @Test("UX-04 tapping a conquered milestone selects it for the detail")
    func selectConquered() async throws {
        let harness = Harness()
        await harness.viewModel.load()
        let bronze = try #require(harness.viewModel.badgeItems.first { $0.tier == .bronze })

        harness.viewModel.selectBadge(bronze)

        #expect(harness.viewModel.selectedBadgeForDetail == bronze)
    }

    @Test("UX-04 tapping a pending milestone is ignored")
    func selectPending() async throws {
        let harness = Harness()
        await harness.viewModel.load()
        let silver = try #require(harness.viewModel.badgeItems.first { $0.tier == .silver })

        harness.viewModel.selectBadge(silver)

        #expect(harness.viewModel.selectedBadgeForDetail == nil)
    }

    // MARK: After editing

    @Test("MOD-009 saving updates the profile and the avatar at once; omitted avatar keeps the current one")
    func applyUpdatedProfile() async {
        let harness = Harness(profile: Fixtures.profile(photoMediaID: "media-1"), mediaResult: .success(Data([1])))
        await harness.viewModel.load()

        harness.viewModel.applyUpdatedProfile(Fixtures.profile(nickname: "Mari", photoMediaID: "media-1"))
        #expect(harness.viewModel.displayTitle == "Mari")
        #expect(harness.viewModel.avatarData == Data([1]))

        harness.viewModel.applyUpdatedProfile(Fixtures.profile(photoMediaID: "media-2"), avatarData: Data([2]))
        #expect(harness.viewModel.avatarData == Data([2]))

        harness.viewModel.applyUpdatedProfile(Fixtures.profile(photoMediaID: nil), avatarData: .some(nil))
        #expect(harness.viewModel.avatarData == nil)
    }
}

// MARK: - Fixtures and doubles

private enum Fixtures {
    static func profile(name: String = "Maria Silva", nickname: String? = nil, photoMediaID: String? = nil) -> OwnProfile {
        OwnProfile(
            memberID: UUID(),
            name: name,
            familyName: "Família Silva",
            nickname: nickname,
            photoMediaID: photoMediaID,
            totalParticipations: 7,
            nextTier: NextBadgeTier(code: .silver, requiredMissionCount: 10, remaining: 3)
        )
    }

    static func badges(
        total: Int = 7,
        awards: [BadgeAward]? = nil,
        next: (BadgeTier, Int, Int)? = (.silver, 10, 3)
    ) -> BadgesOverview {
        BadgesOverview(
            totalParticipations: total,
            nextTier: next.map { NextBadgeTier(code: $0.0, requiredMissionCount: $0.1, remaining: $0.2) },
            awards: awards ?? [
                BadgeAward(awardID: UUID(), tier: .bronze, requiredMissionCount: 5, awardedAt: Date(timeIntervalSince1970: 1_790_000_000)),
            ]
        )
    }
}

private actor ProfileRepositorySpy: ProfileRepository {
    private var profileResults: [Result<OwnProfile, Error>]
    private let badgesResult: Result<BadgesOverview, Error>
    private let mediaResult: Result<Data, Error>
    private(set) var tokens: [String] = []
    private(set) var requestedMedia: [String] = []

    init(profileResults: [Result<OwnProfile, Error>], badgesResult: Result<BadgesOverview, Error>, mediaResult: Result<Data, Error>) {
        self.profileResults = profileResults
        self.badgesResult = badgesResult
        self.mediaResult = mediaResult
    }

    func getOwnProfile(accessToken: String) async throws -> OwnProfile {
        tokens.append(accessToken)
        let result = profileResults.count > 1 ? profileResults.removeFirst() : profileResults[0]
        return try result.get()
    }

    func updateOwnProfile(_ command: UpdateOwnProfileCommand, accessToken: String) async throws -> OwnProfile {
        try profileResults[0].get()
    }

    func getOwnBadges(accessToken: String) async throws -> BadgesOverview {
        tokens.append(accessToken)
        return try badgesResult.get()
    }

    func getBadgeDetail(awardID: UUID, accessToken: String) async throws -> BadgeDetail {
        throw ProfileError.unavailable
    }

    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String {
        throw ProfileError.unavailable
    }

    func getMediaContent(mediaID: String, accessToken: String) async throws -> Data {
        requestedMedia.append(mediaID)
        return try mediaResult.get()
    }
}

@MainActor
private struct Harness {
    let repository: ProfileRepositorySpy
    let viewModel: ProfileViewModel

    init(
        role: MemberRole = .member,
        isCreator: Bool = false,
        profile: OwnProfile = Fixtures.profile(),
        profileResults: [Result<OwnProfile, Error>]? = nil,
        badges: BadgesOverview = Fixtures.badges(),
        badgesResult: Result<BadgesOverview, Error>? = nil,
        mediaResult: Result<Data, Error> = .success(Data([1])),
        signedIn: Bool = true
    ) {
        repository = ProfileRepositorySpy(
            profileResults: profileResults ?? [.success(profile)],
            badgesResult: badgesResult ?? .success(badges),
            mediaResult: mediaResult
        )
        let sessionStore = AppSessionStore(
            repository: AccessRepositoryStub(),
            credentialStore: FamilyCredentialStoreStub(),
            installationProofProvider: FamilyInstallationProofStub()
        )
        let active = ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: role, isFamilyCreator: isCreator)
        if signedIn {
            sessionStore.apply(.session(AuthenticatedSession(
                sessionID: UUID(),
                profile: active,
                credentials: SessionCredentials(
                    token: SessionToken(accessToken: "access-1", expiresAt: .distantFuture),
                    refreshToken: "refresh-1"
                )
            )))
        }
        viewModel = ProfileViewModel(repository: repository, sessionStore: sessionStore, session: active)
    }
}

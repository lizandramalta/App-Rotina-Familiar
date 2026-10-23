import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct BadgeDetailViewModelTests {
    private static let awardedAt = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21 14:13 UTC
    private static let mission = ContributingMission(
        missionID: UUID(),
        title: "Organizar a sala",
        completedAt: Date(timeIntervalSince1970: 1_789_050_000)
    )

    private func makeHarness(
        role: MemberRole = .member,
        results: [Result<BadgeDetail, Error>]? = nil
    ) -> (viewModel: BadgeDetailViewModel, repository: DetailRepositorySpy) {
        let detail = BadgeDetail(
            awardID: UUID(),
            tier: .silver,
            awardedAt: Self.awardedAt,
            contributingMissions: [Self.mission]
        )
        let repository = DetailRepositorySpy(results: results ?? [.success(detail)])
        let sessionStore = AppSessionStore(
            repository: AccessRepositoryStub(),
            credentialStore: FamilyCredentialStoreStub(),
            installationProofProvider: FamilyInstallationProofStub()
        )
        sessionStore.apply(.session(AuthenticatedSession(
            sessionID: UUID(),
            profile: ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: role, isFamilyCreator: false),
            credentials: SessionCredentials(
                token: SessionToken(accessToken: "access-1", expiresAt: .distantFuture),
                refreshToken: "refresh-1"
            )
        )))
        let item = BadgeDisplayItem(
            tier: .silver,
            requiredMissionCount: 10,
            awardID: detail.awardID,
            awardedAt: Self.awardedAt,
            isConquered: true,
            isNextTarget: false
        )
        let viewModel = BadgeDetailViewModel(
            item: item,
            awardID: detail.awardID,
            role: role,
            repository: repository,
            sessionStore: sessionStore
        )
        return (viewModel, repository)
    }

    @Test("starts loading with the tier header and a loading date")
    func initialState() {
        let (viewModel, _) = makeHarness()

        #expect(viewModel.state == .loading)
        #expect(viewModel.headerTitle == "Prata · 10 missões")
        #expect(viewModel.awardedDateText == "Carregando…")
        #expect(viewModel.missions.isEmpty)
    }

    @Test("SPEC-006 CA-11 loads the contributing missions with award and completion dates")
    func loaded() async {
        let (viewModel, repository) = makeHarness()

        await viewModel.load()

        #expect(viewModel.missions == [Self.mission])
        #expect(viewModel.awardedDateText == "Conquistado em 21 de setembro de 2026")
        #expect(viewModel.completedDateText(for: Self.mission) == "Concluída em 10 de setembro de 2026")
        #expect(await repository.tokens == ["access-1"])
    }

    @Test("the section title depends on the role")
    func sectionTitle() {
        #expect(makeHarness(role: .administrator).viewModel.sectionTitle == "Missões que contaram")
        #expect(makeHarness(role: .member).viewModel.sectionTitle == "Missões que contaram")
        #expect(makeHarness(role: .kid).viewModel.sectionTitle == "Missões em que você ajudou")
    }

    @Test("a failure ends in the error state and a retry recovers")
    func errorThenRetry() async {
        for failure in [ProfileError.notFound, .network] {
            let detail = BadgeDetail(awardID: UUID(), tier: .silver, awardedAt: Self.awardedAt, contributingMissions: [Self.mission])
            let (viewModel, _) = makeHarness(results: [.failure(failure), .success(detail)])

            await viewModel.load()
            #expect(viewModel.state == .error)

            await viewModel.load()
            #expect(viewModel.missions == [Self.mission])
        }
    }

    @Test("selecting a contributing mission exposes it for the TEL-021 placeholder")
    func selectMission() async {
        let (viewModel, _) = makeHarness()
        await viewModel.load()

        viewModel.selectedMission = viewModel.missions.first
        #expect(viewModel.selectedMission == Self.mission)

        viewModel.selectedMission = nil
        #expect(viewModel.selectedMission == nil)
    }
}

actor DetailRepositorySpy: ProfileRepository {
    private var results: [Result<BadgeDetail, Error>]
    private(set) var tokens: [String] = []

    init(results: [Result<BadgeDetail, Error>]) {
        self.results = results
    }

    func getBadgeDetail(awardID: UUID, accessToken: String) async throws -> BadgeDetail {
        tokens.append(accessToken)
        let result = results.count > 1 ? results.removeFirst() : results[0]
        return try result.get()
    }

    func getOwnProfile(accessToken: String) async throws -> OwnProfile { throw ProfileError.unavailable }
    func updateOwnProfile(_ command: UpdateOwnProfileCommand, accessToken: String) async throws -> OwnProfile { throw ProfileError.unavailable }
    func getOwnBadges(accessToken: String) async throws -> BadgesOverview { throw ProfileError.unavailable }
    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String { throw ProfileError.unavailable }
    func getMediaContent(mediaID: String, accessToken: String) async throws -> Data { throw ProfileError.unavailable }
}

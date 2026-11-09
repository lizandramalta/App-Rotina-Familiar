import Foundation
@testable import FamilyRoutine
import Testing

/// Deterministic draw: returns the scripted indexes in order, then repeats the last one.
private final class ScriptedDrawing: RewardDrawing, @unchecked Sendable {
    private let lock = NSLock()
    private var indexes: [Int]

    init(_ indexes: [Int]) { self.indexes = indexes }

    func drawIndex(count: Int) -> Int {
        lock.withLock { indexes.count > 1 ? indexes.removeFirst() : (indexes.first ?? 0) }
    }
}

/// TEL-024 — SPEC-017 Fase 2 (CA-06, CA-07, CA-08), UX-017 §6, decisões R-1/R-2 · SCRUM-90.
@MainActor
struct RewardWheelViewModelTests {
    private static let pizza = rewardRepositorySpyFixture
    private static let movie = RewardItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000f3")!,
        title: "Escolher o filme da noite",
        details: nil,
        source: .predefined,
        createdAt: nil
    )

    private func makeViewModel(
        missions: MissionRepositorySpy = MissionRepositorySpy(),
        rewards: RewardRepositorySpy = RewardRepositorySpy(
            rewardItemsResult: .success(RewardCatalog(predefined: [movie], custom: [pizza]))
        ),
        draws: [Int] = [1]
    ) -> RewardWheelViewModel {
        RewardWheelViewModel(
            missionID: missionRepositorySpyFixture.id,
            missionTitle: "Semana organizada",
            missionRepository: missions,
            rewardRepository: rewards,
            accessToken: "token",
            drawing: ScriptedDrawing(draws),
            spinDuration: .zero
        )
    }

    private func drawn(_ viewModel: RewardWheelViewModel) async {
        await viewModel.load()
        await viewModel.draw(reduceMotion: true)
    }

    @Test("UX-017 Loading/Ready: draw is unavailable until the eligible catalog is loaded")
    func loadsCatalogBeforeDrawing() async {
        let viewModel = makeViewModel()
        #expect(!viewModel.canDraw)

        await viewModel.load()

        #expect(viewModel.items.map(\.id) == [Self.movie.id, Self.pizza.id])
        #expect(viewModel.canDraw)
        #expect(!viewModel.canAccept)
    }

    @Test("UX-017 a failed catalog load offers retry and never draws")
    func catalogFailure() async {
        let viewModel = makeViewModel(rewards: RewardRepositorySpy(rewardItemsResult: .failure(RewardItemError.network)))

        await viewModel.load()

        #expect(viewModel.catalogState == .failed)
        #expect(!viewModel.canDraw)
    }

    @Test("CA-06 drawing again and leaving never call the server nor consume the redemption")
    func drawsLocallyOnly() async {
        let missions = MissionRepositorySpy()
        let viewModel = makeViewModel(missions: missions, draws: [1, 0])

        await drawn(viewModel)
        #expect(viewModel.selectedItem == Self.pizza)
        #expect(viewModel.phase == .result)

        await viewModel.draw(reduceMotion: true)
        #expect(viewModel.selectedItem == Self.movie)

        #expect(missions.acceptCalls.isEmpty)
        #expect(missions.missionCalls.isEmpty)
        #expect(viewModel.confirmedReward == nil)
    }

    @Test("the wheel lands the drawn slice under the top pointer")
    func wheelGeometry() {
        let rotation = RewardWheelGeometry.rotation(landingOn: 1, count: 4, from: 0, fullTurns: 4)
        let slice = RewardWheelGeometry.sliceAngle(count: 4)
        let centre = 1 * slice + slice / 2
        #expect((centre + rotation).truncatingRemainder(dividingBy: 360) == 0)
        #expect(rotation >= 4 * 360)
    }

    @Test("CA-08 the acceptance is confirmed only by the server's snapshot")
    func acceptsDrawnItem() async {
        let missions = MissionRepositorySpy()
        missions.setAcceptResults([.success(AcceptedMissionReward(rewardItemID: Self.pizza.id, title: "Noite de pizza"))])
        let viewModel = makeViewModel(missions: missions)
        await drawn(viewModel)

        await viewModel.accept()

        #expect(missions.acceptCalls.count == 1)
        #expect(missions.acceptCalls.first?.rewardItemID == Self.pizza.id)
        #expect(viewModel.confirmedReward?.title == "Noite de pizza")
    }

    @Test("UX-CA-03 a second accept while the first is pending is ignored")
    func blocksDuplicateAccept() async {
        let missions = MissionRepositorySpy()
        let viewModel = makeViewModel(missions: missions)
        await drawn(viewModel)

        async let first: Void = viewModel.accept()
        async let second: Void = viewModel.accept()
        _ = await (first, second)

        #expect(missions.acceptCalls.count == 1)
    }

    @Test("CA-05/R-1 a concurrent accept shows the already-chosen alert without confirming")
    func alreadyAccepted() async {
        let missions = MissionRepositorySpy()
        missions.setAcceptResults([.failure(RewardAcceptanceError.alreadyAccepted)])
        let viewModel = makeViewModel(missions: missions)
        await drawn(viewModel)

        await viewModel.accept()

        #expect(viewModel.alert == .alreadyAccepted)
        #expect(viewModel.confirmedReward == nil)
    }

    @Test("R-1 an unavailable redemption shows its alert")
    func unavailable() async {
        let missions = MissionRepositorySpy()
        missions.setAcceptResults([.failure(RewardAcceptanceError.unavailable)])
        let viewModel = makeViewModel(missions: missions)
        await drawn(viewModel)

        await viewModel.accept()

        #expect(viewModel.alert == .unavailable)
    }

    @Test("CA-07/R-2 an uncertain answer blocks accept and draw until the mission is refreshed")
    func uncertainBlocksRetry() async {
        let missions = MissionRepositorySpy()
        missions.setAcceptResults([.failure(RewardAcceptanceError.uncertain)])
        let viewModel = makeViewModel(missions: missions)
        await drawn(viewModel)

        await viewModel.accept()

        #expect(viewModel.phase == .uncertain)
        #expect(!viewModel.canAccept)
        #expect(!viewModel.canDraw)
        #expect(viewModel.showsRefreshMission)
        #expect(viewModel.selectedItem == Self.pizza)
        #expect(viewModel.confirmedReward == nil)
    }

    @Test("CA-07 refreshing finds my accepted item and confirms it")
    func reconcileAcceptedByMe() async {
        let missions = MissionRepositorySpy()
        missions.setAcceptResults([.failure(RewardAcceptanceError.uncertain)])
        let viewModel = makeViewModel(missions: missions)
        await drawn(viewModel)
        await viewModel.accept()
        missions.setMissionResult(.success(makeMissionDetail(
            status: .completed,
            isRedemptionAvailable: false,
            acceptedReward: AcceptedMissionReward(rewardItemID: Self.pizza.id, title: "Noite de pizza")
        )))

        await viewModel.refreshMission()

        #expect(viewModel.confirmedReward?.rewardItemID == Self.pizza.id)
        #expect(missions.acceptCalls.count == 1)
    }

    @Test("CA-07 refreshing finds another accepted item: already-chosen alert")
    func reconcileAcceptedByOther() async {
        let missions = MissionRepositorySpy()
        missions.setAcceptResults([.failure(RewardAcceptanceError.uncertain)])
        let viewModel = makeViewModel(missions: missions)
        await drawn(viewModel)
        await viewModel.accept()
        missions.setMissionResult(.success(makeMissionDetail(
            status: .completed,
            isRedemptionAvailable: false,
            acceptedReward: AcceptedMissionReward(rewardItemID: Self.movie.id, title: "Escolher o filme da noite")
        )))

        await viewModel.refreshMission()

        #expect(viewModel.alert == .alreadyAccepted)
        #expect(viewModel.confirmedReward == nil)
    }

    @Test("CA-07 refreshing finds the mission still redeemable: accept is allowed again")
    func reconcileStillAvailable() async {
        let missions = MissionRepositorySpy()
        missions.setAcceptResults([.failure(RewardAcceptanceError.rejected)])
        let viewModel = makeViewModel(missions: missions)
        await drawn(viewModel)
        await viewModel.accept()
        #expect(viewModel.phase == .error)
        #expect(!viewModel.canAccept)
        missions.setMissionResult(.success(makeMissionDetail(status: .completed, isRedemptionAvailable: true)))

        await viewModel.refreshMission()

        #expect(viewModel.phase == .result)
        #expect(viewModel.canAccept)
    }

    @Test("CA-07 refreshing finds the mission reopened: unavailable alert")
    func reconcileUnavailable() async {
        let missions = MissionRepositorySpy()
        missions.setAcceptResults([.failure(RewardAcceptanceError.uncertain)])
        let viewModel = makeViewModel(missions: missions)
        await drawn(viewModel)
        await viewModel.accept()
        missions.setMissionResult(.success(makeMissionDetail(status: .inProgress, isRedemptionAvailable: false)))

        await viewModel.refreshMission()

        #expect(viewModel.alert == .unavailable)
    }

    @Test("CA-07 a failed refresh keeps the uncertain state and its action")
    func failedRefreshKeepsUncertain() async {
        let missions = MissionRepositorySpy()
        missions.setAcceptResults([.failure(RewardAcceptanceError.uncertain)])
        let viewModel = makeViewModel(missions: missions)
        await drawn(viewModel)
        await viewModel.accept()
        missions.setMissionResult(.failure(MissionError.network))

        await viewModel.refreshMission()

        #expect(viewModel.phase == .uncertain)
        #expect(viewModel.confirmedReward == nil)
    }

    @Test("UX-017 §8 Reduce Motion lands the result without extra turns")
    func reduceMotionHasNoSpin() async {
        let viewModel = makeViewModel(draws: [0])
        await viewModel.load()

        await viewModel.draw(reduceMotion: true)

        #expect(viewModel.rotation < 360)
        #expect(viewModel.phase == .result)
        #expect(viewModel.resultRevision == 1)
    }
}

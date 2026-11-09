import Foundation
import Observation

/// TEL-024 — Roleta da missão (SPEC-017 Fase 2, UX-017 §5.2/§6). Draws are local and never saved
/// (CA-06); the acceptance is announced only after a confirmed `200`, and any uncertain or failed
/// answer is reconciled through the canonical mission before a new attempt (CA-07, R-1/R-2).
@MainActor
@Observable
final class RewardWheelViewModel {
    enum CatalogState: Equatable {
        case loading
        case failed
        case loaded
    }

    enum Phase: Equatable {
        case idle
        case spinning
        case result
        case submitting
        case reconciling
        /// Lost response, network failure or `5xx`: never claims the accept (UX-017 `Uncertain`).
        case uncertain
        /// Definitive refusal: the local result stays, the mission must be refreshed first (UX-017 `Error`).
        case error
    }

    enum Alert: Equatable {
        case alreadyAccepted
        case unavailable
    }

    let missionID: UUID
    let missionTitle: String
    private let accessToken: String
    private let getEligibleRewards: GetEligibleRewardsUseCase
    private let drawReward: DrawRewardUseCase
    private let acceptReward: AcceptRewardUseCase
    private let reconcile: ReconcileRewardAcceptanceUseCase
    private let spinDuration: Duration

    private(set) var catalogState: CatalogState = .loading
    private(set) var items: [RewardItem] = []
    private(set) var phase: Phase = .idle
    private(set) var selectedIndex: Int?
    /// Absolute wheel rotation in degrees; the View animates towards it.
    private(set) var rotation: Double = 0
    var alert: Alert?
    /// Set once the server confirmed the acceptance; the host pops back to TEL-021.
    private(set) var confirmedReward: AcceptedMissionReward?
    /// Bumped whenever a draw lands, so the View moves VoiceOver focus to the result.
    private(set) var resultRevision = 0

    init(
        missionID: UUID,
        missionTitle: String,
        missionRepository: any MissionRepository,
        rewardRepository: any RewardRepository,
        accessToken: String,
        drawing: any RewardDrawing = SystemRewardDrawing(),
        spinDuration: Duration = .milliseconds(2600)
    ) {
        self.missionID = missionID
        self.missionTitle = missionTitle
        self.accessToken = accessToken
        self.getEligibleRewards = GetEligibleRewardsUseCase(repository: rewardRepository)
        self.drawReward = DrawRewardUseCase(drawing: drawing)
        self.acceptReward = AcceptRewardUseCase(repository: missionRepository)
        self.reconcile = ReconcileRewardAcceptanceUseCase(repository: missionRepository)
        self.spinDuration = spinDuration
    }

    var selectedItem: RewardItem? {
        guard let selectedIndex, items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    var canDraw: Bool {
        catalogState == .loaded && !items.isEmpty && (phase == .idle || phase == .result)
    }

    /// R-2: blocked while submitting and until an uncertain/failed answer is reconciled.
    var canAccept: Bool {
        phase == .result && selectedItem != nil
    }

    var canExit: Bool {
        phase != .submitting && phase != .reconciling
    }

    var showsRefreshMission: Bool {
        phase == .uncertain || phase == .error || phase == .reconciling
    }

    var spinAnimationDuration: Double {
        let components = spinDuration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    func load() async {
        guard catalogState != .loaded else { return }
        catalogState = .loading
        do {
            let eligible = try await getEligibleRewards.execute(accessToken: accessToken)
            guard !Task.isCancelled else { return }
            items = eligible
            catalogState = eligible.isEmpty ? .failed : .loaded
        } catch {
            guard !Task.isCancelled else { return }
            catalogState = .failed
        }
    }

    /// RN52: as many draws as wanted before accepting; nothing leaves the device (CA-06).
    func draw(reduceMotion: Bool) async {
        guard canDraw, let index = drawReward.execute(from: items) else { return }
        selectedIndex = index
        rotation = RewardWheelGeometry.rotation(
            landingOn: index,
            count: items.count,
            from: rotation,
            fullTurns: reduceMotion ? 0 : 4
        )
        if !reduceMotion {
            phase = .spinning
            try? await Task.sleep(for: spinDuration)
        }
        phase = .result
        resultRevision += 1
    }

    func accept() async {
        guard canAccept, let item = selectedItem else { return }
        phase = .submitting
        do {
            let accepted = try await acceptReward.execute(
                missionID: missionID,
                rewardItemID: item.id,
                accessToken: accessToken
            )
            confirmedReward = accepted
        } catch let error as RewardAcceptanceError {
            switch error {
            case .alreadyAccepted:
                phase = .result
                alert = .alreadyAccepted
            case .unavailable:
                phase = .result
                alert = .unavailable
            case .uncertain:
                phase = .uncertain
            case .rejected:
                phase = .error
            }
        } catch {
            phase = .uncertain
        }
    }

    /// "Atualizar missão": the canonical detail decides what happens next (SPEC-017 §5.2).
    func refreshMission() async {
        guard phase == .uncertain || phase == .error else { return }
        let previous = phase
        phase = .reconciling
        do {
            let outcome = try await reconcile.execute(
                missionID: missionID,
                chosenItemID: selectedItem?.id,
                accessToken: accessToken
            )
            switch outcome {
            case let .acceptedByMe(accepted):
                confirmedReward = accepted
            case .acceptedByOther:
                phase = .result
                alert = .alreadyAccepted
            case .stillAvailable:
                phase = .result
            case .unavailable:
                phase = .result
                alert = .unavailable
            }
        } catch {
            // Still unknown: keep the same state and its "Atualizar missão" action.
            phase = previous
        }
    }
}

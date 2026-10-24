#if DEBUG
import Foundation
import UIKit

/// Deterministic, backend-free launch scenarios selected with the `UI_TEST_SCENARIO` environment variable.
enum UITestScenario: String {
    case onboarding = "onboarding"
    case onboardingUncertain = "onboarding-uncertain"
    case onboardingPhotoFailure = "onboarding-photo-failure"
    case onboardingInvite = "onboarding-invite"
    case fullFlow = "full-flow"
    case inviteEntry = "invite-entry"
    case inviteSwitch = "invite-switch"
    case inviteKids = "invite-kids"
    case inviteAdult = "invite-adult"
    case inviteInvalidPassword = "invite-invalid-password"
    case inviteRecovery = "invite-recovery"
    case inviteRecoveryUnavailable = "invite-recovery-unavailable"
    case profileAdult = "profile-adult"
    case profileKids = "profile-kids"
    case profileSaveNetworkError = "profile-save-network-error"
    case taskManagement = "task-management"
    case familySettings = "family-settings"
    case dailyTasks = "daily-tasks"
    case dailyTasksKids = "daily-tasks-kids"
    case dailyTasksFailure = "daily-tasks-failure"

    static var current: UITestScenario? {
        ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"].flatMap(UITestScenario.init(rawValue:))
    }

    @MainActor
    func makeContainer() -> AppContainer {
        AppContainer(
            accessRepository: UITestAccessRepository(),
            inviteJoinRepository: UITestInviteJoinRepository(scenario: self),
            inviteJoinAttemptStore: UITestInviteJoinAttemptStore(),
            inviteLinkParser: InviteLinkParser(baseURL: URL(string: "https://example.invalid")!),
            familyRepository: UITestFamilyRepository(scenario: self),
            taskRepository: UITestTaskRepository(scenario: self),
            profileRepository: UITestProfileRepository(scenario: self),
            credentialStore: UITestCredentialStore(),
            installationProofStore: UITestInstallationProof(),
            appleAuthenticator: UITestAppleAuthenticator()
        )
    }

    @MainActor
    func bootstrap(_ sessionStore: AppSessionStore) {
        if [.profileAdult, .profileKids, .profileSaveNetworkError].contains(self) {
            let role: MemberRole = self == .profileKids ? .kid : .administrator
            sessionStore.apply(.session(Self.inviteSession(role: role)))
            return
        }
        if self == .taskManagement || self == .familySettings || self == .dailyTasks || self == .dailyTasksFailure {
            sessionStore.apply(.session(Self.inviteSession(role: .administrator)))
            return
        }
        if self == .dailyTasksKids {
            // Must match `UITestTaskFixtures.kidMemberID`, the assignee on the Kids-owned fixture
            // tasks, so SPEC-011's `canReopen` check (assignee == current member) finds them.
            sessionStore.apply(.session(AuthenticatedSession(
                sessionID: UUID(),
                profile: ActiveFamilySession(
                    memberID: UITestTaskFixtures.kidMemberID,
                    familyID: UUID(),
                    role: .kid,
                    isFamilyCreator: false
                ),
                credentials: SessionCredentials(
                    token: SessionToken(accessToken: "ui-test-access", expiresAt: .distantFuture),
                    refreshToken: "new-refresh"
                )
            )))
            return
        }
        if self == .inviteSwitch {
            sessionStore.apply(.session(Self.inviteSession(role: .administrator, refreshToken: "old-refresh")))
            return
        }
        if [.inviteEntry, .inviteKids, .inviteAdult, .inviteInvalidPassword, .inviteRecovery, .inviteRecoveryUnavailable].contains(self) {
            sessionStore.discardOnboarding()
            return
        }
        if self == .fullFlow {
            sessionStore.discardOnboarding()
            return
        }
        if self == .onboardingPhotoFailure {
            // Seeds a restored draft so the photo path runs without driving the system photo picker.
            sessionStore.returnToEntry(preserving: OnboardingDraft(name: "Maria Silva", photo: Self.samplePhoto))
        } else if self == .onboardingInvite {
            let member1 = DraftMember(id: UUID(), name: "Marina Silva", role: .administrator)
            let member2 = DraftMember(id: UUID(), name: "Lucas Silva", role: .kid)
            sessionStore.returnToEntry(preserving: OnboardingDraft(name: "João Silva", familyName: "Família Silva", members: [member1, member2]))
            sessionStore.apply(.creationGrant(CreationGrant(value: "ui-test-grant", expiresAt: .distantFuture)))
            sessionStore.establishOnboardingSession(AuthenticatedSession(
                sessionID: UUID(),
                profile: ActiveFamilySession(
                    memberID: UUID(),
                    familyID: UUID(),
                    role: .administrator,
                    isFamilyCreator: true
                ),
                credentials: SessionCredentials(
                    token: SessionToken(accessToken: "ui-test-access", expiresAt: .distantFuture),
                    refreshToken: "ui-test-refresh"
                )
            ))
            return
        }
        sessionStore.apply(.creationGrant(CreationGrant(value: "ui-test-grant", expiresAt: .distantFuture)))
    }

    private static var samplePhoto: Data {
        UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }

    nonisolated static func inviteSession(role: MemberRole, refreshToken: String = "new-refresh") -> AuthenticatedSession {
        AuthenticatedSession(
            sessionID: UUID(),
            profile: ActiveFamilySession(
                memberID: UUID(),
                familyID: UUID(),
                role: role,
                isFamilyCreator: false
            ),
            credentials: SessionCredentials(
                token: SessionToken(accessToken: "ui-test-access", expiresAt: .distantFuture),
                refreshToken: refreshToken
            )
        )
    }
}

private struct UITestInviteJoinRepository: InviteJoinRepository {
    let scenario: UITestScenario

    func inspect(token: String) async throws {}

    func join(
        token: String,
        password: String,
        attempt: InviteJoinAttempt,
        switchConfirmed: Bool,
        previousAccessToken: String?
    ) async throws -> AuthenticatedSession {
        switch scenario {
        case .inviteInvalidPassword:
            throw InviteJoinError.invalidPassword
        case .inviteRecovery, .inviteRecoveryUnavailable:
            throw InviteJoinError.resultUncertain
        case .inviteAdult:
            return UITestScenario.inviteSession(role: .member)
        case .inviteKids:
            return UITestScenario.inviteSession(role: .kid)
        default:
            throw InviteJoinError.inviteUnavailable
        }
    }

    func recover(attempt: InviteJoinAttempt) async throws -> AuthenticatedSession {
        if scenario == .inviteRecovery {
            return UITestScenario.inviteSession(role: .kid)
        }
        throw InviteJoinError.recoveryUnavailable
    }
}

private final class UITestInviteJoinAttemptStore: InviteJoinAttemptStoring, @unchecked Sendable {
    private var value: InviteJoinAttempt?
    func pendingAttempt() throws -> InviteJoinAttempt? { value }
    func save(_ attempt: InviteJoinAttempt) throws { value = attempt }
    func clear() throws { value = nil }
}

private struct UITestAccessRepository: AccessRepository {
    func signIn(proof: AppleAuthorizationProof, installationProof: String) async throws -> AppleSignInOutcome {
        .creationGrant(CreationGrant(value: "ui-test-grant", expiresAt: .distantFuture))
    }

    func currentSession(accessToken: String) async throws -> ActiveFamilySession {
        throw AccessError.unavailable
    }

    func refresh(refreshToken: String, installationProof: String) async throws -> SessionToken {
        SessionToken(accessToken: "ui-test-refreshed-access", expiresAt: .distantFuture)
    }

    func revokeSession(accessToken: String) async throws {}
}

private actor UITestFamilyRepository: FamilyRepository {
    private let scenario: UITestScenario
    private var photoUploadAttempts = 0

    init(scenario: UITestScenario) {
        self.scenario = scenario
    }

    func createFamily(_ command: CreateFamilyCommand, installationProof: String) async throws -> CreatedFamily {
        if scenario == .onboardingUncertain {
            throw FamilyError.uncertainOutcome
        }
        let familyID = UUID()
        let memberID = UUID()
        return CreatedFamily(
            familyID: familyID,
            name: command.familyName,
            timeZoneID: command.timeZoneID,
            session: AuthenticatedSession(
                sessionID: UUID(),
                profile: ActiveFamilySession(
                    memberID: memberID,
                    familyID: familyID,
                    role: .administrator,
                    isFamilyCreator: true
                ),
                credentials: SessionCredentials(
                    token: SessionToken(accessToken: "ui-test-access", expiresAt: .distantFuture),
                    refreshToken: "ui-test-refresh"
                )
            )
        )
    }

    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String {
        photoUploadAttempts += 1
        if scenario == .onboardingPhotoFailure, photoUploadAttempts == 1 {
            throw FamilyError.unavailable
        }
        return "ui-test-media"
    }

    func setProfilePhoto(mediaID: String, accessToken: String) async throws {}

    func createMember(name: String, role: MemberRole, accessToken: String) async throws -> CreatedMember {
        CreatedMember(id: UUID(), name: name, role: role)
    }

    func issueInvite(memberID: UUID, accessToken: String) async throws -> MemberInvite {
        MemberInvite(inviteID: UUID(), link: "https://example.invalid/invite/test", password: "ABC-123")
    }

    func listMembers(accessToken: String, cursor: String?) async throws -> FamilyMemberPage {
        FamilyMemberPage(
            items: [
                FamilyMember(id: UITestTaskFixtures.memberID, name: "Maria Silva", role: .administrator, isFamilyCreator: true),
                FamilyMember(id: UITestTaskFixtures.kidMemberID, name: "Rafa Silva", role: .kid, isFamilyCreator: false),
            ],
            nextCursor: nil
        )
    }

    func getFamilySettings(accessToken: String) async throws -> FamilySettings {
        FamilySettings(
            timeZoneID: "America/Sao_Paulo",
            scheduledTimeZoneChange: nil,
            limits: CycleLimits(
                startsAt: "2026-10-19T03:00:00.000Z",
                endsAt: "2026-10-26T03:00:00.000Z",
                timeZoneID: "America/Sao_Paulo",
                isTransition: false
            )
        )
    }

    func previewFamilyTimeZoneChange(
        timeZoneID: String,
        application: TimeZoneApplication,
        accessToken: String
    ) async throws -> TimeZoneChangePreview {
        TimeZoneChangePreview(
            proposedTimeZoneID: timeZoneID,
            application: application,
            effectiveAt: "2026-10-26T03:00:00.000Z",
            effectiveLimits: CycleLimits(
                startsAt: "2026-10-19T03:00:00.000Z",
                endsAt: "2026-10-26T03:00:00.000Z",
                timeZoneID: timeZoneID,
                isTransition: application == .immediate
            ),
            isTransition: application == .immediate
        )
    }

    func changeFamilyTimeZone(
        timeZoneID: String,
        application: TimeZoneApplication,
        accessToken: String
    ) async throws -> FamilySettings {
        FamilySettings(
            timeZoneID: application == .immediate ? timeZoneID : "America/Sao_Paulo",
            scheduledTimeZoneChange: application == .nextCycle ? ScheduledTimeZoneChange(
                timeZoneID: timeZoneID,
                effectiveAt: "2026-10-26T03:00:00.000Z"
            ) : nil,
            limits: CycleLimits(
                startsAt: "2026-10-19T03:00:00.000Z",
                endsAt: "2026-10-26T03:00:00.000Z",
                timeZoneID: application == .immediate ? timeZoneID : "America/Sao_Paulo",
                isTransition: application == .immediate
            )
        )
    }
}

/// Stable ids shared between `UITestFamilyRepository.listMembers` and `UITestTaskRepository`
/// fixtures, so a seeded task's assignees resolve to names in the picker.
private enum UITestTaskFixtures {
    static let memberID = UUID(uuidString: "00000000-0000-0000-0000-0000000000a1")!
    static let kidMemberID = UUID(uuidString: "00000000-0000-0000-0000-0000000000a2")!
    static let pendingTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!
    static let completedTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000000b2")!
    static let awaitingConfirmationTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000000b3")!
    static let missionProtectedTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000000b4")!
    static let todayPendingTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000000c1")!
    static let todayAwaitingConfirmationTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000000c2")!
    static let todayCompletedTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000000c3")!
    /// SPEC-011: completed, no mission impact — reopens directly (CA-01).
    static let missionFreeReopenTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000000d1")!
    /// SPEC-011: completed, requires confirmation on the first attempt (CA-02/03).
    static let missionReopenTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000000d2")!
    /// SPEC-011: completed, assigned to Kids — Kids can reopen it (CA-04).
    static let kidsOwnCompletedTaskID = UUID(uuidString: "00000000-0000-0000-0000-0000000000d3")!
}

/// Deterministic, backend-free double for the `.taskManagement`/`.dailyTasks*` UI scenarios.
/// Pre-seeds one task per state so `UI_TEST_TASK_ROUTE=detail:<id>` can reach each without a real
/// backend, plus a few tasks dated "today" (computed at launch) for TEL-010/TEL-040.
private actor UITestTaskRepository: TaskRepository {
    private let scenario: UITestScenario
    private var tasks: [UUID: FamilyTask]

    init(scenario: UITestScenario) {
        self.scenario = scenario
        let today = Self.wireString(from: Date())
        // Within the carousel's -7..+6 day window (RN49) so UI tests can reach it by date, unlike
        // the other fixtures below, which use fixed dates reached only via `UI_TEST_TASK_ROUTE`.
        let threeDaysAgo = Self.wireString(
            from: Calendar(identifier: .gregorian).date(byAdding: .day, value: -3, to: Date())!
        )
        // Yesterday is left task-free on purpose: it's the fixed, always-in-range empty day the
        // UI tests navigate to via the carousel (no month-rollover risk near month boundaries).
        tasks = [
            UITestTaskFixtures.pendingTaskID: FamilyTask(
                id: UITestTaskFixtures.pendingTaskID,
                title: "Arrumar os brinquedos",
                weight: .medium,
                scheduledDate: "2026-10-10",
                assigneeIDs: [UITestTaskFixtures.memberID],
                note: nil,
                status: .pending,
                routineID: nil,
                createdAt: Date(timeIntervalSince1970: 1_760_000_000)
            ),
            UITestTaskFixtures.completedTaskID: FamilyTask(
                id: UITestTaskFixtures.completedTaskID,
                title: "Lavar a louça",
                weight: .low,
                scheduledDate: "2026-10-08",
                assigneeIDs: [],
                note: nil,
                status: .completed,
                routineID: nil,
                createdAt: Date(timeIntervalSince1970: 1_760_000_000)
            ),
            UITestTaskFixtures.awaitingConfirmationTaskID: FamilyTask(
                id: UITestTaskFixtures.awaitingConfirmationTaskID,
                title: "Guardar a roupa",
                weight: .high,
                scheduledDate: "2026-10-09",
                assigneeIDs: [UITestTaskFixtures.kidMemberID],
                note: "Separar por cor",
                status: .awaitingConfirmation,
                routineID: nil,
                createdAt: Date(timeIntervalSince1970: 1_760_000_000)
            ),
            UITestTaskFixtures.missionProtectedTaskID: FamilyTask(
                id: UITestTaskFixtures.missionProtectedTaskID,
                title: "Organizar a sala",
                weight: .medium,
                scheduledDate: "2026-10-07",
                assigneeIDs: [],
                note: nil,
                status: .completed,
                routineID: nil,
                createdAt: Date(timeIntervalSince1970: 1_760_000_000)
            ),
            UITestTaskFixtures.todayPendingTaskID: FamilyTask(
                id: UITestTaskFixtures.todayPendingTaskID,
                title: "Passear com o cachorro",
                weight: .low,
                scheduledDate: today,
                assigneeIDs: [UITestTaskFixtures.memberID],
                note: nil,
                status: .pending,
                routineID: nil,
                createdAt: Date(timeIntervalSince1970: 1_760_000_100)
            ),
            UITestTaskFixtures.todayAwaitingConfirmationTaskID: FamilyTask(
                id: UITestTaskFixtures.todayAwaitingConfirmationTaskID,
                title: "Guardar as roupas limpas",
                weight: .medium,
                scheduledDate: today,
                assigneeIDs: [UITestTaskFixtures.kidMemberID, UITestTaskFixtures.memberID],
                note: nil,
                status: .awaitingConfirmation,
                routineID: nil,
                createdAt: Date(timeIntervalSince1970: 1_760_000_200)
            ),
            UITestTaskFixtures.todayCompletedTaskID: FamilyTask(
                id: UITestTaskFixtures.todayCompletedTaskID,
                title: "Escovar os dentes",
                weight: .low,
                scheduledDate: today,
                assigneeIDs: [],
                note: nil,
                status: .completed,
                routineID: nil,
                createdAt: Date(timeIntervalSince1970: 1_760_000_300)
            ),
            UITestTaskFixtures.missionFreeReopenTaskID: FamilyTask(
                id: UITestTaskFixtures.missionFreeReopenTaskID,
                title: "Fazer a cama",
                weight: .low,
                scheduledDate: "2026-10-06",
                assigneeIDs: [UITestTaskFixtures.memberID],
                note: nil,
                status: .completed,
                routineID: nil,
                createdAt: Date(timeIntervalSince1970: 1_760_000_000)
            ),
            UITestTaskFixtures.missionReopenTaskID: FamilyTask(
                id: UITestTaskFixtures.missionReopenTaskID,
                title: "Alimentar o gato",
                weight: .medium,
                scheduledDate: "2026-10-05",
                assigneeIDs: [UITestTaskFixtures.memberID],
                note: nil,
                status: .completed,
                routineID: nil,
                createdAt: Date(timeIntervalSince1970: 1_760_000_000)
            ),
            UITestTaskFixtures.kidsOwnCompletedTaskID: FamilyTask(
                id: UITestTaskFixtures.kidsOwnCompletedTaskID,
                title: "Regar as plantas",
                weight: .low,
                scheduledDate: threeDaysAgo,
                assigneeIDs: [UITestTaskFixtures.kidMemberID],
                note: nil,
                status: .completed,
                routineID: nil,
                createdAt: Date(timeIntervalSince1970: 1_760_000_400)
            ),
        ]
    }

    private var role: MemberRole {
        scenario == .dailyTasksKids ? .kid : .administrator
    }

    private static func displayStatus(for status: TaskStatus, role: MemberRole) -> TaskStatus {
        guard status == .awaitingConfirmation else { return status }
        return role == .kid ? .awaitingConfirmation : .pending
    }

    private static func wireString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func createTask(_ command: CreateTaskCommand, accessToken: String) async throws -> FamilyTask {
        let task = FamilyTask(
            id: UUID(),
            title: command.title,
            weight: command.weight,
            scheduledDate: command.scheduledDate,
            assigneeIDs: command.assigneeIDs,
            note: command.note,
            status: .pending,
            routineID: nil,
            createdAt: Date()
        )
        tasks[task.id] = task
        return task
    }

    func task(id: UUID, accessToken: String) async throws -> FamilyTask {
        guard let task = tasks[id] else {
            throw TaskError.notFound
        }
        return task
    }

    func updateTask(_ command: UpdateTaskCommand, accessToken: String) async throws -> FamilyTask {
        guard let current = tasks[command.taskID] else {
            throw TaskError.notFound
        }
        if command.taskID == UITestTaskFixtures.missionProtectedTaskID {
            throw TaskError.missionCompletedProtected
        }
        let status: TaskStatus = current.status == .awaitingConfirmation
            && command.signalResolution == .resetToPending ? .pending : current.status
        let updated = FamilyTask(
            id: current.id,
            title: command.title,
            weight: command.weight,
            scheduledDate: command.scheduledDate,
            assigneeIDs: command.assigneeIDs,
            note: command.note,
            status: status,
            routineID: current.routineID,
            createdAt: current.createdAt
        )
        tasks[current.id] = updated
        return updated
    }

    func deleteTask(id: UUID, accessToken: String) async throws -> UUID {
        guard let task = tasks[id] else {
            throw TaskError.notFound
        }
        if task.status == .completed {
            throw TaskError.alreadyCompleted
        }
        tasks.removeValue(forKey: id)
        return id
    }

    /// Well before any fixture date and any plausible "today" during a test run (RN49's lower bound).
    private static let familyCreatedAt = "2020-01-01"

    func dailyTasks(referenceDate: String, cursor: String?, accessToken: String) async throws -> OwnTaskPage {
        if scenario == .dailyTasksFailure {
            throw TaskError.unavailable
        }
        let items = tasks.values
            .filter { $0.scheduledDate == referenceDate }
            .sorted { $0.createdAt < $1.createdAt }
            .map { OwnTaskListItem(task: $0, displayStatus: Self.displayStatus(for: $0.status, role: role)) }
        return OwnTaskPage(items: items, nextCursor: nil, familyCreatedAt: Self.familyCreatedAt)
    }

    func reopenTask(id: UUID, confirm: Bool, accessToken: String) async throws -> FamilyTask {
        guard let task = tasks[id] else {
            throw TaskError.notFound
        }
        guard task.status == .completed else {
            throw TaskError.taskNotCompleted
        }
        if id == UITestTaskFixtures.missionReopenTaskID, !confirm {
            throw TaskError.missionReopenRequiresConfirmation(
                missionsAffected: [AffectedMission(id: UUID(), title: "Arrumar o quintal")],
                hasAcceptedReward: false
            )
        }
        let reopened = FamilyTask(
            id: task.id,
            title: task.title,
            weight: task.weight,
            scheduledDate: task.scheduledDate,
            assigneeIDs: task.assigneeIDs,
            note: task.note,
            status: .pending,
            routineID: task.routineID,
            createdAt: task.createdAt
        )
        tasks[id] = reopened
        return reopened
    }

    func dailyProgress(referenceDate: String, accessToken: String) async throws -> DailyProgress {
        if scenario == .dailyTasksFailure {
            throw TaskError.unavailable
        }
        let dayTasks = tasks.values.filter { $0.scheduledDate == referenceDate }
        let completed = dayTasks.filter { $0.status == .completed }.count
        let total = dayTasks.count
        return DailyProgress(
            total: total,
            completed: completed,
            percentage: total == 0 ? nil : Double(completed) / Double(total) * 100,
            familyCreatedAt: Self.familyCreatedAt
        )
    }
}

/// Deterministic profile data so UI scenarios reach TEL-030/MOD-009/TEL-054 without a network.
private actor UITestProfileRepository: ProfileRepository {
    private let scenario: UITestScenario
    private var profile: OwnProfile
    private var awards: [BadgeAward]
    private let nextTier: NextBadgeTier?

    init(scenario: UITestScenario) {
        self.scenario = scenario
        let awardedAt = Date(timeIntervalSince1970: 1_790_000_000)
        if scenario == .profileKids {
            profile = Self.profile(name: "Léo", total: 7)
            awards = [BadgeAward(awardID: Self.bronzeID, tier: .bronze, requiredMissionCount: 5, awardedAt: awardedAt)]
            nextTier = NextBadgeTier(code: .silver, requiredMissionCount: 10, remaining: 3)
        } else {
            profile = Self.profile(name: "Maria Silva", total: 12)
            awards = [
                BadgeAward(awardID: Self.bronzeID, tier: .bronze, requiredMissionCount: 5, awardedAt: awardedAt),
                BadgeAward(awardID: Self.silverID, tier: .silver, requiredMissionCount: 10, awardedAt: awardedAt),
            ]
            nextTier = NextBadgeTier(code: .gold, requiredMissionCount: 25, remaining: 13)
        }
    }

    private static let bronzeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!
    private static let silverID = UUID(uuidString: "00000000-0000-0000-0000-0000000000b2")!

    private static func profile(name: String, total: Int) -> OwnProfile {
        OwnProfile(
            memberID: UUID(),
            name: name,
            familyName: "Família Silva",
            nickname: nil,
            photoMediaID: nil,
            totalParticipations: total,
            nextTier: nil
        )
    }

    func getOwnProfile(accessToken: String) async throws -> OwnProfile { profile }

    func updateOwnProfile(_ command: UpdateOwnProfileCommand, accessToken: String) async throws -> OwnProfile {
        if scenario == .profileSaveNetworkError {
            throw ProfileError.network
        }
        let nickname: String? = switch command.nickname {
        case .unchanged: profile.nickname
        case let .set(value): value
        case .clear: nil
        }
        profile = OwnProfile(
            memberID: profile.memberID,
            name: command.name ?? profile.name,
            familyName: profile.familyName,
            nickname: nickname,
            photoMediaID: profile.photoMediaID,
            totalParticipations: profile.totalParticipations,
            nextTier: nextTier
        )
        return profile
    }

    func getOwnBadges(accessToken: String) async throws -> BadgesOverview {
        BadgesOverview(totalParticipations: profile.totalParticipations, nextTier: nextTier, awards: awards)
    }

    func getBadgeDetail(awardID: UUID, accessToken: String) async throws -> BadgeDetail {
        guard let award = awards.first(where: { $0.awardID == awardID }) else {
            throw ProfileError.notFound
        }
        return BadgeDetail(
            awardID: award.awardID,
            tier: award.tier,
            awardedAt: award.awardedAt,
            contributingMissions: [
                ContributingMission(missionID: UUID(), title: "Organizar a sala", completedAt: Date(timeIntervalSince1970: 1_789_000_000)),
                ContributingMission(missionID: UUID(), title: "Arrumar a cozinha", completedAt: Date(timeIntervalSince1970: 1_789_500_000)),
            ]
        )
    }

    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String { "ui-test-media" }

    func getMediaContent(mediaID: String, accessToken: String) async throws -> Data { Data() }
}

private final class UITestCredentialStore: SessionCredentialStoring, @unchecked Sendable {
    private var token: String?

    func refreshToken() throws -> String? { token }
    func save(refreshToken: String) throws { token = refreshToken }
    func clear() throws { token = nil }
}

private struct UITestInstallationProof: InstallationProofProviding {
    func installationProof() throws -> String { "ui-test-installation" }
}

@MainActor
private final class UITestAppleAuthenticator: AppleAuthenticating {
    func authorize() async throws -> AppleAuthorizationProof {
        AppleAuthorizationProof(
            identityToken: "ui-test-identity-token",
            authorizationCode: "ui-test-auth-code",
            rawNonce: "ui-test-nonce"
        )
    }
}
#endif

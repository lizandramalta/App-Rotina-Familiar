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
    case familyOverview = "family-overview"
    case familyOverviewMember = "family-overview-member"
    case memberInvite = "member-invite"
    case memberInviteUncertain = "member-invite-uncertain"
    case kidsReviewQueue = "kids-review-queue"
    case kidsReviewQueueEmpty = "kids-review-queue-empty"
    case kidsReviewQueueFailure = "kids-review-queue-failure"
    case taskCompletionMember = "task-completion-member"
    case taskCompletionConflict = "task-completion-conflict"
    case taskOptimisticDelayed = "task-optimistic-delayed"
    case taskOptimisticFailure = "task-optimistic-failure"
    case routineCreation = "routine-creation"
    case missionManagement = "mission-management"
    case missionManagementMember = "mission-management-member"
    case missionManagementKids = "mission-management-kids"

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
            routineRepository: UITestRoutineRepository(),
            profileRepository: UITestProfileRepository(scenario: self),
            missionRepository: UITestMissionRepository(scenario: self),
            kidsSignalRepository: UITestKidsSignalRepository(scenario: self),
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
        if self == .taskCompletionMember {
            sessionStore.apply(.session(Self.inviteSession(role: .member)))
            return
        }
        if self == .dailyTasks || self == .dailyTasksFailure {
            sessionStore.apply(.session(Self.inviteSession(role: .administrator, memberID: UITestTaskFixtures.memberID)))
            return
        }
        if self == .taskManagement || self == .familySettings
            || self == .taskCompletionConflict || self == .taskOptimisticDelayed || self == .taskOptimisticFailure
            || self == .routineCreation || self == .missionManagement {
            sessionStore.apply(.session(Self.inviteSession(role: .administrator)))
            return
        }
        if self == .missionManagementMember {
            sessionStore.apply(.session(Self.inviteSession(role: .member)))
            return
        }
        if self == .missionManagementKids {
            // Must match `UITestTaskFixtures.kidMemberID`, the assignee on the Kids-owned fixture
            // task linked to the mission fixture, so CA-19's own-task tap-through can be tested.
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
        if [.familyOverview, .memberInvite, .memberInviteUncertain, .kidsReviewQueue, .kidsReviewQueueEmpty, .kidsReviewQueueFailure].contains(self) {
            sessionStore.apply(.session(Self.inviteSession(role: .administrator)))
            return
        }
        if self == .familyOverviewMember {
            sessionStore.apply(.session(Self.inviteSession(role: .member)))
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

    nonisolated static func inviteSession(
        role: MemberRole,
        refreshToken: String = "new-refresh",
        memberID: UUID = UUID()
    ) -> AuthenticatedSession {
        AuthenticatedSession(
            sessionID: UUID(),
            profile: ActiveFamilySession(
                memberID: memberID,
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

/// SPEC-008 Fase 1 UI fixture: a saved routine starts pending and completes on explicit consultation.
private actor UITestRoutineRepository: RoutineRepository {
    private var saved: Routine?

    func familyTimeZoneID(accessToken: String) async throws -> String { "America/Sao_Paulo" }

    func createRoutine(_ command: CreateRoutineCommand, accessToken: String) async throws -> Routine {
        let routine = Routine(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000a8")!,
            title: command.title,
            weight: command.weight,
            assigneeIDs: command.assigneeIDs,
            note: command.note,
            startDate: command.startDate,
            frequency: command.frequency,
            isActive: true,
            materializationState: .pending
        )
        saved = routine
        return routine
    }

    func routine(id: UUID, accessToken: String) async throws -> Routine {
        guard let saved, saved.id == id else { throw RoutineError.notFound }
        return Routine(
            id: saved.id,
            title: saved.title,
            weight: saved.weight,
            assigneeIDs: saved.assigneeIDs,
            note: saved.note,
            startDate: saved.startDate,
            frequency: saved.frequency,
            isActive: true,
            materializationState: .complete
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
    private var familyName = "Família Silva"
    private let familyTimeZoneID = "America/Sao_Paulo"

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
        if scenario == .memberInviteUncertain {
            throw FamilyError.uncertainOutcome
        }
        return MemberInvite(inviteID: UUID(), link: "https://example.invalid/invite/test", password: "ABC-123")
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

    func getMemberDetail(memberID: UUID, accessToken: String) async throws -> FamilyMemberDetail {
        // Rafa is a regular target for invites; every other id keeps the Creator fixture.
        let isKid = memberID == UITestTaskFixtures.kidMemberID
        return FamilyMemberDetail(
            id: memberID,
            name: isKid ? "Rafa Silva" : "Maria Silva",
            role: isKid ? .kid : .administrator,
            isFamilyCreator: !isKid,
            createdAt: "2026-10-01T12:00:00.000Z",
            capabilities: MemberCapabilities(manageMembers: true)
        )
    }

    func updateMemberName(memberID: UUID, name: String, accessToken: String) async throws -> FamilyMember {
        FamilyMember(id: memberID, name: name, role: .member, isFamilyCreator: false)
    }

    func changeMemberRole(memberID: UUID, role: MemberRole, accessToken: String) async throws -> FamilyMember {
        FamilyMember(id: memberID, name: "Rafa Silva", role: role, isFamilyCreator: false)
    }

    func removeMember(memberID: UUID, accessToken: String) async throws {}

    func leaveAdministration(accessToken: String) async throws -> FamilyMember {
        FamilyMember(id: UITestTaskFixtures.memberID, name: "Maria Silva", role: .member, isFamilyCreator: false)
    }

    func getFamily(accessToken: String) async throws -> FamilyProfile {
        FamilyProfile(id: UITestTaskFixtures.familyID, name: familyName, timeZoneID: familyTimeZoneID)
    }

    func getFamilyOverview(range: FamilyDateRange?, accessToken: String) async throws -> FamilyOverview {
        let selectedRange = range ?? FamilyDateRange(startDate: "2026-10-19", endDate: "2026-10-25")
        let progress = FamilyProgress(
            total: 25,
            completed: 17,
            pending: 6,
            awaitingConfirmation: 2,
            percentage: 68
        )
        return FamilyOverview(
            range: selectedRange,
            familyCreatedAt: "2026-10-01",
            progress: progress,
            members: [
                FamilyMemberProgress(
                    memberID: UITestTaskFixtures.memberID,
                    name: "Maria Silva",
                    role: .administrator,
                    progress: progress
                ),
                FamilyMemberProgress(
                    memberID: UITestTaskFixtures.kidMemberID,
                    name: "Rafa Silva",
                    role: .kid,
                    progress: FamilyProgress(
                        total: 8,
                        completed: 5,
                        pending: 2,
                        awaitingConfirmation: 1,
                        percentage: 62.5
                    )
                ),
            ]
        )
    }

    func listFamilyTasks(
        range: FamilyDateRange,
        memberID: UUID?,
        status: FamilyTaskStatusFilter,
        cursor: String?,
        accessToken: String
    ) async throws -> FamilyTaskPage {
        FamilyTaskPage(range: range, items: [], nextCursor: nil)
    }

    func getWeeklyReport(referenceDate: String, accessToken: String) async throws -> WeeklyReportSnapshot {
        WeeklyReportSnapshot(
            period: FamilyDateRange(startDate: referenceDate, endDate: referenceDate),
            timeZoneID: familyTimeZoneID, generatedAt: Date(timeIntervalSince1970: 1_782_400_000),
            isPartial: false, isTransition: false,
            progress: .init(total: 25, completed: 17, percentage: 68),
            totalWeight: 42,
            members: [.init(displayName: "Alex Silva", weight: 12, completedTasks: 5, percentage: 28.6)]
        )
    }

    func updateFamilyName(_ name: String, accessToken: String) async throws -> FamilyProfile {
        familyName = name
        return FamilyProfile(id: UITestTaskFixtures.familyID, name: familyName, timeZoneID: familyTimeZoneID)
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
    static let familyID = UUID(uuidString: "00000000-0000-0000-0000-0000000000f1")!
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
        // Within the carousel's adjacent weeks (RN49) so UI tests can reach it by date, unlike
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
                assigneeIDs: [UITestTaskFixtures.memberID],
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
        if scenario == .dailyTasksKids { return .kid }
        if scenario == .taskCompletionMember { return .member }
        return .administrator
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

    func completeTask(id: UUID, accessToken: String) async throws -> FamilyTask {
        guard let task = tasks[id] else { throw TaskError.notFound }
        guard task.status != .completed else { throw TaskError.alreadyCompleted }
        if scenario == .taskOptimisticDelayed, id == UITestTaskFixtures.todayPendingTaskID {
            try await Task.sleep(for: .seconds(2))
        }
        if scenario == .taskOptimisticFailure, id == UITestTaskFixtures.todayPendingTaskID {
            throw TaskError.rejected
        }
        if role == .member, task.assigneeIDs.contains(UITestTaskFixtures.kidMemberID) {
            throw TaskError.actionNotAllowed
        }
        let completed = FamilyTask(
            id: task.id,
            title: task.title,
            weight: task.weight,
            scheduledDate: task.scheduledDate,
            assigneeIDs: task.assigneeIDs.isEmpty ? [UITestTaskFixtures.memberID] : task.assigneeIDs,
            note: task.note,
            status: .completed,
            routineID: task.routineID,
            createdAt: task.createdAt
        )
        tasks[id] = completed
        if scenario == .taskCompletionConflict {
            throw TaskError.alreadyCompleted
        }
        return completed
    }

    func uploadSignalPhoto(_ jpeg: Data, accessToken: String) async throws -> String { "ui-test-signal-photo" }

    func signalTask(id: UUID, photoMediaID: String?, accessToken: String) async throws -> FamilyTask {
        guard let current = tasks[id] else { throw TaskError.notFound }
        let changed = FamilyTask(id: current.id, title: current.title, weight: current.weight,
                                 scheduledDate: current.scheduledDate, assigneeIDs: current.assigneeIDs,
                                 note: current.note, status: .awaitingConfirmation,
                                 routineID: current.routineID, createdAt: current.createdAt)
        tasks[id] = changed
        return changed
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

private enum UITestMissionFixtures {
    static let inProgressMissionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000e1")!
    static let completedMissionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000e2")!
}

/// Deterministic queue for TEL-015 (SPEC-013): three pending signals, oldest first, an empty queue or a failing load.
private struct UITestKidsSignalRepository: KidsSignalRepository {
    let scenario: UITestScenario

    func getReviewQueue(accessToken: String, cursor: String?) async throws -> KidsReviewQueuePage {
        switch scenario {
        case .kidsReviewQueue:
            return KidsReviewQueuePage(items: Self.items, nextCursor: nil)
        case .kidsReviewQueueFailure:
            throw KidsSignalError.network
        default:
            return KidsReviewQueuePage(items: [], nextCursor: nil)
        }
    }

    func getSignalDetail(id: UUID, accessToken: String) async throws -> KidsSignalDetail {
        guard let item = Self.items.first(where: { $0.id == id }) else { throw KidsSignalError.notFound }
        return KidsSignalDetail(id: id, taskID: item.taskID, taskTitle: item.taskTitle,
                                childName: item.childName, signaledAt: item.signaledAt,
                                assignees: [item.childName], photoMediaID: nil)
    }

    func decideSignal(id: UUID, decision: KidsReviewDecision, accessToken: String) async throws -> KidsDecisionResult {
        KidsDecisionResult(taskStatus: decision == .confirm ? .completed : .pending,
                           outcome: decision == .confirm ? "confirmed" : "rejected", applied: true)
    }

    func getSignalPhoto(mediaID: UUID, accessToken: String) async throws -> Data { Data() }

    private static let items: [KidsSignalSummary] = [
        ("Arrumar a cama", "Rafa Silva", "2026-10-27T10:00:00.000Z", true),
        ("Guardar os brinquedos", "Lucas Silva", "2026-10-27T11:30:00.000Z", false),
        ("Lavar a louça", "Rafa Silva", "2026-10-27T13:15:00.000Z", true),
    ].enumerated().map { index, row in
        KidsSignalSummary(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000050\(index + 1)")!,
            taskID: UUID(),
            taskTitle: row.0,
            signaledByID: UUID(),
            childName: row.1,
            signaledAt: ISO8601DateFormatter().date(from: row.2.replacingOccurrences(of: ".000Z", with: "Z"))!,
            hasPhoto: row.3
        )
    }
}

/// SPEC-014 Fase 2 UI fixture: two missions pre-linked to tasks already seeded by
/// `UITestTaskRepository`, so TEL-021/022's by-id hydration resolves end-to-end without a backend.
/// The in-progress mission links one task assigned to the adult fixture member and one assigned to
/// the Kids fixture member, so CA-19's own-task tap-through (and its absence for "de outra pessoa") is testable.
private actor UITestMissionRepository: MissionRepository {
    private let scenario: UITestScenario
    private var missions: [UUID: Mission]

    init(scenario: UITestScenario) {
        self.scenario = scenario
        let omitsRedemption = scenario == .missionManagementKids
        missions = [
            UITestMissionFixtures.inProgressMissionID: Mission(
                id: UITestMissionFixtures.inProgressMissionID,
                familyID: UITestTaskFixtures.familyID,
                title: "Casa pronta para o fim de semana",
                note: "Antes da visita da vó no sábado.",
                status: .inProgress,
                taskIDs: [UITestTaskFixtures.pendingTaskID, UITestTaskFixtures.awaitingConfirmationTaskID],
                completedAt: nil,
                isRedemptionAvailable: omitsRedemption ? nil : false,
                createdAt: Date(timeIntervalSince1970: 1_760_000_000)
            ),
            UITestMissionFixtures.completedMissionID: Mission(
                id: UITestMissionFixtures.completedMissionID,
                familyID: UITestTaskFixtures.familyID,
                title: "Semana organizada",
                note: nil,
                status: .completed,
                taskIDs: [UITestTaskFixtures.completedTaskID],
                completedAt: Date(timeIntervalSince1970: 1_760_100_000),
                isRedemptionAvailable: omitsRedemption ? nil : true,
                createdAt: Date(timeIntervalSince1970: 1_760_050_000)
            ),
        ]
    }

    func createMission(_ command: CreateMissionCommand, accessToken: String) async throws -> Mission {
        let mission = Mission(
            id: UUID(),
            familyID: UITestTaskFixtures.familyID,
            title: command.title,
            note: command.note,
            status: .inProgress,
            taskIDs: command.taskIDs,
            completedAt: nil,
            isRedemptionAvailable: scenario == .missionManagementKids ? nil : false,
            createdAt: Date()
        )
        missions[mission.id] = mission
        return mission
    }

    func mission(id: UUID, accessToken: String) async throws -> Mission {
        guard let mission = missions[id] else {
            throw MissionError.notFound
        }
        return mission
    }

    func missions(cursor: String?, accessToken: String) async throws -> MissionPage {
        let items = missions.values
            .sorted { $0.createdAt < $1.createdAt }
            .map {
                MissionSummary(
                    id: $0.id,
                    title: $0.title,
                    status: $0.status,
                    taskCount: $0.taskIDs.count,
                    completedTaskCount: $0.status == .completed ? $0.taskIDs.count : 0
                )
            }
        return MissionPage(items: items, nextCursor: nil)
    }

    func updateMission(_ command: UpdateMissionCommand, accessToken: String) async throws -> Mission {
        guard let current = missions[command.missionID] else {
            throw MissionError.notFound
        }
        guard current.status == .inProgress else {
            throw MissionError.completedProtected
        }
        let updated = Mission(
            id: current.id,
            familyID: current.familyID,
            title: command.title,
            note: command.note,
            status: current.status,
            taskIDs: command.taskIDs,
            completedAt: current.completedAt,
            isRedemptionAvailable: current.isRedemptionAvailable,
            createdAt: current.createdAt
        )
        missions[current.id] = updated
        return updated
    }

    func taskOptions(query: String?, cursor: String?, accessToken: String) async throws -> MissionTaskOptionPage {
        let allTasks: [MissionTaskOption] = [
            MissionTaskOption(
                id: UITestTaskFixtures.pendingTaskID,
                title: "Arrumar os brinquedos",
                weight: .medium,
                scheduledDate: "2026-10-10",
                status: .pending,
                assigneeIDs: [UITestTaskFixtures.memberID]
            ),
            MissionTaskOption(
                id: UITestTaskFixtures.completedTaskID,
                title: "Lavar a louça",
                weight: .low,
                scheduledDate: "2026-10-08",
                status: .completed,
                assigneeIDs: []
            ),
            MissionTaskOption(
                id: UITestTaskFixtures.awaitingConfirmationTaskID,
                title: "Guardar a roupa",
                weight: .high,
                scheduledDate: "2026-10-09",
                status: .awaitingConfirmation,
                assigneeIDs: [UITestTaskFixtures.kidMemberID]
            ),
        ]
        let filtered = query.map { text in allTasks.filter { $0.title.localizedCaseInsensitiveContains(text) } } ?? allTasks
        return MissionTaskOptionPage(items: filtered, nextCursor: nil)
    }
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

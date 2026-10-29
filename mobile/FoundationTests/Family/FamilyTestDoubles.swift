import Foundation
@testable import FamilyRoutine

// Existing test doubles can opt into family query fixtures only in tests that exercise SPEC-009.
extension FamilyRepository {
    func updateMemberName(memberID: UUID, name: String, accessToken: String) async throws -> FamilyMember { throw FamilyError.unavailable }
    func changeMemberRole(memberID: UUID, role: MemberRole, accessToken: String) async throws -> FamilyMember { throw FamilyError.unavailable }
    func removeMember(memberID: UUID, accessToken: String) async throws { throw FamilyError.unavailable }
    func leaveAdministration(accessToken: String) async throws -> FamilyMember { throw FamilyError.unavailable }
    func getWeeklyReport(referenceDate: String, accessToken: String) async throws -> WeeklyReportSnapshot {
        throw FamilyError.unavailable
    }
    func getFamilyOverview(range: FamilyDateRange?, accessToken: String) async throws -> FamilyOverview {
        throw FamilyError.unavailable
    }

    func listFamilyTasks(
        range: FamilyDateRange,
        memberID: UUID?,
        status: FamilyTaskStatusFilter,
        cursor: String?,
        accessToken: String
    ) async throws -> FamilyTaskPage {
        throw FamilyError.unavailable
    }
}
final class FamilyRepositorySpy: FamilyRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var createResult: Result<CreatedFamily, Error>
    private var uploadResults: [Result<String, Error>]
    private var linkResults: [Result<Void, Error>]
    private var memberResults: [Result<CreatedMember, Error>]
    private var settingsResult: Result<FamilySettings, Error>
    private var previewResults: [Result<TimeZoneChangePreview, Error>]
    private var changeTimeZoneResults: [Result<FamilySettings, Error>]
    private var listMembersResults: [Result<FamilyMemberPage, Error>]
    private var memberDetailResult: Result<FamilyMemberDetail, Error>
    private var memberNameUpdateResult: Result<FamilyMember, Error> = .failure(FamilyError.unavailable)
    private var _memberNameUpdateRequests: [(UUID, String)] = []
    private var inviteResults: [Result<MemberInvite, Error>]
    private var _invitedMemberIDs: [UUID] = []
    private var familyResult: Result<FamilyProfile, Error> = .success(FamilyRepositorySpy.defaultFamilyProfile)
    private var familyOverviewResult: Result<FamilyOverview, Error> = .failure(FamilyError.unavailable)
    private var familyTaskPageResult: Result<FamilyTaskPage, Error> = .failure(FamilyError.unavailable)
    private var leaveAdministrationResult: Result<FamilyMember, Error> = .failure(FamilyError.unavailable)
    private var _updatedFamilyNames: [String] = []
    private let createDelay: Duration?

    private var _createFamilyCalls = 0
    private var _uploadCalls = 0
    private var _inviteCalls = 0
    private var _getSettingsCalls = 0
    private var _previewCalls = 0
    private var _changeTimeZoneCalls = 0
    private var _memberDetailRequests: [UUID] = []
    private var _familyTaskRequests: [(FamilyDateRange, UUID?)] = []
    private var _createMemberCalls = 0
    private var _listMembersCalls = 0
    private var _lastCommand: CreateFamilyCommand?
    private var _uploadedPhotos: [Data] = []
    private var _linkedMediaIDs: [String] = []
    private var _createdMembers: [CreatedMember] = []
    private var _lastPreviewTimeZoneID: String?
    private var _lastPreviewApplication: TimeZoneApplication?
    private var _lastChangeTimeZoneID: String?
    private var _lastChangeApplication: TimeZoneApplication?

    var createFamilyCalls: Int { lock.withLock { _createFamilyCalls } }
    var uploadCalls: Int { lock.withLock { _uploadCalls } }
    var inviteCalls: Int { lock.withLock { _inviteCalls } }
    var invitedMemberIDs: [UUID] { lock.withLock { _invitedMemberIDs } }
    var getSettingsCalls: Int { lock.withLock { _getSettingsCalls } }
    var previewCalls: Int { lock.withLock { _previewCalls } }
    var changeTimeZoneCalls: Int { lock.withLock { _changeTimeZoneCalls } }
    var createMemberCalls: Int { lock.withLock { _createMemberCalls } }
    var listMembersCalls: Int { lock.withLock { _listMembersCalls } }
    func setMemberDetailResult(_ result: Result<FamilyMemberDetail, Error>) {
        lock.withLock { memberDetailResult = result }
    }

    func setMemberNameUpdateResult(_ result: Result<FamilyMember, Error>) {
        lock.withLock { memberNameUpdateResult = result }
    }

    var memberNameUpdateRequests: [(UUID, String)] { lock.withLock { _memberNameUpdateRequests } }

    func setFamilyResult(_ result: Result<FamilyProfile, Error>) {
        lock.withLock { familyResult = result }
    }

    func setFamilyOverviewResult(_ result: Result<FamilyOverview, Error>) {
        lock.withLock { familyOverviewResult = result }
    }

    func setFamilyTaskPageResult(_ result: Result<FamilyTaskPage, Error>) {
        lock.withLock { familyTaskPageResult = result }
    }

    func getFamilyOverview(range: FamilyDateRange?, accessToken: String) async throws -> FamilyOverview {
        try lock.withLock { familyOverviewResult }.get()
    }

    func listFamilyTasks(
        range: FamilyDateRange,
        memberID: UUID?,
        status: FamilyTaskStatusFilter,
        cursor: String?,
        accessToken: String
    ) async throws -> FamilyTaskPage {
        lock.withLock { _familyTaskRequests.append((range, memberID)) }
        return try lock.withLock { familyTaskPageResult }.get()
    }

    func setLeaveAdministrationResult(_ result: Result<FamilyMember, Error>) {
        lock.withLock { leaveAdministrationResult = result }
    }

    var updatedFamilyNames: [String] { lock.withLock { _updatedFamilyNames } }
    var memberDetailRequests: [UUID] { lock.withLock { _memberDetailRequests } }
    var familyTaskRequests: [(FamilyDateRange, UUID?)] { lock.withLock { _familyTaskRequests } }
    var lastCommand: CreateFamilyCommand? { lock.withLock { _lastCommand } }
    var uploadedPhotos: [Data] { lock.withLock { _uploadedPhotos } }
    var linkedMediaIDs: [String] { lock.withLock { _linkedMediaIDs } }
    var createdMembers: [CreatedMember] { lock.withLock { _createdMembers } }
    var lastPreviewTimeZoneID: String? { lock.withLock { _lastPreviewTimeZoneID } }
    var lastPreviewApplication: TimeZoneApplication? { lock.withLock { _lastPreviewApplication } }
    var lastChangeTimeZoneID: String? { lock.withLock { _lastChangeTimeZoneID } }
    var lastChangeApplication: TimeZoneApplication? { lock.withLock { _lastChangeApplication } }

    init(
        createResult: Result<CreatedFamily, Error> = .success(FamilyRepositorySpy.createdFamily),
        uploadResults: [Result<String, Error>] = [],
        linkResults: [Result<Void, Error>] = [],
        memberResults: [Result<CreatedMember, Error>] = [],
        settingsResult: Result<FamilySettings, Error> = .success(FamilyRepositorySpy.defaultSettings),
        previewResults: [Result<TimeZoneChangePreview, Error>] = [],
        changeTimeZoneResults: [Result<FamilySettings, Error>] = [],
        listMembersResults: [Result<FamilyMemberPage, Error>] = [],
        memberDetailResult: Result<FamilyMemberDetail, Error> = .success(FamilyRepositorySpy.defaultMemberDetail),
        inviteResults: [Result<MemberInvite, Error>] = [],
        createDelay: Duration? = nil
    ) {
        self.inviteResults = inviteResults
        self.createResult = createResult
        self.uploadResults = uploadResults
        self.linkResults = linkResults
        self.memberResults = memberResults
        self.settingsResult = settingsResult
        self.previewResults = previewResults
        self.changeTimeZoneResults = changeTimeZoneResults
        self.listMembersResults = listMembersResults
        self.memberDetailResult = memberDetailResult
        self.createDelay = createDelay
    }

    static let defaultSettings = FamilySettings(
        timeZoneID: "America/Sao_Paulo",
        scheduledTimeZoneChange: nil,
        limits: CycleLimits(
            startsAt: "2026-10-19T03:00:00.000Z",
            endsAt: "2026-10-26T03:00:00.000Z",
            timeZoneID: "America/Sao_Paulo",
            isTransition: false
        )
    )

    static let defaultFamilyProfile = FamilyProfile(
        id: UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!,
        name: "Família Silva",
        timeZoneID: "America/Sao_Paulo"
    )

    static let defaultMemberDetail = FamilyMemberDetail(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Maria Silva",
        role: .administrator,
        isFamilyCreator: true,
        createdAt: "2026-10-01T12:00:00.000Z",
        capabilities: MemberCapabilities(manageMembers: true)
    )

    static let createdFamily = CreatedFamily(
        familyID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Casa Silva",
        timeZoneID: "America/Sao_Paulo",
        session: AuthenticatedSession(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            profile: ActiveFamilySession(
                memberID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                familyID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                role: .administrator,
                isFamilyCreator: true
            ),
            credentials: SessionCredentials(
                token: SessionToken(accessToken: "access", expiresAt: Date(timeIntervalSince1970: 1_800_000_000)),
                refreshToken: "refresh"
            )
        )
    )

    func createFamily(_ command: CreateFamilyCommand, installationProof: String) async throws -> CreatedFamily {
        lock.withLock {
            _createFamilyCalls += 1
            _lastCommand = command
        }
        if let createDelay {
            try await Task.sleep(for: createDelay)
        }
        return try lock.withLock { createResult }.get()
    }

    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String {
        try lock.withLock {
            _uploadCalls += 1
            _uploadedPhotos.append(jpeg)
            guard !uploadResults.isEmpty else {
                return "media-1"
            }
            return try uploadResults.removeFirst().get()
        }
    }

    func setProfilePhoto(mediaID: String, accessToken: String) async throws {
        try lock.withLock {
            _linkedMediaIDs.append(mediaID)
            guard !linkResults.isEmpty else {
                return
            }
            try linkResults.removeFirst().get()
        }
    }

    func createMember(name: String, role: MemberRole, accessToken: String) async throws -> CreatedMember {
        try lock.withLock {
            _createMemberCalls += 1
            if !memberResults.isEmpty {
                let member = try memberResults.removeFirst().get()
                _createdMembers.append(member)
                return member
            }
            let member = CreatedMember(id: UUID(), name: name, role: role)
            _createdMembers.append(member)
            return member
        }
    }

    func issueInvite(memberID: UUID, accessToken: String) async throws -> MemberInvite {
        try lock.withLock {
            _inviteCalls += 1
            _invitedMemberIDs.append(memberID)
            if !inviteResults.isEmpty { return try inviteResults.removeFirst().get() }
            return MemberInvite(inviteID: UUID(), link: "https://example.test/invite", password: "PW")
        }
    }

    func listMembers(accessToken: String, cursor: String?) async throws -> FamilyMemberPage {
        try lock.withLock {
            _listMembersCalls += 1
            guard !listMembersResults.isEmpty else {
                return FamilyMemberPage(items: [], nextCursor: nil)
            }
            return try listMembersResults.removeFirst().get()
        }
    }

    func getMemberDetail(memberID: UUID, accessToken: String) async throws -> FamilyMemberDetail {
        try lock.withLock {
            _memberDetailRequests.append(memberID)
            return try memberDetailResult.get()
        }
    }

    func updateMemberName(memberID: UUID, name: String, accessToken: String) async throws -> FamilyMember {
        try lock.withLock {
            _memberNameUpdateRequests.append((memberID, name))
            return try memberNameUpdateResult.get()
        }
    }

    func getFamily(accessToken: String) async throws -> FamilyProfile {
        try lock.withLock { try familyResult.get() }
    }

    func leaveAdministration(accessToken: String) async throws -> FamilyMember {
        try lock.withLock { try leaveAdministrationResult.get() }
    }

    func updateFamilyName(_ name: String, accessToken: String) async throws -> FamilyProfile {
        try lock.withLock {
            _updatedFamilyNames.append(name)
            let current = try familyResult.get()
            let updated = FamilyProfile(id: current.id, name: name, timeZoneID: current.timeZoneID)
            familyResult = .success(updated)
            return updated
        }
    }

    func getFamilySettings(accessToken: String) async throws -> FamilySettings {
        try lock.withLock {
            _getSettingsCalls += 1
            return try settingsResult.get()
        }
    }

    func previewFamilyTimeZoneChange(
        timeZoneID: String,
        application: TimeZoneApplication,
        accessToken: String
    ) async throws -> TimeZoneChangePreview {
        try lock.withLock {
            _previewCalls += 1
            _lastPreviewTimeZoneID = timeZoneID
            _lastPreviewApplication = application
            if !previewResults.isEmpty {
                return try previewResults.removeFirst().get()
            }
            return TimeZoneChangePreview(
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
    }

    func changeFamilyTimeZone(
        timeZoneID: String,
        application: TimeZoneApplication,
        accessToken: String
    ) async throws -> FamilySettings {
        try lock.withLock {
            _changeTimeZoneCalls += 1
            _lastChangeTimeZoneID = timeZoneID
            _lastChangeApplication = application
            if !changeTimeZoneResults.isEmpty {
                return try changeTimeZoneResults.removeFirst().get()
            }
            return FamilySettings(
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
}

struct PhotoNormalizerStub: ProfilePhotoNormalizing {
    let result: Result<Data, Error>

    func normalize(_ data: Data) async throws -> Data {
        try result.get()
    }
}

struct AccessRepositoryStub: AccessRepository {
    func signIn(proof: AppleAuthorizationProof, installationProof: String) async throws -> AppleSignInOutcome {
        throw AccessError.unavailable
    }

    func currentSession(accessToken: String) async throws -> ActiveFamilySession {
        throw AccessError.unavailable
    }

    func refresh(refreshToken: String, installationProof: String) async throws -> SessionToken {
        throw AccessError.unavailable
    }

    func revokeSession(accessToken: String) async throws {}
}

final class FamilyCredentialStoreStub: SessionCredentialStoring, @unchecked Sendable {
    var savedRefreshToken: String?
    var saveFailuresRemaining = 0

    func refreshToken() throws -> String? { savedRefreshToken }
    func save(refreshToken: String) throws {
        if saveFailuresRemaining > 0 {
            saveFailuresRemaining -= 1
            throw KeychainSecretStoreError.invalidValue
        }
        savedRefreshToken = refreshToken
    }
    func clear() throws { savedRefreshToken = nil }
}

struct FamilyInstallationProofStub: InstallationProofProviding {
    func installationProof() throws -> String { "installation-proof" }
}

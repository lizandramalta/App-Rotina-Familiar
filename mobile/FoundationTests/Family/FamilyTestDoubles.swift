import Foundation
@testable import FamilyRoutine

actor FamilyRepositorySpy: FamilyRepository {
    private var createResult: Result<CreatedFamily, Error>
    private var uploadResults: [Result<String, Error>]
    private var linkResults: [Result<Void, Error>]
    private var memberResults: [Result<CreatedMember, Error>]
    private let createDelay: Duration?

    private(set) var createFamilyCalls = 0
    private(set) var uploadCalls = 0
    private(set) var inviteCalls = 0
    private(set) var lastCommand: CreateFamilyCommand?
    private(set) var uploadedPhotos: [Data] = []
    private(set) var linkedMediaIDs: [String] = []
    private(set) var createdMembers: [CreatedMember] = []

    init(
        createResult: Result<CreatedFamily, Error> = .success(FamilyRepositorySpy.createdFamily),
        uploadResults: [Result<String, Error>] = [],
        linkResults: [Result<Void, Error>] = [],
        memberResults: [Result<CreatedMember, Error>] = [],
        createDelay: Duration? = nil
    ) {
        self.createResult = createResult
        self.uploadResults = uploadResults
        self.linkResults = linkResults
        self.memberResults = memberResults
        self.createDelay = createDelay
    }

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
        createFamilyCalls += 1
        lastCommand = command
        if let createDelay {
            try await Task.sleep(for: createDelay)
        }
        return try createResult.get()
    }

    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String {
        uploadCalls += 1
        uploadedPhotos.append(jpeg)
        guard !uploadResults.isEmpty else {
            return "media-1"
        }
        return try uploadResults.removeFirst().get()
    }

    func setProfilePhoto(mediaID: String, accessToken: String) async throws {
        linkedMediaIDs.append(mediaID)
        guard !linkResults.isEmpty else {
            return
        }
        try linkResults.removeFirst().get()
    }

    func createMember(name: String, role: MemberRole, accessToken: String) async throws -> CreatedMember {
        if !memberResults.isEmpty {
            let member = try memberResults.removeFirst().get()
            createdMembers.append(member)
            return member
        }
        let member = CreatedMember(id: UUID(), name: name, role: role)
        createdMembers.append(member)
        return member
    }

    func issueInvite(memberID: UUID, accessToken: String) async throws -> MemberInvite {
        inviteCalls += 1
        return MemberInvite(inviteID: UUID(), link: "https://example.test/invite", password: "PW")
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

import Foundation
@testable import FamilyRoutine

enum RecognitionFixtures {
    static let id = UUID(uuidString: "00000000-0000-0000-0000-00000000c052")!
    /// Cycle 2026-09-28 (Mon) 00:00 → 2026-10-05 (Mon) 00:00 in America/Sao_Paulo (UTC-3).
    static let startsAt = ISO8601DateFormatter().date(from: "2026-09-28T03:00:00Z")!
    static let endsAt = ISO8601DateFormatter().date(from: "2026-10-05T03:00:00Z")!

    static func recognition(
        id: UUID = id,
        endsAt: Date = endsAt,
        isTie: Bool = false,
        openedAt: Date? = nil
    ) -> WeeklyRecognition {
        WeeklyRecognition(
            id: id,
            startsAt: endsAt.addingTimeInterval(-7 * 86_400),
            endsAt: endsAt,
            timeZoneID: "America/Sao_Paulo",
            isTransition: false,
            points: 42,
            completedTasks: 12,
            isTie: isTie,
            openedAt: openedAt
        )
    }
}

/// Scripted repository: each call pops the next result; records tokens and openings.
final class RecognitionRepositorySpy: RecognitionRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var detailResults: [Result<WeeklyRecognition, RecognitionError>]
    private var listResults: [Result<[WeeklyRecognition], RecognitionError>]
    private var openingResults: [Result<WeeklyRecognition, RecognitionError>]
    private(set) var detailTokens: [String] = []
    private(set) var openedIDs: [UUID] = []

    init(
        detail: [Result<WeeklyRecognition, RecognitionError>] = [],
        list: [Result<[WeeklyRecognition], RecognitionError>] = [],
        opening: [Result<WeeklyRecognition, RecognitionError>] = []
    ) {
        detailResults = detail
        listResults = list
        openingResults = opening
    }

    func listOwn(accessToken: String) async throws -> [WeeklyRecognition] {
        try lock.withLock { listResults.isEmpty ? [] : try listResults.removeFirst().get() }
    }

    func recognition(id: UUID, accessToken: String) async throws -> WeeklyRecognition {
        try lock.withLock {
            detailTokens.append(accessToken)
            guard !detailResults.isEmpty else { throw RecognitionError.unavailable }
            return try detailResults.removeFirst().get()
        }
    }

    func recordOpening(id: UUID, accessToken: String) async throws -> WeeklyRecognition {
        try lock.withLock {
            openedIDs.append(id)
            guard !openingResults.isEmpty else { return RecognitionFixtures.recognition(openedAt: Date()) }
            return try openingResults.removeFirst().get()
        }
    }
}

@MainActor
final class HighlightSharingSpy: HighlightSharing {
    var canOpenWhatsApp: Bool
    var opensSucceed = true
    private(set) var openedTexts: [String] = []
    private(set) var copiedTexts: [String] = []

    init(canOpenWhatsApp: Bool = true) {
        self.canOpenWhatsApp = canOpenWhatsApp
    }

    func openWhatsApp(text: String) async -> Bool {
        openedTexts.append(text)
        return opensSucceed
    }

    func copy(text: String) {
        copiedTexts.append(text)
    }
}

@MainActor
final class RecognitionSessionStub: RecognitionSessionProviding {
    var currentAccessToken: String?
    var recoveredToken: String?
    private(set) var recoveryCount = 0

    init(token: String? = "access-1", recoveredToken: String? = nil) {
        currentAccessToken = token
        self.recoveredToken = recoveredToken
    }

    func recoverAccessToken() async -> String? {
        recoveryCount += 1
        if let recoveredToken { currentAccessToken = recoveredToken }
        return recoveredToken
    }
}

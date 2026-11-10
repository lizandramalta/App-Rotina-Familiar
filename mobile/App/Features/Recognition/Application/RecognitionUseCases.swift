import Foundation

/// Fetches the owner's recognition, recovering an invalid session once before giving up (UX-020 §3).
@MainActor
struct GetOwnWeeklyRecognitionUseCase {
    let repository: any RecognitionRepository
    let session: any RecognitionSessionProviding

    func callAsFunction(id: UUID) async throws -> WeeklyRecognition {
        try await withRecoveredSession { token in
            try await repository.recognition(id: id, accessToken: token)
        }
    }

    /// Most recent result still featured in Minhas tarefas (E-1), or `nil`.
    func featured(now: Date) async throws -> WeeklyRecognition? {
        let items = try await withRecoveredSession { token in
            try await repository.listOwn(accessToken: token)
        }
        guard let latest = items.max(by: { $0.endsAt < $1.endsAt }) else { return nil }
        return latest.isFeatured(at: now) ? latest : nil
    }

    /// Best effort and monotonic: failure never changes what TEL-052 shows.
    func recordOpening(id: UUID) async {
        _ = try? await withRecoveredSession { token in
            try await repository.recordOpening(id: id, accessToken: token)
        }
    }

    private func withRecoveredSession<T>(_ work: (String) async throws -> T) async throws -> T {
        guard let token = session.currentAccessToken else {
            guard let recovered = await session.recoverAccessToken() else { throw RecognitionError.sessionExpired }
            return try await work(recovered)
        }
        do {
            return try await work(token)
        } catch RecognitionError.sessionExpired {
            guard let recovered = await session.recoverAccessToken() else { throw RecognitionError.sessionExpired }
            return try await work(recovered)
        }
    }
}

/// Builds the editable celebration message (RF64, UF-15, E-2). Kids use the same text.
struct PrepareHighlightShareUseCase {
    func callAsFunction(for recognition: WeeklyRecognition) -> String {
        recognition.isTie
            ? String(localized: "recognition.message.tie")
            : String(localized: "recognition.message.first")
    }

    /// E-4: an empty (or blank) message can't be shared nor copied.
    static func isShareable(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

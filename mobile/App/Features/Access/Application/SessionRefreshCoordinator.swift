import Foundation

actor SessionRefreshCoordinator {
    private var activeRefresh: Task<SessionToken, Error>?

    func refresh(
        repository: any AccessRepository,
        refreshToken: String,
        installationProof: String
    ) async throws -> SessionToken {
        if let activeRefresh {
            return try await activeRefresh.value
        }

        let refreshTask = Task {
            try await repository.refresh(
                refreshToken: refreshToken,
                installationProof: installationProof
            )
        }
        activeRefresh = refreshTask

        do {
            let token = try await refreshTask.value
            activeRefresh = nil
            return token
        } catch {
            activeRefresh = nil
            throw error
        }
    }
}

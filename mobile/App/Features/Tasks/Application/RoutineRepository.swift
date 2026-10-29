import Foundation

nonisolated protocol RoutineRepository: Sendable {
    /// The family's time zone supplies the default civil start date in MOD-002 (RN11, UX-008 §5.2).
    func familyTimeZoneID(accessToken: String) async throws -> String
    func createRoutine(_ command: CreateRoutineCommand, accessToken: String) async throws -> Routine
    func routine(id: UUID, accessToken: String) async throws -> Routine
    func updateFutureRoutine(
        id: UUID,
        command: UpdateFutureRoutineCommand,
        accessToken: String
    ) async throws -> UpdateFutureRoutineResult
    func deleteFutureTasks(id: UUID, fromTaskID: UUID, accessToken: String) async throws -> DeleteFutureRoutineTasksResult
}

nonisolated struct CreateRoutineUseCase: Sendable {
    let repository: any RoutineRepository

    func execute(_ command: CreateRoutineCommand, accessToken: String) async throws -> Routine {
        try await repository.createRoutine(command, accessToken: accessToken)
    }
}

nonisolated struct GetRoutineUseCase: Sendable {
    let repository: any RoutineRepository

    func execute(id: UUID, accessToken: String) async throws -> Routine {
        try await repository.routine(id: id, accessToken: accessToken)
    }
}

/// SPEC-008 Fase 2 — CA-07: the open occurrence and the following ones.
nonisolated struct UpdateFutureRoutineUseCase: Sendable {
    let repository: any RoutineRepository

    func execute(routineID: UUID, command: UpdateFutureRoutineCommand, accessToken: String) async throws -> UpdateFutureRoutineResult {
        try await repository.updateFutureRoutine(id: routineID, command: command, accessToken: accessToken)
    }
}

/// SPEC-008 Fase 2 — CA-08: deletes the open occurrence and the following ones, ending the routine.
nonisolated struct DeleteFutureRoutineTasksUseCase: Sendable {
    let repository: any RoutineRepository

    func execute(routineID: UUID, fromTaskID: UUID, accessToken: String) async throws -> DeleteFutureRoutineTasksResult {
        try await repository.deleteFutureTasks(id: routineID, fromTaskID: fromTaskID, accessToken: accessToken)
    }
}

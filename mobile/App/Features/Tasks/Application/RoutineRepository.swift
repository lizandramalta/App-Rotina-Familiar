import Foundation

nonisolated protocol RoutineRepository: Sendable {
    /// The family's time zone supplies the default civil start date in MOD-002 (RN11, UX-008 §5.2).
    func familyTimeZoneID(accessToken: String) async throws -> String
    func createRoutine(_ command: CreateRoutineCommand, accessToken: String) async throws -> Routine
    func routine(id: UUID, accessToken: String) async throws -> Routine
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

import Foundation

nonisolated protocol TaskRepository: Sendable {
    func createTask(_ command: CreateTaskCommand, accessToken: String) async throws -> FamilyTask
    func task(id: UUID, accessToken: String) async throws -> FamilyTask
    func updateTask(_ command: UpdateTaskCommand, accessToken: String) async throws -> FamilyTask
    func deleteTask(id: UUID, accessToken: String) async throws -> UUID
    /// `referenceDate` is `YYYY-MM-DD`. Backs TEL-010/TEL-040 (SPEC-009 Fase 1).
    func dailyTasks(referenceDate: String, cursor: String?, accessToken: String) async throws -> OwnTaskPage
    func dailyProgress(referenceDate: String, accessToken: String) async throws -> DailyProgress
}

import Foundation

nonisolated protocol TaskRepository: Sendable {
    func createTask(_ command: CreateTaskCommand, accessToken: String) async throws -> FamilyTask
    func task(id: UUID, accessToken: String) async throws -> FamilyTask
    func updateTask(_ command: UpdateTaskCommand, accessToken: String) async throws -> FamilyTask
    func deleteTask(id: UUID, accessToken: String) async throws -> UUID
    /// SPEC-010 CA-01/02/05: the server derives the actor and returns the canonical task.
    func completeTask(id: UUID, accessToken: String) async throws -> FamilyTask
    func uploadSignalPhoto(_ jpeg: Data, accessToken: String) async throws -> String
    func signalTask(id: UUID, photoMediaID: String?, accessToken: String) async throws -> FamilyTask
    /// `referenceDate` is `YYYY-MM-DD`. Backs TEL-010/TEL-040 (SPEC-009 Fase 1).
    func dailyTasks(referenceDate: String, cursor: String?, accessToken: String) async throws -> OwnTaskPage
    func dailyProgress(referenceDate: String, accessToken: String) async throws -> DailyProgress
    /// Per SPEC-011 E-01: always called first without `confirm`; retried with `confirm: true`
    /// only after the server refuses with `.missionReopenRequiresConfirmation`.
    func reopenTask(id: UUID, confirm: Bool, accessToken: String) async throws -> FamilyTask
}

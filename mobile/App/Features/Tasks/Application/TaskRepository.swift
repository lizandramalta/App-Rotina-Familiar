import Foundation

nonisolated protocol TaskRepository: Sendable {
    func createTask(_ command: CreateTaskCommand, accessToken: String) async throws -> FamilyTask
    func task(id: UUID, accessToken: String) async throws -> FamilyTask
    func updateTask(_ command: UpdateTaskCommand, accessToken: String) async throws -> FamilyTask
    func deleteTask(id: UUID, accessToken: String) async throws -> UUID
}

import Foundation

struct CreateTaskUseCase: Sendable {
    let repository: any TaskRepository

    func execute(_ command: CreateTaskCommand, accessToken: String) async throws -> FamilyTask {
        try await repository.createTask(command, accessToken: accessToken)
    }
}

struct GetTaskDetailUseCase: Sendable {
    let repository: any TaskRepository

    func execute(taskID: UUID, accessToken: String) async throws -> FamilyTask {
        try await repository.task(id: taskID, accessToken: accessToken)
    }
}

struct UpdateTaskUseCase: Sendable {
    let repository: any TaskRepository

    func execute(_ command: UpdateTaskCommand, accessToken: String) async throws -> FamilyTask {
        try await repository.updateTask(command, accessToken: accessToken)
    }
}

struct DeleteTaskUseCase: Sendable {
    let repository: any TaskRepository

    func execute(taskID: UUID, accessToken: String) async throws -> UUID {
        try await repository.deleteTask(id: taskID, accessToken: accessToken)
    }
}

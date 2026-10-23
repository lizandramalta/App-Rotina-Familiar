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

struct GetDailyTasksUseCase: Sendable {
    let repository: any TaskRepository

    func execute(referenceDate: String, cursor: String?, accessToken: String) async throws -> OwnTaskPage {
        try await repository.dailyTasks(referenceDate: referenceDate, cursor: cursor, accessToken: accessToken)
    }
}

struct GetDailyProgressUseCase: Sendable {
    let repository: any TaskRepository

    func execute(referenceDate: String, accessToken: String) async throws -> DailyProgress {
        try await repository.dailyProgress(referenceDate: referenceDate, accessToken: accessToken)
    }
}

struct ReopenTaskUseCase: Sendable {
    let repository: any TaskRepository

    func execute(taskID: UUID, confirm: Bool, accessToken: String) async throws -> FamilyTask {
        try await repository.reopenTask(id: taskID, confirm: confirm, accessToken: accessToken)
    }
}

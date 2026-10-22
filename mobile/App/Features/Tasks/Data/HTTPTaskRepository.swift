import Foundation

nonisolated private struct TaskDTO: Decodable {
    let id: UUID
    let title: String
    let weight: Int
    let scheduledDate: String
    let assigneeIds: [UUID]
    let note: String?
    let status: TaskStatus
    let routineId: UUID?
    let createdAt: Date
}

nonisolated private struct CreateTaskRequestDTO: Encodable {
    let title: String
    let weight: Int
    let scheduledDate: String
    let assigneeIds: [UUID]
    let note: String?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(weight, forKey: .weight)
        try container.encode(scheduledDate, forKey: .scheduledDate)
        try container.encode(assigneeIds, forKey: .assigneeIds)
        try container.encode(note, forKey: .note)
    }

    private enum CodingKeys: String, CodingKey {
        case title, weight, scheduledDate, assigneeIds, note
    }
}

/// Always carries every single-task field (TEL-013 is one unified form); `signalResolution`
/// is included only when editing an `awaitingConfirmation` task, per the contract's "ignored
/// outside that state" rule — simplest to just not send it rather than rely on that leniency.
nonisolated private struct UpdateTaskRequestDTO: Encodable {
    let title: String
    let weight: Int
    let scheduledDate: String
    let assigneeIds: [UUID]
    let note: String?
    let signalResolution: SignalResolution?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(weight, forKey: .weight)
        try container.encode(scheduledDate, forKey: .scheduledDate)
        try container.encode(assigneeIds, forKey: .assigneeIds)
        try container.encode(note, forKey: .note)
        if let signalResolution {
            try container.encode(signalResolution, forKey: .signalResolution)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case title, weight, scheduledDate, assigneeIds, note, signalResolution
    }
}

nonisolated private struct DeleteTaskResponseDTO: Decodable {
    let id: UUID
}

nonisolated private struct ProblemDetailsDTO: Decodable {
    let code: String?
    let fieldErrors: [String: [String]]?
}

nonisolated struct HTTPTaskRepository: TaskRepository {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Never retried here: with no id yet, an ambiguous failure cannot be reconciled by a `GET`,
    /// so it is reported as uncertain rather than as a plain network error (BA-07).
    func createTask(_ command: CreateTaskCommand, accessToken: String) async throws -> FamilyTask {
        let body = CreateTaskRequestDTO(
            title: command.title,
            weight: command.weight.rawValue,
            scheduledDate: command.scheduledDate,
            assigneeIds: command.assigneeIDs,
            note: command.note
        )
        do {
            let data = try await send(path: "tasks", method: "POST", accessToken: accessToken, json: body)
            return try Self.toFamilyTask(decode(TaskDTO.self, from: data))
        } catch TaskError.network, TaskError.unavailable {
            throw TaskError.uncertainOutcome
        } catch is DecodingError {
            throw TaskError.uncertainOutcome
        }
    }

    func task(id: UUID, accessToken: String) async throws -> FamilyTask {
        let data = try await send(path: "tasks/\(id.uuidString.lowercased())", method: "GET", accessToken: accessToken)
        return try Self.toFamilyTask(decode(TaskDTO.self, from: data))
    }

    /// A network/server failure here is left as `.network`/`.unavailable`: unlike creation, the
    /// caller already knows the task id and must reconcile via `task(id:)` before retrying (SPEC-007 §5.3).
    func updateTask(_ command: UpdateTaskCommand, accessToken: String) async throws -> FamilyTask {
        let body = UpdateTaskRequestDTO(
            title: command.title,
            weight: command.weight.rawValue,
            scheduledDate: command.scheduledDate,
            assigneeIds: command.assigneeIDs,
            note: command.note,
            signalResolution: command.signalResolution
        )
        let data = try await send(
            path: "tasks/\(command.taskID.uuidString.lowercased())",
            method: "PATCH",
            accessToken: accessToken,
            json: body
        )
        return try Self.toFamilyTask(decode(TaskDTO.self, from: data))
    }

    func deleteTask(id: UUID, accessToken: String) async throws -> UUID {
        let data = try await send(path: "tasks/\(id.uuidString.lowercased())", method: "DELETE", accessToken: accessToken)
        return try decode(DeleteTaskResponseDTO.self, from: data).id
    }

    private static func toFamilyTask(_ dto: TaskDTO) throws -> FamilyTask {
        guard let weight = EffortWeight(rawValue: dto.weight) else {
            throw TaskError.unavailable
        }
        return FamilyTask(
            id: dto.id,
            title: dto.title,
            weight: weight,
            scheduledDate: dto.scheduledDate,
            assigneeIDs: dto.assigneeIds,
            note: dto.note,
            status: dto.status,
            routineID: dto.routineId,
            createdAt: dto.createdAt
        )
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let plain = ISO8601DateFormatter()
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = plain.date(from: text) ?? fractional.date(from: text) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Invalid ISO 8601 date")
                )
            }
            return date
        }
        return decoder
    }

    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            throw TaskError.unavailable
        }
    }

    private func send(path: String, method: String, accessToken: String) async throws -> Data {
        try await send(rawRequest: makeRequest(path: path, method: method, accessToken: accessToken))
    }

    private func send(
        path: String,
        method: String,
        accessToken: String,
        json body: some Encodable
    ) async throws -> Data {
        var request = makeRequest(path: path, method: method, accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(rawRequest: request)
    }

    private func makeRequest(path: String, method: String, accessToken: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(rawRequest request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw TaskError.unavailable
            }
            guard (200 ... 299).contains(response.statusCode) else {
                throw Self.error(for: response.statusCode, data: data)
            }
            return data
        } catch let error as TaskError {
            throw error
        } catch is URLError {
            throw TaskError.network
        } catch {
            throw TaskError.unavailable
        }
    }

    private static func error(for statusCode: Int, data: Data) -> TaskError {
        let problem = try? decoder.decode(ProblemDetailsDTO.self, from: data)
        switch (statusCode, problem?.code) {
        case (403, "ACTION_NOT_ALLOWED"):
            return .actionNotAllowed
        case (404, _):
            return .notFound
        case (409, "TASK_ALREADY_COMPLETED"):
            return .alreadyCompleted
        case (409, "MISSION_COMPLETED_PROTECTED"):
            return .missionCompletedProtected
        case (409, "MISSION_WOULD_HAVE_NO_TASKS"):
            return .missionWouldHaveNoTasks
        case (422, "SIGNAL_RESOLUTION_REQUIRED"):
            return .signalResolutionRequired
        case (422, "VALIDATION_FAILED"):
            return .validationFailed(problem?.fieldErrors ?? [:])
        case (503, _):
            return .unavailable
        case (500..., _):
            return .unavailable
        default:
            return .rejected
        }
    }
}

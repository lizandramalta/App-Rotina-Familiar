import Foundation

nonisolated private struct RoutineDTO: Decodable {
    let id: UUID
    let title: String
    let weight: Int
    let assigneeIds: [UUID]
    let note: String?
    let startDate: String
    let frequencyDays: Int
    let isActive: Bool
    let materializationState: RoutineMaterializationState
}

nonisolated private struct CreateRoutineRequestDTO: Encodable {
    let title: String
    let weight: Int
    let assigneeIds: [UUID]
    let note: String?
    let startDate: String
    let frequencyDays: Int
}

nonisolated private struct UpdateFutureRoutineRequestDTO: Encodable {
    let fromTaskId: UUID
    let title: String
    let weight: Int
    let assigneeIds: [UUID]
    let note: String?

    // `note: null` removes the note, so it is always sent explicitly.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fromTaskId, forKey: .fromTaskId)
        try container.encode(title, forKey: .title)
        try container.encode(weight, forKey: .weight)
        try container.encode(assigneeIds, forKey: .assigneeIds)
        try container.encode(note, forKey: .note)
    }

    private enum CodingKeys: String, CodingKey {
        case fromTaskId, title, weight, assigneeIds, note
    }
}

nonisolated private struct UpdateFutureRoutineResponseDTO: Decodable {
    let routine: RoutineDTO
    let updatedTaskIds: [UUID]
    let preservedTaskIds: [UUID]
}

nonisolated private struct DeleteFutureRoutineTasksRequestDTO: Encodable {
    let fromTaskId: UUID
}

nonisolated private struct DeleteFutureRoutineTasksResponseDTO: Decodable {
    let routineId: UUID
    let deletedTaskIds: [UUID]
    let preservedTaskIds: [UUID]
}

nonisolated private struct FamilyTimeZoneDTO: Decodable {
    let timeZoneId: String
}

nonisolated private struct RoutineProblemDTO: Decodable {
    let code: String?
    let fieldErrors: [String: [String]]?
}

/// SPEC-008 Fases 1 e 2 — bearer-scoped routines; no automatic replay of a write (MA-08).
nonisolated struct HTTPRoutineRepository: RoutineRepository {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func familyTimeZoneID(accessToken: String) async throws -> String {
        let data = try await send(path: "family", method: "GET", accessToken: accessToken)
        let timeZoneID = try decode(FamilyTimeZoneDTO.self, from: data).timeZoneId
        guard TimeZone(identifier: timeZoneID) != nil else { throw RoutineError.unavailable }
        return timeZoneID
    }

    func createRoutine(_ command: CreateRoutineCommand, accessToken: String) async throws -> Routine {
        let body = CreateRoutineRequestDTO(
            title: command.title,
            weight: command.weight.rawValue,
            assigneeIds: command.assigneeIDs,
            note: command.note,
            startDate: command.startDate,
            frequencyDays: command.frequency.rawValue
        )
        do {
            let data = try await send(path: "routines", method: "POST", accessToken: accessToken, body: body)
            return try toRoutine(decode(RoutineDTO.self, from: data))
        } catch RoutineError.network, RoutineError.unavailable {
            // No routine ID is known on a lost create response, so do not guess or retry.
            throw RoutineError.uncertainOutcome
        } catch is DecodingError {
            throw RoutineError.uncertainOutcome
        }
    }

    func routine(id: UUID, accessToken: String) async throws -> Routine {
        let data = try await send(path: "routines/\(id.uuidString.lowercased())", method: "GET", accessToken: accessToken)
        return try toRoutine(decode(RoutineDTO.self, from: data))
    }

    func updateFutureRoutine(
        id: UUID,
        command: UpdateFutureRoutineCommand,
        accessToken: String
    ) async throws -> UpdateFutureRoutineResult {
        let body = UpdateFutureRoutineRequestDTO(
            fromTaskId: command.fromTaskID,
            title: command.title,
            weight: command.weight.rawValue,
            assigneeIds: command.assigneeIDs,
            note: command.note
        )
        do {
            let data = try await send(path: routinePath(id), method: "PATCH", accessToken: accessToken, body: body)
            let dto = try decode(UpdateFutureRoutineResponseDTO.self, from: data)
            return UpdateFutureRoutineResult(
                routine: try toRoutine(dto.routine),
                updatedTaskIDs: dto.updatedTaskIds,
                preservedTaskIDs: dto.preservedTaskIds
            )
        } catch RoutineError.network, RoutineError.unavailable {
            // The write may have been applied; the caller reconciles before any new attempt.
            throw RoutineError.uncertainOutcome
        } catch is DecodingError {
            throw RoutineError.uncertainOutcome
        }
    }

    func deleteFutureTasks(
        id: UUID,
        fromTaskID: UUID,
        accessToken: String
    ) async throws -> DeleteFutureRoutineTasksResult {
        let body = DeleteFutureRoutineTasksRequestDTO(fromTaskId: fromTaskID)
        do {
            let data = try await send(
                path: routinePath(id) + "/future-task-deletions",
                method: "POST",
                accessToken: accessToken,
                body: body
            )
            let dto = try decode(DeleteFutureRoutineTasksResponseDTO.self, from: data)
            return DeleteFutureRoutineTasksResult(
                routineID: dto.routineId,
                deletedTaskIDs: dto.deletedTaskIds,
                preservedTaskIDs: dto.preservedTaskIds
            )
        } catch RoutineError.network, RoutineError.unavailable {
            throw RoutineError.uncertainOutcome
        } catch is DecodingError {
            throw RoutineError.uncertainOutcome
        }
    }

    private func routinePath(_ id: UUID) -> String {
        "routines/\(id.uuidString.lowercased())"
    }

    private func toRoutine(_ dto: RoutineDTO) throws -> Routine {
        guard let weight = EffortWeight(rawValue: dto.weight),
              let frequency = RoutineFrequency(rawValue: dto.frequencyDays) else {
            throw RoutineError.unavailable
        }
        return Routine(
            id: dto.id,
            title: dto.title,
            weight: weight,
            assigneeIDs: dto.assigneeIds,
            note: dto.note,
            startDate: dto.startDate,
            frequency: frequency,
            isActive: dto.isActive,
            materializationState: dto.materializationState
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    private func send(path: String, method: String, accessToken: String) async throws -> Data {
        try await send(request: makeRequest(path: path, method: method, accessToken: accessToken))
    }

    private func send(path: String, method: String, accessToken: String, body: some Encodable) async throws -> Data {
        var request = makeRequest(path: path, method: method, accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request: request)
    }

    private func makeRequest(path: String, method: String, accessToken: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw RoutineError.unavailable }
            guard (200 ... 299).contains(response.statusCode) else {
                throw Self.error(for: response.statusCode, data: data)
            }
            return data
        } catch let error as RoutineError {
            throw error
        } catch is URLError {
            throw RoutineError.network
        } catch {
            throw RoutineError.unavailable
        }
    }

    private static func error(for status: Int, data: Data) -> RoutineError {
        let problem = try? JSONDecoder().decode(RoutineProblemDTO.self, from: data)
        switch (status, problem?.code) {
        case (403, "ACTION_NOT_ALLOWED"):
            return .actionNotAllowed
        case (409, "MISSION_COMPLETED_PROTECTED"):
            return .missionProtected
        case (409, "MISSION_WOULD_HAVE_NO_TASKS"):
            return .missionWouldHaveNoTasks
        case (404, _):
            return .notFound
        case (422, "VALIDATION_FAILED"):
            return .validationFailed(problem?.fieldErrors ?? [:])
        case (503, _), (500..., _):
            return .unavailable
        default:
            return .rejected
        }
    }
}

import Foundation

nonisolated private struct MissionDTO: Decodable {
    let id: UUID
    let familyId: UUID
    let title: String
    let note: String?
    let status: MissionStatus
    let taskIds: [UUID]
    let completedAt: Date?
    /// Absent (never present-but-false) in the Kids projection (SPEC-014 CA-19) — `Bool?`
    /// decodes a missing key as `nil` without throwing, no custom `init(from:)` needed.
    let isRedemptionAvailable: Bool?
    let createdAt: Date
}

nonisolated private struct MissionSummaryDTO: Decodable {
    let id: UUID
    let title: String
    let status: MissionStatus
    let taskCount: Int
    let completedTaskCount: Int
}

nonisolated private struct MissionListResponseDTO: Decodable {
    let items: [MissionSummaryDTO]
    let nextCursor: String?
}

nonisolated private struct MissionTaskOptionDTO: Decodable {
    let id: UUID
    let title: String
    let weight: Int
    let scheduledDate: String
    let status: TaskStatus
    let assigneeIds: [UUID]
}

nonisolated private struct MissionTaskOptionsResponseDTO: Decodable {
    let items: [MissionTaskOptionDTO]
    let nextCursor: String?
}

/// Create and update share one body shape (SPEC-014 §5.2: "PATCH segue a convenção comum... mesmo
/// shape"). `note` is always encoded, even when `nil`, so an edit can explicitly clear it (RN68).
nonisolated private struct MissionRequestDTO: Encodable {
    let title: String
    let note: String?
    let taskIds: [UUID]

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(note, forKey: .note)
        try container.encode(taskIds, forKey: .taskIds)
    }

    private enum CodingKeys: String, CodingKey {
        case title, note, taskIds
    }
}

nonisolated private struct ProblemDetailsDTO: Decodable {
    let code: String?
    let fieldErrors: [String: [String]]?
}

nonisolated struct HTTPMissionRepository: MissionRepository {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Never retried here: with no id yet, an ambiguous failure cannot be reconciled by a `GET`,
    /// so it is reported as uncertain rather than as a plain network error (BA-07, SPEC-014 §5.3).
    func createMission(_ command: CreateMissionCommand, accessToken: String) async throws -> Mission {
        let body = MissionRequestDTO(title: command.title, note: command.note, taskIds: command.taskIDs)
        do {
            let data = try await send(path: "missions", method: "POST", accessToken: accessToken, json: body)
            return Self.toMission(try decode(MissionDTO.self, from: data))
        } catch MissionError.network, MissionError.unavailable {
            throw MissionError.uncertainOutcome
        } catch is DecodingError {
            throw MissionError.uncertainOutcome
        }
    }

    func mission(id: UUID, accessToken: String) async throws -> Mission {
        let data = try await send(path: "missions/\(id.uuidString.lowercased())", method: "GET", accessToken: accessToken)
        return Self.toMission(try decode(MissionDTO.self, from: data))
    }

    func missions(cursor: String?, accessToken: String) async throws -> MissionPage {
        var items: [URLQueryItem] = []
        if let cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        let data = try await send(path: "missions", method: "GET", queryItems: items, accessToken: accessToken)
        let response = try decode(MissionListResponseDTO.self, from: data)
        return MissionPage(items: response.items.map(Self.toMissionSummary), nextCursor: response.nextCursor)
    }

    /// A network/server failure here is left as `.network`/`.unavailable`: unlike creation, the
    /// caller already knows the mission id and must reconcile via `mission(id:)` before retrying.
    func updateMission(_ command: UpdateMissionCommand, accessToken: String) async throws -> Mission {
        let body = MissionRequestDTO(title: command.title, note: command.note, taskIds: command.taskIDs)
        let data = try await send(
            path: "missions/\(command.missionID.uuidString.lowercased())",
            method: "PATCH",
            accessToken: accessToken,
            json: body
        )
        return Self.toMission(try decode(MissionDTO.self, from: data))
    }

    func taskOptions(query: String?, cursor: String?, accessToken: String) async throws -> MissionTaskOptionPage {
        var items: [URLQueryItem] = []
        if let query, !query.isEmpty {
            items.append(URLQueryItem(name: "query", value: query))
        }
        if let cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        let data = try await send(path: "missions/task-options", method: "GET", queryItems: items, accessToken: accessToken)
        let response = try decode(MissionTaskOptionsResponseDTO.self, from: data)
        return try MissionTaskOptionPage(items: response.items.map(Self.toMissionTaskOption), nextCursor: response.nextCursor)
    }

    private static func toMission(_ dto: MissionDTO) -> Mission {
        Mission(
            id: dto.id,
            familyID: dto.familyId,
            title: dto.title,
            note: dto.note,
            status: dto.status,
            taskIDs: dto.taskIds,
            completedAt: dto.completedAt,
            isRedemptionAvailable: dto.isRedemptionAvailable,
            createdAt: dto.createdAt
        )
    }

    private static func toMissionSummary(_ dto: MissionSummaryDTO) -> MissionSummary {
        MissionSummary(
            id: dto.id,
            title: dto.title,
            status: dto.status,
            taskCount: dto.taskCount,
            completedTaskCount: dto.completedTaskCount
        )
    }

    private static func toMissionTaskOption(_ dto: MissionTaskOptionDTO) throws -> MissionTaskOption {
        guard let weight = EffortWeight(rawValue: dto.weight) else {
            throw MissionError.unavailable
        }
        return MissionTaskOption(
            id: dto.id,
            title: dto.title,
            weight: weight,
            scheduledDate: dto.scheduledDate,
            status: dto.status,
            assigneeIDs: dto.assigneeIds
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
            throw MissionError.unavailable
        }
    }

    private func send(path: String, method: String, accessToken: String) async throws -> Data {
        try await send(rawRequest: makeRequest(path: path, method: method, accessToken: accessToken))
    }

    private func send(path: String, method: String, queryItems: [URLQueryItem], accessToken: String) async throws -> Data {
        try await send(rawRequest: makeRequest(path: path, method: method, queryItems: queryItems, accessToken: accessToken))
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

    private func makeRequest(path: String, method: String, queryItems: [URLQueryItem], accessToken: String) -> URLRequest {
        let url = baseURL.appending(path: path).appending(queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(rawRequest request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw MissionError.unavailable
            }
            guard (200 ... 299).contains(response.statusCode) else {
                throw Self.error(for: response.statusCode, data: data)
            }
            return data
        } catch let error as MissionError {
            throw error
        } catch is URLError {
            throw MissionError.network
        } catch {
            throw MissionError.unavailable
        }
    }

    private static func error(for statusCode: Int, data: Data) -> MissionError {
        let problem = try? decoder.decode(ProblemDetailsDTO.self, from: data)
        switch (statusCode, problem?.code) {
        case (403, "ACTION_NOT_ALLOWED"):
            return .actionNotAllowed
        case (404, _):
            return .notFound
        case (409, "MISSION_COMPLETED_PROTECTED"):
            return .completedProtected
        case (409, "MISSION_WOULD_HAVE_NO_TASKS"):
            return .wouldHaveNoTasks
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

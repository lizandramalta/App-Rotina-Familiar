import Foundation

nonisolated private struct RewardItemDTO: Decodable {
    let id: UUID
    let title: String
    let details: String?
    let source: RewardItemSource
    /// Absent for predefined items (SPEC-015 §6) — `Date?` decodes a missing key as `nil`.
    let createdAt: Date?
}

nonisolated private struct RewardCatalogDTO: Decodable {
    let predefined: [RewardItemDTO]
    let custom: [RewardItemDTO]
}

/// `details` is only encoded when present: an omitted key, not an explicit `null`, is how the
/// backend's `AddRewardItemUseCase` distinguishes "no description" (SPEC-015 §5.3) — unlike
/// Missions' `note`, there's no existing value to clear here, so no "always send" override is needed.
nonisolated private struct AddRewardItemRequestDTO: Encodable {
    let title: String
    let details: String?
}

nonisolated private struct ProblemDetailsDTO: Decodable {
    let code: String?
    let fieldErrors: [String: [String]]?
}

nonisolated struct HTTPRewardRepository: RewardRepository {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func rewardItems(accessToken: String) async throws -> RewardCatalog {
        let data = try await send(path: "reward-items", method: "GET", accessToken: accessToken)
        let dto = try decode(RewardCatalogDTO.self, from: data)
        return RewardCatalog(predefined: dto.predefined.map(Self.toRewardItem), custom: dto.custom.map(Self.toRewardItem))
    }

    /// Never retried here: with no id yet, an ambiguous failure cannot be reconciled by a `GET`
    /// before the caller reloads the catalog, so it's reported as uncertain rather than a plain
    /// network error (BA-07, SPEC-015 §5.4/CA-07).
    func addRewardItem(_ command: AddRewardItemCommand, accessToken: String) async throws -> RewardItem {
        let body = AddRewardItemRequestDTO(title: command.title, details: command.details)
        do {
            let data = try await send(path: "reward-items", method: "POST", accessToken: accessToken, json: body)
            return Self.toRewardItem(try decode(RewardItemDTO.self, from: data))
        } catch RewardItemError.network, RewardItemError.unavailable {
            throw RewardItemError.uncertainOutcome
        } catch is DecodingError {
            throw RewardItemError.uncertainOutcome
        }
    }

    private static func toRewardItem(_ dto: RewardItemDTO) -> RewardItem {
        RewardItem(id: dto.id, title: dto.title, details: dto.details, source: dto.source, createdAt: dto.createdAt)
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
            throw RewardItemError.unavailable
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
                throw RewardItemError.unavailable
            }
            guard (200 ... 299).contains(response.statusCode) else {
                throw Self.error(for: response.statusCode, data: data)
            }
            return data
        } catch let error as RewardItemError {
            throw error
        } catch is URLError {
            throw RewardItemError.network
        } catch {
            throw RewardItemError.unavailable
        }
    }

    private static func error(for statusCode: Int, data: Data) -> RewardItemError {
        let problem = try? decoder.decode(ProblemDetailsDTO.self, from: data)
        switch (statusCode, problem?.code) {
        case (403, "INSUFFICIENT_PERMISSIONS"):
            return .insufficientPermissions
        case (422, "VALIDATION_FAILED"):
            return .validationFailed(problem?.fieldErrors ?? [:])
        case (422, "REWARD_TITLE_ALREADY_EXISTS"):
            return .titleAlreadyExists
        case (503, _):
            return .unavailable
        case (500..., _):
            return .unavailable
        default:
            return .unavailable
        }
    }
}

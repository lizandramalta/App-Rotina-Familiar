import Foundation

nonisolated private struct KidsReviewQueueResponseDTO: Decodable {
    let items: [KidsSignalSummaryDTO]
    let nextCursor: String?
}

nonisolated private struct KidsSignalSummaryDTO: Decodable {
    let signalId: UUID
    let task: KidsSignalTaskDTO
    let signaledBy: KidsSignaledByDTO
    let signaledAt: Date
    let hasPhoto: Bool
}

nonisolated private struct KidsSignalTaskDTO: Decodable {
    let id: UUID
    let title: String
}

nonisolated private struct KidsSignaledByDTO: Decodable {
    let id: UUID
    let name: String
}

nonisolated private struct ProblemDetailsDTO: Decodable {
    let code: String?
}

nonisolated struct HTTPKidsSignalRepository: KidsSignalRepository {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func getReviewQueue(accessToken: String, cursor: String?) async throws -> KidsReviewQueuePage {
        var url = baseURL.appending(path: "kids/signals")
        if let cursor {
            url = url.appending(queryItems: [URLQueryItem(name: "cursor", value: cursor)])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data = try await send(request)
        let response: KidsReviewQueueResponseDTO
        do {
            response = try Self.decoder.decode(KidsReviewQueueResponseDTO.self, from: data)
        } catch {
            throw KidsSignalError.unavailable
        }
        return KidsReviewQueuePage(
            items: response.items.map {
                KidsSignalSummary(
                    id: $0.signalId,
                    taskID: $0.task.id,
                    taskTitle: $0.task.title,
                    signaledByID: $0.signaledBy.id,
                    childName: $0.signaledBy.name,
                    signaledAt: $0.signaledAt,
                    hasPhoto: $0.hasPhoto
                )
            },
            nextCursor: response.nextCursor
        )
    }

    private func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw KidsSignalError.unavailable
            }
            guard (200 ... 299).contains(response.statusCode) else {
                throw Self.error(for: response.statusCode, data: data)
            }
            return data
        } catch let error as KidsSignalError {
            throw error
        } catch is URLError {
            throw KidsSignalError.network
        } catch {
            throw KidsSignalError.unavailable
        }
    }

    private static func error(for statusCode: Int, data: Data) -> KidsSignalError {
        let problem = try? JSONDecoder().decode(ProblemDetailsDTO.self, from: data)
        switch (statusCode, problem?.code) {
        case (403, "ACTION_NOT_ALLOWED"):
            return .actionNotAllowed
        case (404, _):
            return .notFound
        case (500..., _):
            return .unavailable
        default:
            return .rejected
        }
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
}

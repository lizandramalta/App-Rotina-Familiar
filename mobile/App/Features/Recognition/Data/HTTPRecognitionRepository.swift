import Foundation

nonisolated struct WeeklyRecognitionDTO: Decodable, Sendable {
    struct Period: Decodable, Sendable {
        let startsAt: Date
        let endsAt: Date
    }

    let id: UUID
    let period: Period
    let timeZoneId: String
    let isTransition: Bool
    let points: Int
    let completedTasks: Int
    let isTie: Bool
    let openedAt: Date?

    var model: WeeklyRecognition {
        WeeklyRecognition(
            id: id,
            startsAt: period.startsAt,
            endsAt: period.endsAt,
            timeZoneID: timeZoneId,
            isTransition: isTransition,
            points: points,
            completedTasks: completedTasks,
            isTie: isTie,
            openedAt: openedAt
        )
    }
}

nonisolated private struct WeeklyRecognitionListDTO: Decodable {
    let items: [WeeklyRecognitionDTO]
}

/// `/v1/me/weekly-recognitions` (SPEC-020 §5). Results are owner-scoped by the server; `404` covers
/// both a missing and a foreign `recognitionId`, so nothing about another member leaks (CA-05).
nonisolated struct HTTPRecognitionRepository: RecognitionRepository {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func listOwn(accessToken: String) async throws -> [WeeklyRecognition] {
        let data = try await send(path: "me/weekly-recognitions", method: "GET", accessToken: accessToken)
        return try decode(WeeklyRecognitionListDTO.self, from: data).items.map(\.model)
    }

    func recognition(id: UUID, accessToken: String) async throws -> WeeklyRecognition {
        let data = try await send(
            path: "me/weekly-recognitions/\(id.uuidString.lowercased())",
            method: "GET",
            accessToken: accessToken
        )
        return try decode(WeeklyRecognitionDTO.self, from: data).model
    }

    func recordOpening(id: UUID, accessToken: String) async throws -> WeeklyRecognition {
        let data = try await send(
            path: "me/weekly-recognitions/\(id.uuidString.lowercased())/opening",
            method: "POST",
            accessToken: accessToken
        )
        return try decode(WeeklyRecognitionDTO.self, from: data).model
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
            throw RecognitionError.unavailable
        }
    }

    private func send(path: String, method: String, accessToken: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw RecognitionError.unavailable
            }
            switch response.statusCode {
            case 200 ... 299: return data
            case 401: throw RecognitionError.sessionExpired
            case 404: throw RecognitionError.notFound
            default: throw RecognitionError.unavailable
            }
        } catch let error as RecognitionError {
            throw error
        } catch is URLError {
            throw RecognitionError.network
        } catch {
            throw RecognitionError.unavailable
        }
    }
}

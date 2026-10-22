import Foundation

nonisolated private struct NextTierDTO: Decodable {
    let code: BadgeTier
    let requiredMissionCount: Int
    let remaining: Int

    var model: NextBadgeTier {
        NextBadgeTier(code: code, requiredMissionCount: requiredMissionCount, remaining: remaining)
    }
}

nonisolated private struct OwnProfileDTO: Decodable {
    let memberId: UUID
    let name: String
    let familyName: String
    let nickname: String?
    let photoMediaId: String?
    let totalParticipations: Int
    let nextTier: NextTierDTO?

    var model: OwnProfile {
        OwnProfile(
            memberID: memberId,
            name: name,
            familyName: familyName,
            nickname: nickname,
            photoMediaID: photoMediaId,
            totalParticipations: totalParticipations,
            nextTier: nextTier?.model
        )
    }
}

nonisolated private struct BadgesOverviewDTO: Decodable {
    struct Award: Decodable {
        let awardId: UUID
        let tier: BadgeTier
        let requiredMissionCount: Int
        let awardedAt: Date
    }

    let totalParticipations: Int
    let nextTier: NextTierDTO?
    let awards: [Award]
}

nonisolated private struct BadgeDetailDTO: Decodable {
    struct Mission: Decodable {
        let missionId: UUID
        let title: String
        /// The contract allows `null`; the award date then stands in, since the mission closed no later than it.
        let completedAt: Date?
    }

    let awardId: UUID
    let tier: BadgeTier
    let awardedAt: Date
    let contributingMissions: [Mission]
}

nonisolated private struct MediaResponseDTO: Decodable {
    let mediaId: String
    let state: String
}

nonisolated private struct ProblemDetailsDTO: Decodable {
    let code: String?
    let fieldErrors: [String: [String]]?
}

/// Only the fields the user changed go on the wire: omitted preserves, explicit `null` removes (SPEC-006 §5.2).
nonisolated private struct UpdateOwnProfileRequestDTO: Encodable {
    let command: UpdateOwnProfileCommand

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name = command.name {
            try container.encode(name, forKey: .name)
        }
        try Self.encode(command.nickname, forKey: .nickname, in: &container)
        try Self.encode(command.photoMediaID, forKey: .photoMediaId, in: &container)
    }

    private static func encode(
        _ update: OptionalFieldUpdate<String>,
        forKey key: CodingKeys,
        in container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        switch update {
        case .unchanged: break
        case .set(let value): try container.encode(value, forKey: key)
        case .clear: try container.encodeNil(forKey: key)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name, nickname, photoMediaId
    }
}

nonisolated struct HTTPProfileRepository: ProfileRepository {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func getOwnProfile(accessToken: String) async throws -> OwnProfile {
        let data = try await send(path: "me/profile", method: "GET", accessToken: accessToken)
        return try decode(OwnProfileDTO.self, from: data).model
    }

    func updateOwnProfile(_ command: UpdateOwnProfileCommand, accessToken: String) async throws -> OwnProfile {
        let body: Data
        do {
            body = try JSONEncoder().encode(UpdateOwnProfileRequestDTO(command: command))
        } catch {
            throw ProfileError.unavailable
        }
        let data = try await send(
            path: "me/profile",
            method: "PATCH",
            accessToken: accessToken,
            contentType: "application/json",
            body: body
        )
        return try decode(OwnProfileDTO.self, from: data).model
    }

    func getOwnBadges(accessToken: String) async throws -> BadgesOverview {
        let data = try await send(path: "me/badges", method: "GET", accessToken: accessToken)
        let dto = try decode(BadgesOverviewDTO.self, from: data)
        return BadgesOverview(
            totalParticipations: dto.totalParticipations,
            nextTier: dto.nextTier?.model,
            awards: dto.awards.map {
                BadgeAward(
                    awardID: $0.awardId,
                    tier: $0.tier,
                    requiredMissionCount: $0.requiredMissionCount,
                    awardedAt: $0.awardedAt
                )
            }
        )
    }

    func getBadgeDetail(awardID: UUID, accessToken: String) async throws -> BadgeDetail {
        let data = try await send(
            path: "me/badges/\(awardID.uuidString.lowercased())",
            method: "GET",
            accessToken: accessToken
        )
        let dto = try decode(BadgeDetailDTO.self, from: data)
        return BadgeDetail(
            awardID: dto.awardId,
            tier: dto.tier,
            awardedAt: dto.awardedAt,
            contributingMissions: dto.contributingMissions.map {
                ContributingMission(
                    missionID: $0.missionId,
                    title: $0.title,
                    completedAt: $0.completedAt ?? dto.awardedAt
                )
            }
        )
    }

    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        let data = try await send(
            path: "media",
            method: "POST",
            accessToken: accessToken,
            contentType: "multipart/form-data; boundary=\(boundary)",
            body: HTTPFamilyRepository.multipartBody(boundary: boundary, purpose: "profilePhoto", jpeg: jpeg)
        )
        let media = try decode(MediaResponseDTO.self, from: data)
        // A photo still processing cannot be linked yet; the caller treats it as an upload failure.
        guard media.state == "READY" else {
            throw ProfileError.unavailable
        }
        return media.mediaId
    }

    func getMediaContent(mediaID: String, accessToken: String) async throws -> Data {
        let data = try await send(
            path: "media/\(mediaID)/content",
            method: "GET",
            accessToken: accessToken,
            accept: "image/jpeg"
        )
        guard !data.isEmpty else {
            throw ProfileError.unavailable
        }
        return data
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
            throw ProfileError.unavailable
        }
    }

    private func send(
        path: String,
        method: String,
        accessToken: String,
        accept: String = "application/json",
        contentType: String? = nil,
        body: Data? = nil
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw ProfileError.unavailable
            }
            guard (200 ... 299).contains(response.statusCode) else {
                throw Self.error(for: response.statusCode, data: data)
            }
            return data
        } catch let error as ProfileError {
            throw error
        } catch is URLError {
            throw ProfileError.network
        } catch {
            throw ProfileError.unavailable
        }
    }

    private static func error(for statusCode: Int, data: Data) -> ProfileError {
        let problem = try? decoder.decode(ProblemDetailsDTO.self, from: data)
        switch (statusCode, problem?.code) {
        case (401, _):
            return .unauthorized
        case (403, _):
            return .actionNotAllowed
        case (404, _):
            return .notFound
        case (413, _):
            return .mediaTooLarge
        case (415, _):
            return .mediaFormatUnsupported
        case (422, "PHOTO_MEDIA_NOT_READY"), (422, "PHOTO_MEDIA_NOT_OWNED"), (422, "PHOTO_MEDIA_PURPOSE_MISMATCH"):
            return .validationFailed(["photoMediaId": [problem?.code ?? ""]])
        case (422, _):
            return .validationFailed(problem?.fieldErrors ?? [:])
        case (429, _):
            return .rateLimited
        case (500..., _):
            return .unavailable
        default:
            return .rejected
        }
    }
}

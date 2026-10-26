import Foundation

nonisolated private struct CreateFamilyRequestDTO: Encodable {
    let creationGrant: String
    let creatorName: String
    let creatorNickname: String?
    let name: String
    let timeZoneId: String

    // The contract rejects unknown fields; an absent nickname is sent as an explicit null.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(creationGrant, forKey: .creationGrant)
        try container.encode(creatorName, forKey: .creatorName)
        try container.encode(creatorNickname, forKey: .creatorNickname)
        try container.encode(name, forKey: .name)
        try container.encode(timeZoneId, forKey: .timeZoneId)
    }

    private enum CodingKeys: String, CodingKey {
        case creationGrant, creatorName, creatorNickname, name, timeZoneId
    }
}

nonisolated private struct CreateFamilyResponseDTO: Decodable {
    struct Family: Decodable {
        let id: UUID
        let name: String
        let timeZoneId: String
    }

    struct Session: Decodable {
        let sessionId: UUID
        let memberId: UUID
        let familyId: UUID
        let role: MemberRole
        let isFamilyCreator: Bool
        let accessToken: String
        let accessTokenExpiresAt: Date
        let refreshToken: String
    }

    let family: Family
    let session: Session
}

nonisolated private struct MediaResponseDTO: Decodable {
    let mediaId: String
}

nonisolated private struct ProfilePhotoRequestDTO: Encodable {
    let photoMediaId: String?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(photoMediaId, forKey: .photoMediaId)
    }

    private enum CodingKeys: String, CodingKey {
        case photoMediaId
    }
}

nonisolated private struct CreateMemberRequestDTO: Encodable {
    let name: String
    let role: MemberRole
}

nonisolated private struct CreateMemberResponseDTO: Decodable {
    let id: UUID
    let name: String
    let role: MemberRole
}

nonisolated private struct EmptyRequestDTO: Encodable {}

nonisolated private struct InviteResponseDTO: Decodable {
    let inviteId: UUID
    let link: String
    let password: String
}

nonisolated private struct FamilyMemberDTO: Decodable {
    let id: UUID
    let name: String
    let role: MemberRole
    let isFamilyCreator: Bool
}

nonisolated private struct ListFamilyMembersResponseDTO: Decodable {
    let items: [FamilyMemberDTO]
    let nextCursor: String?
}

nonisolated private struct MemberDetailDTO: Decodable {
    struct Capabilities: Decodable {
        let manageMembers: Bool
    }

    let id: UUID
    let name: String
    let role: MemberRole
    let isFamilyCreator: Bool
    let createdAt: String
    let capabilities: Capabilities
}

nonisolated private struct FamilyProfileDTO: Decodable {
    let id: UUID
    let name: String
    let timeZoneId: String
}

nonisolated private struct UpdateFamilyRequestDTO: Encodable {
    let name: String
}

nonisolated private struct CycleLimitsDTO: Decodable {
    let startsAt: String
    let endsAt: String
    let timeZoneId: String
    let isTransition: Bool
}

nonisolated private struct ScheduledTimeZoneChangeDTO: Decodable {
    let timeZoneId: String
    let effectiveAt: String
}

nonisolated private struct FamilySettingsResponseDTO: Decodable {
    let timeZoneId: String
    let scheduledTimeZoneChange: ScheduledTimeZoneChangeDTO?
    let limits: CycleLimitsDTO
}

nonisolated private struct TimeZoneChangeRequestDTO: Encodable {
    let timeZoneId: String
    let application: TimeZoneApplication
}

nonisolated private struct TimeZoneChangePreviewResponseDTO: Decodable {
    let proposedTimeZoneId: String
    let application: TimeZoneApplication
    let effectiveAt: String
    let effectiveLimits: CycleLimitsDTO
    let isTransition: Bool
}

nonisolated private struct ProblemDetailsDTO: Decodable {
    let code: String?
    let fieldErrors: [String: [String]]?
}

nonisolated struct HTTPFamilyRepository: FamilyRepository {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Never retried here: the `creationGrant` is single-use, so an unconfirmed outcome is reported as uncertain.
    func createFamily(_ command: CreateFamilyCommand, installationProof: String) async throws -> CreatedFamily {
        let body = CreateFamilyRequestDTO(
            creationGrant: command.creationGrant,
            creatorName: command.creatorName,
            creatorNickname: command.creatorNickname,
            name: command.familyName,
            timeZoneId: command.timeZoneID
        )

        do {
            let data = try await send(
                path: "families",
                method: "POST",
                headers: ["X-Installation-Proof": installationProof],
                json: body
            )
            let response = try Self.decoder.decode(CreateFamilyResponseDTO.self, from: data)
            return CreatedFamily(
                familyID: response.family.id,
                name: response.family.name,
                timeZoneID: response.family.timeZoneId,
                session: AuthenticatedSession(
                    sessionID: response.session.sessionId,
                    profile: ActiveFamilySession(
                        memberID: response.session.memberId,
                        familyID: response.session.familyId,
                        role: response.session.role,
                        isFamilyCreator: response.session.isFamilyCreator
                    ),
                    credentials: SessionCredentials(
                        token: SessionToken(
                            accessToken: response.session.accessToken,
                            expiresAt: response.session.accessTokenExpiresAt
                        ),
                        refreshToken: response.session.refreshToken
                    )
                )
            )
        } catch FamilyError.network, FamilyError.unavailable {
            throw FamilyError.uncertainOutcome
        } catch is DecodingError {
            throw FamilyError.uncertainOutcome
        }
    }

    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        let data = try await send(
            path: "media",
            method: "POST",
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Content-Type": "multipart/form-data; boundary=\(boundary)",
            ],
            rawBody: Self.multipartBody(boundary: boundary, purpose: "profilePhoto", jpeg: jpeg)
        )
        return try decode(MediaResponseDTO.self, from: data).mediaId
    }

    func setProfilePhoto(mediaID: String, accessToken: String) async throws {
        _ = try await send(
            path: "me/profile",
            method: "PATCH",
            headers: ["Authorization": "Bearer \(accessToken)"],
            json: ProfilePhotoRequestDTO(photoMediaId: mediaID)
        )
    }

    func createMember(name: String, role: MemberRole, accessToken: String) async throws -> CreatedMember {
        let data = try await send(
            path: "family/members",
            method: "POST",
            headers: ["Authorization": "Bearer \(accessToken)"],
            json: CreateMemberRequestDTO(name: name, role: role)
        )
        let response = try decode(CreateMemberResponseDTO.self, from: data)
        return CreatedMember(id: response.id, name: response.name, role: response.role)
    }

    func issueInvite(memberID: UUID, accessToken: String) async throws -> MemberInvite {
        // Never retried: the password cannot be recovered, so a lost response is reported as uncertain (SPEC-004 CA-07).
        do {
            let data = try await send(
                path: "family/members/\(memberID.uuidString.lowercased())/invites",
                method: "POST",
                headers: ["Authorization": "Bearer \(accessToken)"],
                json: EmptyRequestDTO()
            )
            let response = try Self.decoder.decode(InviteResponseDTO.self, from: data)
            return MemberInvite(inviteID: response.inviteId, link: response.link, password: response.password)
        } catch FamilyError.network, FamilyError.unavailable {
            throw FamilyError.uncertainOutcome
        } catch is DecodingError {
            throw FamilyError.uncertainOutcome
        }
    }

    func listMembers(accessToken: String, cursor: String?) async throws -> FamilyMemberPage {
        var path = "family/members"
        if let cursor {
            path += "?cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        let data = try await send(
            path: path,
            method: "GET",
            headers: ["Authorization": "Bearer \(accessToken)"],
            rawBody: Data()
        )
        let response = try decode(ListFamilyMembersResponseDTO.self, from: data)
        return FamilyMemberPage(
            items: response.items.map {
                FamilyMember(id: $0.id, name: $0.name, role: $0.role, isFamilyCreator: $0.isFamilyCreator)
            },
            nextCursor: response.nextCursor
        )
    }

    func getMemberDetail(memberID: UUID, accessToken: String) async throws -> FamilyMemberDetail {
        let data = try await send(
            path: "family/members/\(memberID.uuidString.lowercased())",
            method: "GET",
            headers: ["Authorization": "Bearer \(accessToken)"],
            rawBody: Data()
        )
        let response = try decode(MemberDetailDTO.self, from: data)
        return FamilyMemberDetail(
            id: response.id,
            name: response.name,
            role: response.role,
            isFamilyCreator: response.isFamilyCreator,
            createdAt: response.createdAt,
            capabilities: MemberCapabilities(manageMembers: response.capabilities.manageMembers)
        )
    }

    func getFamily(accessToken: String) async throws -> FamilyProfile {
        let data = try await send(
            path: "family",
            method: "GET",
            headers: ["Authorization": "Bearer \(accessToken)"],
            rawBody: Data()
        )
        let response = try decode(FamilyProfileDTO.self, from: data)
        return FamilyProfile(id: response.id, name: response.name, timeZoneID: response.timeZoneId)
    }

    func updateFamilyName(_ name: String, accessToken: String) async throws -> FamilyProfile {
        let data = try await send(
            path: "family",
            method: "PATCH",
            headers: ["Authorization": "Bearer \(accessToken)"],
            json: UpdateFamilyRequestDTO(name: name)
        )
        let response = try decode(FamilyProfileDTO.self, from: data)
        return FamilyProfile(id: response.id, name: response.name, timeZoneID: response.timeZoneId)
    }

    func getFamilySettings(accessToken: String) async throws -> FamilySettings {
        let data = try await send(
            path: "family/settings",
            method: "GET",
            headers: ["Authorization": "Bearer \(accessToken)"],
            rawBody: Data()
        )
        let response = try decode(FamilySettingsResponseDTO.self, from: data)
        return FamilySettings(
            timeZoneID: response.timeZoneId,
            scheduledTimeZoneChange: response.scheduledTimeZoneChange.map {
                ScheduledTimeZoneChange(timeZoneID: $0.timeZoneId, effectiveAt: $0.effectiveAt)
            },
            limits: CycleLimits(
                startsAt: response.limits.startsAt,
                endsAt: response.limits.endsAt,
                timeZoneID: response.limits.timeZoneId,
                isTransition: response.limits.isTransition
            )
        )
    }

    func previewFamilyTimeZoneChange(
        timeZoneID: String,
        application: TimeZoneApplication,
        accessToken: String
    ) async throws -> TimeZoneChangePreview {
        let data = try await send(
            path: "family/time-zone-changes/preview",
            method: "POST",
            headers: ["Authorization": "Bearer \(accessToken)"],
            json: TimeZoneChangeRequestDTO(timeZoneId: timeZoneID, application: application)
        )
        let response = try decode(TimeZoneChangePreviewResponseDTO.self, from: data)
        return TimeZoneChangePreview(
            proposedTimeZoneID: response.proposedTimeZoneId,
            application: response.application,
            effectiveAt: response.effectiveAt,
            effectiveLimits: CycleLimits(
                startsAt: response.effectiveLimits.startsAt,
                endsAt: response.effectiveLimits.endsAt,
                timeZoneID: response.effectiveLimits.timeZoneId,
                isTransition: response.effectiveLimits.isTransition
            ),
            isTransition: response.isTransition
        )
    }

    func changeFamilyTimeZone(
        timeZoneID: String,
        application: TimeZoneApplication,
        accessToken: String
    ) async throws -> FamilySettings {
        let data = try await send(
            path: "family/time-zone-changes",
            method: "POST",
            headers: ["Authorization": "Bearer \(accessToken)"],
            json: TimeZoneChangeRequestDTO(timeZoneId: timeZoneID, application: application)
        )
        let response = try decode(FamilySettingsResponseDTO.self, from: data)
        return FamilySettings(
            timeZoneID: response.timeZoneId,
            scheduledTimeZoneChange: response.scheduledTimeZoneChange.map {
                ScheduledTimeZoneChange(timeZoneID: $0.timeZoneId, effectiveAt: $0.effectiveAt)
            },
            limits: CycleLimits(
                startsAt: response.limits.startsAt,
                endsAt: response.limits.endsAt,
                timeZoneID: response.limits.timeZoneId,
                isTransition: response.limits.isTransition
            )
        )
    }

    static func multipartBody(boundary: String, purpose: String, jpeg: Data) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n\(purpose)\r\n".utf8))
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"profile.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpeg)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
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
            throw FamilyError.unavailable
        }
    }

    private func send(
        path: String,
        method: String,
        headers: [String: String],
        json body: some Encodable
    ) async throws -> Data {
        var allHeaders = headers
        allHeaders["Content-Type"] = "application/json"
        return try await send(
            path: path,
            method: method,
            headers: allHeaders,
            rawBody: try JSONEncoder().encode(body)
        )
    }

    private func send(
        path: String,
        method: String,
        headers: [String: String],
        rawBody: Data
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = rawBody

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw FamilyError.unavailable
            }
            guard (200 ... 299).contains(response.statusCode) else {
                throw Self.error(for: response.statusCode, data: data)
            }
            return data
        } catch let error as FamilyError {
            throw error
        } catch is URLError {
            throw FamilyError.network
        } catch {
            throw FamilyError.unavailable
        }
    }

    private static func error(for statusCode: Int, data: Data) -> FamilyError {
        let problem = try? decoder.decode(ProblemDetailsDTO.self, from: data)
        switch (statusCode, problem?.code) {
        case (401, "CREATION_GRANT_INVALID"):
            return .creationGrantInvalid
        case (403, "ACTION_NOT_ALLOWED"):
            return .actionNotAllowed
        case (422, "VALIDATION_FAILED"):
            if let timeZoneErrors = problem?.fieldErrors?["timeZoneId"], timeZoneErrors.contains("TIME_ZONE_UNCHANGED") {
                return .timeZoneUnchanged
            }
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

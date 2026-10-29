import Foundation

nonisolated private struct InspectInviteRequestDTO: Encodable {
    let token: String
}

nonisolated private struct InspectInviteResponseDTO: Decodable {
    let status: String
}

nonisolated private struct JoinInviteRequestDTO: Encodable {
    let token: String
    let password: String
    let attemptId: UUID
    let attemptSecret: String
    let installationProof: String
    let switchConfirmed: Bool
}

nonisolated private struct RecoverInviteRequestDTO: Encodable {
    let attemptId: UUID
    let attemptSecret: String
    let installationProof: String
}

nonisolated private struct InviteSessionResponseDTO: Decodable {
    let sessionId: UUID
    let memberId: UUID
    let familyId: UUID
    let role: MemberRole
    let isFamilyCreator: Bool
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String

    var session: AuthenticatedSession {
        AuthenticatedSession(
            sessionID: sessionId,
            profile: ActiveFamilySession(
                memberID: memberId,
                familyID: familyId,
                role: role,
                isFamilyCreator: isFamilyCreator
            ),
            credentials: SessionCredentials(
                token: SessionToken(accessToken: accessToken, expiresAt: accessTokenExpiresAt),
                refreshToken: refreshToken
            )
        )
    }
}

nonisolated private struct InviteProblemDTO: Decodable {
    let code: String?
}

nonisolated struct HTTPInviteJoinRepository: InviteJoinRepository {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func inspect(token: String) async throws {
        let data = try await post(path: "access/invites/inspect", body: InspectInviteRequestDTO(token: token))
        guard (try? decoder.decode(InspectInviteResponseDTO.self, from: data))?.status == "available" else {
            throw InviteJoinError.invalidResponse
        }
    }

    func join(
        token: String,
        password: String,
        attempt: InviteJoinAttempt,
        switchConfirmed: Bool,
        previousAccessToken: String?
    ) async throws -> AuthenticatedSession {
        let data = try await post(
            path: "access/invite-joins",
            body: JoinInviteRequestDTO(
                token: token,
                password: password,
                attemptId: attempt.id,
                attemptSecret: attempt.secret,
                installationProof: attempt.installationProof,
                switchConfirmed: switchConfirmed
            ),
            accessToken: previousAccessToken
        )
        guard let result = try? decoder.decode(InviteSessionResponseDTO.self, from: data) else {
            throw InviteJoinError.resultUncertain
        }
        return result.session
    }

    func recover(attempt: InviteJoinAttempt) async throws -> AuthenticatedSession {
        let data = try await post(
            path: "access/invite-joins/recover",
            body: RecoverInviteRequestDTO(
                attemptId: attempt.id,
                attemptSecret: attempt.secret,
                installationProof: attempt.installationProof
            )
        )
        guard let result = try? decoder.decode(InviteSessionResponseDTO.self, from: data) else {
            throw InviteJoinError.invalidResponse
        }
        return result.session
    }

    private func post<Body: Encodable>(path: String, body: Body, accessToken: String? = nil) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw InviteJoinError.network
            }
            guard (200 ... 299).contains(response.statusCode) else {
                throw mapError(status: response.statusCode, data: data)
            }
            return data
        } catch let error as InviteJoinError {
            throw error
        } catch is URLError {
            throw InviteJoinError.network
        } catch {
            throw InviteJoinError.network
        }
    }

    private func mapError(status: Int, data: Data) -> InviteJoinError {
        let code = (try? decoder.decode(InviteProblemDTO.self, from: data))?.code
        return switch (status, code) {
        case (404, "INVITE_UNAVAILABLE"): .inviteUnavailable
        case (404, "JOIN_RECOVERY_UNAVAILABLE"): .recoveryUnavailable
        case (422, "INVITE_PASSWORD_INVALID"): .invalidPassword
        case (429, "RATE_LIMITED"): .rateLimited
        case (409, "ACCESS_SWITCH_CONFIRMATION_REQUIRED"): .switchConfirmationRequired
        case (401, "SESSION_INVALID"): .previousSessionInvalid
        case (503, "JOIN_RESULT_UNCERTAIN"): .resultUncertain
        case (503, "DEPENDENCY_UNAVAILABLE"): .dependencyUnavailable
        default: .invalidResponse
        }
    }
}

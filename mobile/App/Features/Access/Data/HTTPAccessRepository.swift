import Foundation

private struct AppleSignInRequestDTO: Encodable {
    let identityToken: String
    let authorizationCode: String
    let rawNonce: String
}

private struct RefreshSessionRequestDTO: Encodable {
    let refreshToken: String
}

private struct SessionResponseDTO: Decodable {
    let sessionId: UUID
    let memberId: UUID
    let familyId: UUID
    let role: MemberRole
    let isFamilyCreator: Bool
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String
}

private struct CreationGrantResponseDTO: Decodable {
    let creationGrant: String
    let expiresAt: Date
}

private struct CurrentSessionResponseDTO: Decodable {
    let memberId: UUID
    let familyId: UUID
    let role: MemberRole
    let isFamilyCreator: Bool
}

private struct RefreshSessionResponseDTO: Decodable {
    let accessToken: String
    let accessTokenExpiresAt: Date
}

private struct ProblemDetailsDTO: Decodable {
    let code: String?
}

struct HTTPAccessRepository: AccessRepository {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func signIn(
        proof: AppleAuthorizationProof,
        installationProof: String
    ) async throws -> AppleSignInOutcome {
        let data = try await request(
            path: "access/apple",
            method: "POST",
            headers: ["X-Installation-Proof": installationProof],
            body: AppleSignInRequestDTO(
                identityToken: proof.identityToken,
                authorizationCode: proof.authorizationCode,
                rawNonce: proof.rawNonce
            )
        )

        if let session = try? decoder.decode(SessionResponseDTO.self, from: data) {
            return .session(
                AuthenticatedSession(
                    sessionID: session.sessionId,
                    profile: ActiveFamilySession(
                        memberID: session.memberId,
                        familyID: session.familyId,
                        role: session.role,
                        isFamilyCreator: session.isFamilyCreator
                    ),
                    credentials: SessionCredentials(
                        token: SessionToken(
                            accessToken: session.accessToken,
                            expiresAt: session.accessTokenExpiresAt
                        ),
                        refreshToken: session.refreshToken
                    )
                )
            )
        }

        if let grant = try? decoder.decode(CreationGrantResponseDTO.self, from: data) {
            return .creationGrant(CreationGrant(value: grant.creationGrant, expiresAt: grant.expiresAt))
        }

        throw AccessError.invalidResponse
    }

    func currentSession(accessToken: String) async throws -> ActiveFamilySession {
        let data = try await request(
            path: "me/session",
            method: "GET",
            headers: ["Authorization": "Bearer \(accessToken)"],
            body: Optional<String>.none
        )
        let response = try decoder.decode(CurrentSessionResponseDTO.self, from: data)
        return ActiveFamilySession(
            memberID: response.memberId,
            familyID: response.familyId,
            role: response.role,
            isFamilyCreator: response.isFamilyCreator
        )
    }

    func refresh(
        refreshToken: String,
        installationProof: String
    ) async throws -> SessionToken {
        let data = try await request(
            path: "access/refresh",
            method: "POST",
            headers: ["X-Installation-Proof": installationProof],
            body: RefreshSessionRequestDTO(refreshToken: refreshToken)
        )
        let response = try decoder.decode(RefreshSessionResponseDTO.self, from: data)
        return SessionToken(accessToken: response.accessToken, expiresAt: response.accessTokenExpiresAt)
    }

    func revokeSession(accessToken: String) async throws {
        _ = try await request(
            path: "me/session",
            method: "DELETE",
            headers: ["Authorization": "Bearer \(accessToken)"],
            body: Optional<String>.none
        )
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func request<Body: Encodable>(
        path: String,
        method: String,
        headers: [String: String],
        body: Body?
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw AccessError.invalidResponse
            }
            guard (200 ... 299).contains(response.statusCode) else {
                throw error(for: response.statusCode, data: data)
            }
            return data
        } catch let error as AccessError {
            throw error
        } catch is URLError {
            throw AccessError.network
        } catch {
            throw AccessError.unavailable
        }
    }

    private func error(for statusCode: Int, data: Data) -> AccessError {
        let code = (try? decoder.decode(ProblemDetailsDTO.self, from: data))?.code
        switch (statusCode, code) {
        case (401, "APPLE_PROOF_INVALID"):
            return .appleProofInvalid
        case (401, "SESSION_REVOKED"):
            return .sessionRevoked
        case (401, "SESSION_EXPIRED"):
            return .sessionExpired
        case (429, "RATE_LIMIT_EXCEEDED"):
            return .rateLimited
        default:
            return .unavailable
        }
    }
}

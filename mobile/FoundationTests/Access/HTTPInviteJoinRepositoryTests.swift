import Foundation
@testable import FamilyRoutine
import Testing

struct HTTPInviteJoinRepositoryTests {
    private let attempt = InviteJoinAttempt(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        secret: "opaque-attempt-secret-123456789",
        installationProof: "installation-proof-123"
    )

    @Test("SPEC-005 CA-01/CA-04 mobile inspection sends only the token and accepts only available")
    func inspectContract() async throws {
        let stub = InviteHTTPStub(status: 200, json: #"{"status":"available"}"#)

        try await stub.repository.inspect(token: "opaque-token")

        let request = try #require(stub.requests.first)
        #expect(request.url.path == "/v1/access/invites/inspect")
        #expect(request.headers["Authorization"] == nil)
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(Set(body.keys) == ["token"])
        #expect(body["token"] as? String == "opaque-token")
    }

    @Test("SPEC-005 CA-06/CA-09 mobile join sends the confirmed switch proof and trusts the server role")
    func joinContract() async throws {
        let stub = InviteHTTPStub(status: 201, json: sessionJSON(role: "kids"))

        let session = try await stub.repository.join(
            token: "opaque-token",
            password: "ABC234",
            attempt: attempt,
            switchConfirmed: true,
            previousAccessToken: "old-access"
        )

        let request = try #require(stub.requests.first)
        #expect(request.url.path == "/v1/access/invite-joins")
        #expect(request.headers["Authorization"] == "Bearer old-access")
        #expect(request.headers["Cache-Control"] == "no-store")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(Set(body.keys) == ["token", "password", "attemptId", "attemptSecret", "installationProof", "switchConfirmed"])
        #expect(body["attemptId"] as? String == attempt.id.uuidString)
        #expect(body["attemptSecret"] as? String == attempt.secret)
        #expect(body["installationProof"] as? String == attempt.installationProof)
        #expect(body["switchConfirmed"] as? Bool == true)
        #expect(session.profile.role == .kid)
        #expect(session.credentials.refreshToken == "new-refresh")
    }

    @Test("SPEC-005 CA-08 recovery sends original proofs without password, token or old bearer")
    func recoverContract() async throws {
        let stub = InviteHTTPStub(status: 200, json: sessionJSON(role: "member"))

        let session = try await stub.repository.recover(attempt: attempt)

        let request = try #require(stub.requests.first)
        #expect(request.url.path == "/v1/access/invite-joins/recover")
        #expect(request.headers["Authorization"] == nil)
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(Set(body.keys) == ["attemptId", "attemptSecret", "installationProof"])
        #expect(session.profile.role == .member)
    }

    @Test("SPEC-005 CA-08 maps neutral recovery refusal and uncertain join for reconciliation")
    func mapsRecoveryAndUncertainResponses() async {
        let refused = InviteHTTPStub(status: 404, json: #"{"code":"JOIN_RECOVERY_UNAVAILABLE"}"#)
        await #expect(throws: InviteJoinError.recoveryUnavailable) {
            _ = try await refused.repository.recover(attempt: attempt)
        }

        let uncertain = InviteHTTPStub(status: 503, json: #"{"code":"JOIN_RESULT_UNCERTAIN"}"#)
        await #expect(throws: InviteJoinError.resultUncertain) {
            _ = try await uncertain.repository.join(
                token: "opaque-token",
                password: "ABC234",
                attempt: attempt,
                switchConfirmed: false,
                previousAccessToken: nil
            )
        }

        let malformed = InviteHTTPStub(status: 201, json: "{}")
        await #expect(throws: InviteJoinError.resultUncertain) {
            _ = try await malformed.repository.join(
                token: "opaque-token",
                password: "ABC234",
                attempt: attempt,
                switchConfirmed: false,
                previousAccessToken: nil
            )
        }
    }

    private func sessionJSON(role: String) -> String {
        """
        {"sessionId":"00000000-0000-0000-0000-000000000011",
        "memberId":"00000000-0000-0000-0000-000000000012",
        "familyId":"00000000-0000-0000-0000-000000000013",
        "role":"\(role)","isFamilyCreator":false,
        "accessToken":"new-access","accessTokenExpiresAt":"2026-10-21T18:00:00Z",
        "refreshToken":"new-refresh"}
        """
    }
}

private struct InviteCapturedRequest: Sendable {
    let url: URL
    let headers: [String: String]
    let body: Data
}

private final class InviteHTTPStub: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registry: [String: InviteHTTPStub] = [:]

    private let status: Int
    private let data: Data
    private var captured: [InviteCapturedRequest] = []
    let repository: HTTPInviteJoinRepository

    init(status: Int, json: String) {
        self.status = status
        data = Data(json.utf8)
        let host = "invite-stub-\(UUID().uuidString.lowercased()).test"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InviteURLProtocol.self]
        repository = HTTPInviteJoinRepository(
            baseURL: URL(string: "https://\(host)/v1")!,
            session: URLSession(configuration: configuration)
        )
        Self.lock.withLock { Self.registry[host] = self }
    }

    var requests: [InviteCapturedRequest] {
        Self.lock.withLock { captured }
    }

    static func stub(for host: String?) -> InviteHTTPStub? {
        lock.withLock { host.flatMap { registry[$0] } }
    }

    func respond(to request: URLRequest) -> (HTTPURLResponse, Data) {
        let url = request.url!
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
        Self.lock.withLock {
            captured.append(InviteCapturedRequest(url: url, headers: request.allHTTPHeaderFields ?? [:], body: body))
        }
        return (HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, data)
    }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            result.append(buffer, count: count)
        }
        return result
    }
}

private final class InviteURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = InviteHTTPStub.stub(for: request.url?.host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (response, data) = stub.respond(to: request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

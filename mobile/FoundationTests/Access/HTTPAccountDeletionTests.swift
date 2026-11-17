import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-022 §5.2 — wire contract of `POST /v1/me/account-deletion` and of the Kids deletion route.
struct HTTPAccountDeletionTests {
    @Test("Sends an empty object when there is no Apple proof")
    func emptyBody() async throws {
        let stub = AccountDeletionStubHTTP.make(status: 204)

        try await stub.accessRepository.deleteOwnAccount(appleProof: nil, accessToken: "token-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/me/account-deletion")
        #expect(request.headers["Authorization"] == "Bearer token-1")
        #expect(String(data: request.body, encoding: .utf8) == "{}")
    }

    @Test("Sends the Apple proof with its nonce")
    func appleProofBody() async throws {
        let stub = AccountDeletionStubHTTP.make(status: 204)

        try await stub.accessRepository.deleteOwnAccount(
            appleProof: AppleAuthorizationProof(identityToken: "jwt", authorizationCode: "code", rawNonce: "nonce"),
            accessToken: "token-1"
        )

        let body = try JSONSerialization.jsonObject(with: try #require(stub.requests().first).body) as? [String: Any]
        let apple = body?["apple"] as? [String: String]
        #expect(apple == ["identityToken": "jwt", "authorizationCode": "code", "rawNonce": "nonce"])
    }

    @Test("Maps 422 APPLE_PROOF_REQUIRED and 401 SESSION_REVOKED")
    func errorMapping() async {
        let required = AccountDeletionStubHTTP.make(status: 422, json: #"{"code":"APPLE_PROOF_REQUIRED"}"#)
        await #expect(throws: AccessError.appleProofRequired) {
            try await required.accessRepository.deleteOwnAccount(appleProof: nil, accessToken: "t")
        }
        let revoked = AccountDeletionStubHTTP.make(status: 401, json: #"{"code":"SESSION_REVOKED"}"#)
        await #expect(throws: AccessError.sessionRevoked) {
            try await revoked.accessRepository.deleteOwnAccount(appleProof: nil, accessToken: "t")
        }
    }

    @Test("CA-16 the administrator route posts an empty object for the Kids member")
    func kidsDeletionRoute() async throws {
        let stub = AccountDeletionStubHTTP.make(status: 204)
        let kidsID = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!

        try await stub.familyRepository.deleteKidsAccount(memberID: kidsID, accessToken: "token-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/family/members/00000000-0000-0000-0000-0000000000c3/account-deletion")
        #expect(String(data: request.body, encoding: .utf8) == "{}")
    }
}

private struct AccountDeletionCapturedRequest: Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data
}

private final class AccountDeletionStubHTTP: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registry: [String: AccountDeletionStubHTTP] = [:]

    private let status: Int
    private let data: Data
    private var captured: [AccountDeletionCapturedRequest] = []
    let accessRepository: HTTPAccessRepository
    let familyRepository: HTTPFamilyRepository

    private init(status: Int, data: Data, host: String) {
        self.status = status
        self.data = data
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccountDeletionStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let baseURL = URL(string: "https://\(host)/v1")!
        accessRepository = HTTPAccessRepository(baseURL: baseURL, session: session)
        familyRepository = HTTPFamilyRepository(baseURL: baseURL, session: session)
    }

    static func make(status: Int, json: String = "") -> AccountDeletionStubHTTP {
        let host = "account-deletion-\(UUID().uuidString.lowercased()).test"
        let stub = AccountDeletionStubHTTP(status: status, data: Data(json.utf8), host: host)
        lock.withLock { registry[host] = stub }
        return stub
    }

    static func stub(for host: String?) -> AccountDeletionStubHTTP? {
        lock.withLock { host.flatMap { registry[$0] } }
    }

    func requests() -> [AccountDeletionCapturedRequest] {
        Self.lock.withLock { captured }
    }

    fileprivate func respond(to request: URLRequest) -> (HTTPURLResponse, Data) {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
        let url = request.url!
        Self.lock.withLock {
            captured.append(AccountDeletionCapturedRequest(
                method: request.httpMethod ?? "",
                url: url,
                headers: request.allHTTPHeaderFields ?? [:],
                body: body
            ))
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

private final class AccountDeletionStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = AccountDeletionStubHTTP.stub(for: request.url?.host) else {
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

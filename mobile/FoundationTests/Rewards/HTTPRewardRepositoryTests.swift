import Foundation
@testable import FamilyRoutine
import Testing

struct HTTPRewardRepositoryTests {
    private let itemID = "00000000-0000-0000-0000-0000000000f6"

    @Test("GET /v1/reward-items decodes predefined and custom items, including a nil createdAt for predefined")
    func listDecodesCatalog() async throws {
        let json = """
        {
          "predefined": [
            {"id":"00000000-0000-0000-0000-0000000000f3","title":"Escolher o filme da noite","details":null,"source":"predefined"}
          ],
          "custom": [
            {"id":"\(itemID)","title":"Noite de pizza","details":"Escolher juntos","source":"custom","createdAt":"2026-10-10T13:00:00Z"}
          ]
        }
        """
        let stub = RewardStubHTTP.make(status: 200, json: json)

        let catalog = try await stub.repository.rewardItems(accessToken: "access-1")

        #expect(catalog.predefined.count == 1)
        #expect(catalog.predefined.first?.createdAt == nil)
        #expect(catalog.custom.count == 1)
        #expect(catalog.custom.first?.title == "Noite de pizza")
        #expect(catalog.custom.first?.createdAt != nil)

        let request = try #require(stub.requests().first)
        #expect(request.method == "GET")
        #expect(request.url.path == "/v1/reward-items")
        #expect(request.headers["Authorization"] == "Bearer access-1")
    }

    @Test("POST /v1/reward-items omits details when nil and decodes the canonical 201")
    func addSendsTitleAndOmitsNilDetails() async throws {
        let json = """
        {"id":"\(itemID)","title":"Noite de pizza","details":null,"source":"custom","createdAt":"2026-10-10T13:00:00Z"}
        """
        let stub = RewardStubHTTP.make(status: 201, json: json)
        let command = AddRewardItemCommand(title: "Noite de pizza", details: nil)

        let item = try await stub.repository.addRewardItem(command, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/reward-items")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["title"] as? String == "Noite de pizza")
        #expect(body["details"] == nil)
        #expect(item.title == "Noite de pizza")
        #expect(item.source == .custom)
    }

    @Test("POST /v1/reward-items never retries an ambiguous failure: reported as uncertain, not network")
    func addNetworkFailureIsUncertain() async {
        let stub = RewardStubHTTP.make(failure: URLError(.timedOut))
        let command = AddRewardItemCommand(title: "Noite de pizza", details: nil)

        await #expect(throws: RewardItemError.uncertainOutcome) {
            _ = try await stub.repository.addRewardItem(command, accessToken: "access-1")
        }
        #expect(stub.requests().count == 1)
    }

    /// Exercised via `rewardItems` (GET), not `addRewardItem`: the latter rewrites `.network`/
    /// `.unavailable` into `.uncertainOutcome` (BA-07), which would mask the raw status mapping.
    @Test("Maps every documented SPEC-015 §5.3 error code to its RewardItemError case")
    func errorMapping() async {
        await expectError(status: 403, json: #"{"code":"INSUFFICIENT_PERMISSIONS"}"#, .insufficientPermissions)
        await expectError(
            status: 422,
            json: #"{"code":"VALIDATION_FAILED","fieldErrors":{"title":["REWARD_TITLE_TOO_LONG"]}}"#,
            .validationFailed(["title": ["REWARD_TITLE_TOO_LONG"]])
        )
        await expectError(status: 422, json: #"{"code":"REWARD_TITLE_ALREADY_EXISTS"}"#, .titleAlreadyExists)
        await expectError(status: 503, json: #"{"code":"DEPENDENCY_UNAVAILABLE"}"#, .unavailable)
    }

    private func expectError(status: Int, json: String, _ expected: RewardItemError) async {
        let stub = RewardStubHTTP.make(status: status, json: json)
        await #expect(throws: expected) {
            _ = try await stub.repository.rewardItems(accessToken: "access-1")
        }
    }
}

/// Routes requests of one test to its own canned response, keyed by a unique host so tests can run
/// in parallel. Scoped to this file — distinct names from `MissionStubHTTP`, same test target.
final class RewardStubHTTP: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registry: [String: RewardStubHTTP] = [:]

    private let status: Int
    private let data: Data
    private let failure: URLError?
    private var captured: [RewardCapturedRequest] = []
    let repository: HTTPRewardRepository

    private init(status: Int, data: Data, failure: URLError?, host: String) {
        self.status = status
        self.data = data
        self.failure = failure
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RewardStubURLProtocol.self]
        repository = HTTPRewardRepository(
            baseURL: URL(string: "https://\(host)/v1")!,
            session: URLSession(configuration: configuration)
        )
    }

    static func make(status: Int = 200, json: String = "{}", failure: URLError? = nil) -> RewardStubHTTP {
        let host = "reward-stub-\(UUID().uuidString.lowercased()).test"
        let stub = RewardStubHTTP(status: status, data: Data(json.utf8), failure: failure, host: host)
        lock.withLock { registry[host] = stub }
        return stub
    }

    static func stub(for host: String?) -> RewardStubHTTP? {
        lock.withLock { host.flatMap { registry[$0] } }
    }

    func requests() -> [RewardCapturedRequest] {
        Self.lock.withLock { captured }
    }

    fileprivate func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
        let url = request.url!
        Self.lock.withLock {
            captured.append(
                RewardCapturedRequest(
                    method: request.httpMethod ?? "",
                    url: url,
                    headers: request.allHTTPHeaderFields ?? [:],
                    body: body
                )
            )
        }
        if let failure {
            throw failure
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

struct RewardCapturedRequest: Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data
}

private final class RewardStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = RewardStubHTTP.stub(for: request.url?.host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try stub.respond(to: request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

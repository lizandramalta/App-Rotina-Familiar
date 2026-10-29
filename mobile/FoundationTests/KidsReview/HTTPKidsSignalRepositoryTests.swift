import Foundation
@testable import FamilyRoutine
import Testing

@Suite(.serialized)
struct HTTPKidsSignalRepositoryTests {
    private let signalID = "00000000-0000-0000-0000-0000000005a1"
    private let taskID = "00000000-0000-0000-0000-0000000005b1"
    private let childID = "00000000-0000-0000-0000-0000000005c1"

    private var queueJSON: String {
        """
        {"items":[{"signalId":"\(signalID)","task":{"id":"\(taskID)","title":"Arrumar a cama"},\
        "signaledBy":{"id":"\(childID)","name":"Rafa"},"signaledAt":"2026-10-27T10:00:00.000Z","hasPhoto":true}],\
        "nextCursor":"cursor-2"}
        """
    }

    @Test("SPEC-013 CA-01 requests the queue with the bearer token and maps the page")
    func getReviewQueue() async throws {
        let stub = KidsSignalStubHTTP.make(json: queueJSON)

        let page = try await stub.repository.getReviewQueue(accessToken: "access-1", cursor: nil)

        let request = try #require(stub.requests().first)
        #expect(request.method == "GET")
        #expect(request.url.path == "/v1/kids/signals")
        #expect(request.url.query == nil)
        #expect(request.headers["Authorization"] == "Bearer access-1")
        let item = try #require(page.items.first)
        #expect(item.id == UUID(uuidString: signalID))
        #expect(item.taskID == UUID(uuidString: taskID))
        #expect(item.taskTitle == "Arrumar a cama")
        #expect(item.signaledByID == UUID(uuidString: childID))
        #expect(item.childName == "Rafa")
        #expect(item.hasPhoto)
        #expect(item.signaledAt == ISO8601DateFormatter().date(from: "2026-10-27T10:00:00Z"))
        #expect(page.nextCursor == "cursor-2")
    }

    @Test("SPEC-013 CA-01 forwards the opaque cursor as a query item")
    func forwardsCursor() async throws {
        let stub = KidsSignalStubHTTP.make(json: #"{"items":[],"nextCursor":null}"#)

        let page = try await stub.repository.getReviewQueue(accessToken: "access-1", cursor: "cursor-2")

        let request = try #require(stub.requests().first)
        #expect(request.url.query == "cursor=cursor-2")
        #expect(page.items.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test("SPEC-013 CA-05 maps refusals and failures to stable errors")
    func errors() async {
        let cases: [(KidsSignalStubHTTP, KidsSignalError)] = [
            (KidsSignalStubHTTP.make(status: 403, json: #"{"code":"ACTION_NOT_ALLOWED"}"#), .actionNotAllowed),
            (KidsSignalStubHTTP.make(status: 404, json: #"{"code":"RESOURCE_NOT_FOUND"}"#), .notFound),
            (KidsSignalStubHTTP.make(status: 422, json: #"{"code":"VALIDATION_FAILED"}"#), .rejected),
            (KidsSignalStubHTTP.make(status: 503, json: #"{"code":"DEPENDENCY_UNAVAILABLE"}"#), .unavailable),
            (KidsSignalStubHTTP.make(failure: URLError(.notConnectedToInternet)), .network),
            (KidsSignalStubHTTP.make(json: #"{"unexpected":true}"#), .unavailable),
        ]
        for (stub, expected) in cases {
            await #expect(throws: expected) {
                _ = try await stub.repository.getReviewQueue(accessToken: "access-1", cursor: nil)
            }
        }
    }
}

/// Routes requests of one test to its own canned response, keyed by a unique host so tests can run
/// in parallel. Scoped to this file — distinct names from `TaskStubHTTP`, same test target.
final class KidsSignalStubHTTP: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registry: [String: KidsSignalStubHTTP] = [:]

    private let status: Int
    private let data: Data
    private let failure: URLError?
    private var captured: [KidsSignalCapturedRequest] = []
    let repository: HTTPKidsSignalRepository

    private init(status: Int, data: Data, failure: URLError?, host: String) {
        self.status = status
        self.data = data
        self.failure = failure
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [KidsSignalStubURLProtocol.self]
        repository = HTTPKidsSignalRepository(
            baseURL: URL(string: "https://\(host)/v1")!,
            session: URLSession(configuration: configuration)
        )
    }

    static func make(status: Int = 200, json: String = "{}", failure: URLError? = nil) -> KidsSignalStubHTTP {
        let host = "kids-signal-stub-\(UUID().uuidString.lowercased()).test"
        let stub = KidsSignalStubHTTP(status: status, data: Data(json.utf8), failure: failure, host: host)
        lock.withLock { registry[host] = stub }
        return stub
    }

    static func stub(for host: String?) -> KidsSignalStubHTTP? {
        lock.withLock { host.flatMap { registry[$0] } }
    }

    func requests() -> [KidsSignalCapturedRequest] {
        Self.lock.withLock { captured }
    }

    fileprivate func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
        let url = request.url!
        Self.lock.withLock {
            captured.append(
                KidsSignalCapturedRequest(
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

struct KidsSignalCapturedRequest: Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data
}

private final class KidsSignalStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = KidsSignalStubHTTP.stub(for: request.url?.host) else {
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

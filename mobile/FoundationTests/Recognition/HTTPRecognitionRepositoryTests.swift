import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-020 §5 contract consumed by TEL-052 (SCRUM-103).
struct HTTPRecognitionRepositoryTests {
    private let recognitionID = "00000000-0000-0000-0000-00000000c052"

    private var recognitionJSON: String {
        """
        {"id":"\(recognitionID)","period":{"startsAt":"2026-09-28T03:00:00.000Z","endsAt":"2026-10-05T03:00:00.000Z",
        "referenceWeek":"2026-09-28"},"timeZoneId":"America/Sao_Paulo","isTransition":false,"points":42,
        "completedTasks":12,"isTie":true,"processedAt":"2026-10-05T03:00:05.000Z","openedAt":null}
        """
    }

    @Test("SPEC-020 CA-07 GET /v1/me/weekly-recognitions/{id} decodes period, time zone, points, tasks and tie")
    func getRecognition() async throws {
        let stub = RecognitionStubHTTP.make(status: 200, json: recognitionJSON)

        let recognition = try await stub.repository.recognition(
            id: UUID(uuidString: recognitionID)!,
            accessToken: "access-1"
        )

        let request = try #require(stub.requests().first)
        #expect(request.method == "GET")
        #expect(request.url.path == "/v1/me/weekly-recognitions/\(recognitionID)")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        #expect(recognition.points == 42)
        #expect(recognition.completedTasks == 12)
        #expect(recognition.isTie)
        #expect(recognition.timeZoneID == "America/Sao_Paulo")
        #expect(recognition.openedAt == nil)
        #expect(recognition.endsAt == ISO8601DateFormatter().date(from: "2026-10-05T03:00:00Z"))
    }

    @Test("SPEC-020 CA-05 list reads only the owner's finalized results")
    func listOwn() async throws {
        let stub = RecognitionStubHTTP.make(status: 200, json: #"{"items":[\#(recognitionJSON)]}"#)

        let items = try await stub.repository.listOwn(accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.url.path == "/v1/me/weekly-recognitions")
        #expect(items.map(\.id) == [UUID(uuidString: recognitionID)!])
    }

    @Test("SPEC-020 §5 opening is a POST without body that returns the same result")
    func recordOpening() async throws {
        let stub = RecognitionStubHTTP.make(status: 200, json: recognitionJSON)

        _ = try await stub.repository.recordOpening(id: UUID(uuidString: recognitionID)!, accessToken: "a")

        let request = try #require(stub.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/me/weekly-recognitions/\(recognitionID)/opening")
        #expect(request.body.isEmpty)
    }

    @Test("SPEC-020 CA-05 maps 401 to session expired and 404 to not found, without other details",
          arguments: [(401, RecognitionError.sessionExpired), (404, .notFound), (503, .unavailable)])
    func mapsErrors(status: Int, expected: RecognitionError) async {
        let stub = RecognitionStubHTTP.make(
            status: status,
            json: #"{"type":"about:blank","title":"x","status":\#(status),"code":"X","requestId":"r"}"#
        )

        await #expect(throws: expected) {
            _ = try await stub.repository.recognition(id: UUID(), accessToken: "a")
        }
    }

    @Test("connectivity failures are reported as network errors")
    func networkFailure() async {
        let stub = RecognitionStubHTTP.make(failure: URLError(.notConnectedToInternet))

        await #expect(throws: RecognitionError.network) {
            _ = try await stub.repository.listOwn(accessToken: "a")
        }
    }

    @Test("an unexpected body is unavailable, never a partial result")
    func malformedBody() async {
        let stub = RecognitionStubHTTP.make(status: 200, json: #"{"id":"nope"}"#)

        await #expect(throws: RecognitionError.unavailable) {
            _ = try await stub.repository.recognition(id: UUID(), accessToken: "a")
        }
    }
}

/// Routes the requests of one test to its own canned response, keyed by a unique host.
final class RecognitionStubHTTP: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registry: [String: RecognitionStubHTTP] = [:]

    private let status: Int
    private let data: Data
    private let failure: URLError?
    private var captured: [CapturedRequest] = []
    let repository: HTTPRecognitionRepository

    private init(status: Int, data: Data, failure: URLError?, host: String) {
        self.status = status
        self.data = data
        self.failure = failure
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecognitionStubURLProtocol.self]
        repository = HTTPRecognitionRepository(
            baseURL: URL(string: "https://\(host)/v1")!,
            session: URLSession(configuration: configuration)
        )
    }

    static func make(status: Int = 200, json: String = "{}", failure: URLError? = nil) -> RecognitionStubHTTP {
        let host = "recognition-stub-\(UUID().uuidString.lowercased()).test"
        let stub = RecognitionStubHTTP(status: status, data: Data(json.utf8), failure: failure, host: host)
        lock.withLock { registry[host] = stub }
        return stub
    }

    static func stub(for host: String?) -> RecognitionStubHTTP? {
        lock.withLock { host.flatMap { registry[$0] } }
    }

    func requests() -> [CapturedRequest] {
        Self.lock.withLock { captured }
    }

    fileprivate func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let url = request.url!
        Self.lock.withLock {
            captured.append(CapturedRequest(
                method: request.httpMethod ?? "",
                url: url,
                headers: request.allHTTPHeaderFields ?? [:],
                body: request.httpBody ?? Data()
            ))
        }
        if let failure { throw failure }
        return (HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, data)
    }
}

private final class RecognitionStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = RecognitionStubHTTP.stub(for: request.url?.host) else {
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

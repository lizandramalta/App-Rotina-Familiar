import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-008 Fase 1 — CA-01 to CA-04 and the pending materialization response.
struct HTTPRoutineRepositoryTests {
    private let routineID = UUID(uuidString: "00000000-0000-0000-0000-0000000000a8")!

    private func routineJSON(state: String = "pending") -> String {
        """
        {"id":"\(routineID.uuidString.lowercased())","title":"Regar as plantas","weight":1,
         "assigneeIds":[],"note":null,"startDate":"2026-10-10","frequencyDays":7,
         "isActive":true,"materializationState":"\(state)"}
        """
    }

    private var command: CreateRoutineCommand {
        CreateRoutineCommand(
            title: "Regar as plantas", weight: .low, assigneeIDs: [], note: nil,
            startDate: "2026-10-10", frequency: .everySevenDays
        )
    }

    @Test("CA-01 POST /v1/routines sends the accepted fields, no endDate, and decodes pending")
    func create() async throws {
        let stub = RoutineStubHTTP.make(status: 201, json: routineJSON())

        let routine = try await stub.repository.createRoutine(command, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/routines")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        #expect(body["frequencyDays"] as? Int == 7)
        #expect(body["startDate"] as? String == "2026-10-10")
        #expect(body["note"] == nil)
        #expect(body["endDate"] == nil)
        #expect(routine.materializationState == .pending)
    }

    @Test("CA-01 GET /v1/routines/:id reads the canonical completion state")
    func get() async throws {
        let stub = RoutineStubHTTP.make(status: 200, json: routineJSON(state: "complete"))

        let routine = try await stub.repository.routine(id: routineID, accessToken: "access-1")

        #expect(stub.requests().first?.url.path == "/v1/routines/\(routineID.uuidString.lowercased())")
        #expect(routine.materializationState == .complete)
        #expect(routine.frequency == .everySevenDays)
    }

    @Test("RN11 GET /v1/family supplies the family's time zone for the default start day")
    func familyTimeZone() async throws {
        let stub = RoutineStubHTTP.make(status: 200, json: #"{"timeZoneId":"America/Sao_Paulo"}"#)
        #expect(try await stub.repository.familyTimeZoneID(accessToken: "access-1") == "America/Sao_Paulo")
        #expect(stub.requests().first?.url.path == "/v1/family")
    }

    @Test("A lost create response is uncertain and never retried automatically")
    func uncertainCreate() async {
        let stub = RoutineStubHTTP.make(failure: URLError(.timedOut))

        await #expect(throws: RoutineError.uncertainOutcome) {
            _ = try await stub.repository.createRoutine(command, accessToken: "access-1")
        }
        #expect(stub.requests().count == 1)
    }

    @Test("CA-02 to CA-04 maps validation, authorization and family isolation without exposing a routine")
    func errors() async {
        await expectError(422, #"{"code":"VALIDATION_FAILED","fieldErrors":{"frequencyDays":["FREQUENCY_DAYS_INVALID"]}}"#,
                          .validationFailed(["frequencyDays": ["FREQUENCY_DAYS_INVALID"]]))
        await expectError(403, #"{"code":"ACTION_NOT_ALLOWED"}"#, .actionNotAllowed)
        await expectError(404, #"{"code":"RESOURCE_NOT_FOUND"}"#, .notFound)
        await expectError(503, #"{"code":"DEPENDENCY_UNAVAILABLE"}"#, .unavailable)
    }

    private func expectError(_ status: Int, _ json: String, _ expected: RoutineError) async {
        let stub = RoutineStubHTTP.make(status: status, json: json)
        await #expect(throws: expected) {
            _ = try await stub.repository.routine(id: routineID, accessToken: "access-1")
        }
    }
}

private struct RoutineCapturedRequest: Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data
}

private final class RoutineStubHTTP: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registry: [String: RoutineStubHTTP] = [:]

    private let status: Int
    private let data: Data
    private let failure: URLError?
    private var captured: [RoutineCapturedRequest] = []
    let repository: HTTPRoutineRepository

    private init(status: Int, data: Data, failure: URLError?, host: String) {
        self.status = status
        self.data = data
        self.failure = failure
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RoutineStubURLProtocol.self]
        repository = HTTPRoutineRepository(
            baseURL: URL(string: "https://\(host)/v1")!,
            session: URLSession(configuration: configuration)
        )
    }

    static func make(status: Int = 200, json: String = "{}", failure: URLError? = nil) -> RoutineStubHTTP {
        let host = "routine-stub-\(UUID().uuidString.lowercased()).test"
        let stub = RoutineStubHTTP(status: status, data: Data(json.utf8), failure: failure, host: host)
        lock.withLock { registry[host] = stub }
        return stub
    }

    static func stub(for host: String?) -> RoutineStubHTTP? {
        lock.withLock { host.flatMap { registry[$0] } }
    }

    func requests() -> [RoutineCapturedRequest] { Self.lock.withLock { captured } }

    fileprivate func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
        let url = request.url!
        Self.lock.withLock {
            captured.append(RoutineCapturedRequest(
                method: request.httpMethod ?? "", url: url,
                headers: request.allHTTPHeaderFields ?? [:], body: body
            ))
        }
        if let failure { throw failure }
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

private final class RoutineStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = RoutineStubHTTP.stub(for: request.url?.host) else {
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

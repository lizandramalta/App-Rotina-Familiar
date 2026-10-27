import Foundation
@testable import FamilyRoutine
import Testing

struct HTTPMissionRepositoryTests {
    private let missionID = "00000000-0000-0000-0000-0000000000e1"
    private let familyID = "00000000-0000-0000-0000-0000000000f1"
    private let taskID = "00000000-0000-0000-0000-0000000000b1"

    private func missionJSON(
        status: String = "inProgress",
        note: String = "null",
        taskIds: String = "[]",
        includeRedemption: Bool = true,
        completedAt: String = "null"
    ) -> String {
        let redemptionField = includeRedemption ? #""isRedemptionAvailable":false,"# : ""
        return """
        {"id":"\(missionID)","familyId":"\(familyID)","title":"Casa pronta para o fim de semana","note":\(note),
        "status":"\(status)","taskIds":\(taskIds),"completedAt":\(completedAt),\(redemptionField)"createdAt":"2026-10-07T15:00:00Z"}
        """
    }

    @Test("POST /v1/missions sends title, note and taskIds and decodes the canonical 201")
    func createMissionSuccess() async throws {
        let stub = MissionStubHTTP.make(status: 201, json: missionJSON(taskIds: "[\"\(taskID)\"]"))
        let command = CreateMissionCommand(title: "Casa pronta para o fim de semana", note: nil, taskIDs: [UUID(uuidString: taskID)!])

        let mission = try await stub.repository.createMission(command, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/missions")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["note"] is NSNull)
        #expect(mission.title == "Casa pronta para o fim de semana")
        #expect(mission.status == .inProgress)
        #expect(mission.taskIDs == [UUID(uuidString: taskID)!])
    }

    @Test("POST /v1/missions never retries an ambiguous failure: reported as uncertain, not network")
    func createMissionNetworkFailureIsUncertain() async {
        let stub = MissionStubHTTP.make(failure: URLError(.timedOut))
        let command = CreateMissionCommand(title: "Missão", note: nil, taskIDs: [UUID(uuidString: taskID)!])

        await #expect(throws: MissionError.uncertainOutcome) {
            _ = try await stub.repository.createMission(command, accessToken: "access-1")
        }
        #expect(stub.requests().count == 1)
    }

    @Test("GET /v1/missions/:id leaves a network failure as .network, not uncertain")
    func getMissionNetworkFailureStaysNetwork() async {
        let stub = MissionStubHTTP.make(failure: URLError(.notConnectedToInternet))

        await #expect(throws: MissionError.network) {
            _ = try await stub.repository.mission(id: UUID(uuidString: missionID)!, accessToken: "access-1")
        }
    }

    @Test("CA-19: isRedemptionAvailable absent from the Kids projection decodes to nil, not a thrown error")
    func decodesMissingIsRedemptionAvailableAsNil() async throws {
        let stub = MissionStubHTTP.make(status: 200, json: missionJSON(includeRedemption: false))

        let mission = try await stub.repository.mission(id: UUID(uuidString: missionID)!, accessToken: "access-1")

        #expect(mission.isRedemptionAvailable == nil)
    }

    @Test("PATCH /v1/missions/:id always sends title, note and taskIds — note explicitly null clears it")
    func updateMissionAlwaysSendsFullBody() async throws {
        let stub = MissionStubHTTP.make(status: 200, json: missionJSON())
        let command = UpdateMissionCommand(
            missionID: UUID(uuidString: missionID)!,
            title: "Novo título",
            note: nil,
            taskIDs: [UUID(uuidString: taskID)!]
        )

        _ = try await stub.repository.updateMission(command, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "PATCH")
        #expect(request.url.path == "/v1/missions/\(missionID)")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["note"] is NSNull)
        // `UUID.uuidString` encodes uppercase; compare by value rather than by raw string case.
        let sentTaskIDs = (body["taskIds"] as? [String])?.compactMap { UUID(uuidString: $0) }
        #expect(sentTaskIDs == [UUID(uuidString: taskID)!])
    }

    @Test("GET /v1/missions decodes the minimal list projection")
    func listMissionsDecodesSummaries() async throws {
        let json = """
        {"items":[{"id":"\(missionID)","title":"Casa pronta para o fim de semana","status":"inProgress","taskCount":2,"completedTaskCount":1}],"nextCursor":null}
        """
        let stub = MissionStubHTTP.make(status: 200, json: json)

        let page = try await stub.repository.missions(cursor: nil, accessToken: "access-1")

        #expect(page.items.count == 1)
        #expect(page.items.first?.taskCount == 2)
        #expect(page.items.first?.completedTaskCount == 1)
        #expect(page.nextCursor == nil)
    }

    @Test("GET /v1/missions/task-options sends query and cursor as query items")
    func taskOptionsSendsQueryAndCursor() async throws {
        let json = """
        {"items":[{"id":"\(taskID)","title":"Arrumar o quintal","weight":2,"scheduledDate":"2026-10-10","status":"pending","assigneeIds":[]}],"nextCursor":"abc"}
        """
        let stub = MissionStubHTTP.make(status: 200, json: json)

        let page = try await stub.repository.taskOptions(query: "quintal", cursor: "page-1", accessToken: "access-1")

        let request = try #require(stub.requests().first)
        let items = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "query", value: "quintal")))
        #expect(items.contains(URLQueryItem(name: "cursor", value: "page-1")))
        #expect(page.items.first?.title == "Arrumar o quintal")
        #expect(page.nextCursor == "abc")
    }

    @Test("Maps every documented SPEC-014 §5.3 error code to its MissionError case")
    func errorMapping() async {
        await expectError(status: 403, json: #"{"code":"ACTION_NOT_ALLOWED"}"#, .actionNotAllowed)
        await expectError(status: 404, json: #"{"code":"RESOURCE_NOT_FOUND"}"#, .notFound)
        await expectError(status: 409, json: #"{"code":"MISSION_COMPLETED_PROTECTED"}"#, .completedProtected)
        await expectError(status: 409, json: #"{"code":"MISSION_WOULD_HAVE_NO_TASKS"}"#, .wouldHaveNoTasks)
        await expectError(
            status: 422,
            json: #"{"code":"VALIDATION_FAILED","fieldErrors":{"title":["TITLE_INVALID_LENGTH"]}}"#,
            .validationFailed(["title": ["TITLE_INVALID_LENGTH"]])
        )
        await expectError(status: 503, json: #"{"code":"DEPENDENCY_UNAVAILABLE"}"#, .unavailable)
        await expectError(status: 500, json: "{}", .unavailable)
        await expectError(status: 400, json: #"{"code":"UNKNOWN_FIELD"}"#, .rejected)
    }

    private func expectError(status: Int, json: String, _ expected: MissionError) async {
        let stub = MissionStubHTTP.make(status: status, json: json)
        await #expect(throws: expected) {
            _ = try await stub.repository.mission(id: UUID(uuidString: missionID)!, accessToken: "access-1")
        }
    }
}

/// Routes requests of one test to its own canned response, keyed by a unique host so tests can run
/// in parallel. Scoped to this file — distinct names from `TaskStubHTTP`, same test target.
final class MissionStubHTTP: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registry: [String: MissionStubHTTP] = [:]

    private let status: Int
    private let data: Data
    private let failure: URLError?
    private var captured: [MissionCapturedRequest] = []
    let repository: HTTPMissionRepository

    private init(status: Int, data: Data, failure: URLError?, host: String) {
        self.status = status
        self.data = data
        self.failure = failure
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MissionStubURLProtocol.self]
        repository = HTTPMissionRepository(
            baseURL: URL(string: "https://\(host)/v1")!,
            session: URLSession(configuration: configuration)
        )
    }

    static func make(status: Int = 200, json: String = "{}", failure: URLError? = nil) -> MissionStubHTTP {
        let host = "mission-stub-\(UUID().uuidString.lowercased()).test"
        let stub = MissionStubHTTP(status: status, data: Data(json.utf8), failure: failure, host: host)
        lock.withLock { registry[host] = stub }
        return stub
    }

    static func stub(for host: String?) -> MissionStubHTTP? {
        lock.withLock { host.flatMap { registry[$0] } }
    }

    func requests() -> [MissionCapturedRequest] {
        Self.lock.withLock { captured }
    }

    fileprivate func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
        let url = request.url!
        Self.lock.withLock {
            captured.append(
                MissionCapturedRequest(
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

struct MissionCapturedRequest: Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data
}

private final class MissionStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = MissionStubHTTP.stub(for: request.url?.host) else {
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

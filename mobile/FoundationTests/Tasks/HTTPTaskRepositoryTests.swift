import Foundation
@testable import FamilyRoutine
import Testing

struct HTTPTaskRepositoryTests {
    private let taskID = "00000000-0000-0000-0000-0000000000f1"

    private func taskJSON(status: String = "pending", note: String = "null") -> String {
        """
        {"id":"\(taskID)","title":"Arrumar os brinquedos","weight":2,"scheduledDate":"2026-10-10",
        "assigneeIds":[],"note":\(note),"status":"\(status)","routineId":null,"createdAt":"2026-10-06T15:00:00Z"}
        """
    }

    @Test("POST /v1/tasks sends every single-task field and decodes the canonical 201")
    func createTaskSuccess() async throws {
        let stub = TaskStubHTTP.make(status: 201, json: taskJSON())
        let command = CreateTaskCommand(
            title: "Arrumar os brinquedos", weight: .medium, scheduledDate: "2026-10-10", assigneeIDs: [], note: nil
        )

        let task = try await stub.repository.createTask(command, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/tasks")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["note"] is NSNull)
        #expect(task.title == "Arrumar os brinquedos")
        #expect(task.weight == .medium)
        #expect(task.status == .pending)
    }

    @Test("POST /v1/tasks never retries an ambiguous failure: reported as uncertain, not network")
    func createTaskNetworkFailureIsUncertain() async {
        let stub = TaskStubHTTP.make(failure: URLError(.timedOut))
        let command = CreateTaskCommand(
            title: "Tarefa", weight: .low, scheduledDate: "2026-10-10", assigneeIDs: [], note: nil
        )

        await #expect(throws: TaskError.uncertainOutcome) {
            _ = try await stub.repository.createTask(command, accessToken: "access-1")
        }
        #expect(stub.requests().count == 1)
    }

    @Test("GET /v1/tasks/:id decodes the task and leaves a network failure as .network, not uncertain")
    func getTaskNetworkFailureStaysNetwork() async {
        let stub = TaskStubHTTP.make(failure: URLError(.notConnectedToInternet))

        await #expect(throws: TaskError.network) {
            _ = try await stub.repository.task(id: UUID(uuidString: taskID)!, accessToken: "access-1")
        }
    }

    @Test("PATCH /v1/tasks/:id sends signalResolution only when present")
    func updateTaskOmitsSignalResolutionWhenNil() async throws {
        let stub = TaskStubHTTP.make(status: 200, json: taskJSON())
        let command = UpdateTaskCommand(
            taskID: UUID(uuidString: taskID)!, title: "Novo título", weight: .high,
            scheduledDate: "2026-10-11", assigneeIDs: [], note: nil, signalResolution: nil
        )

        _ = try await stub.repository.updateTask(command, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "PATCH")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["signalResolution"] == nil)
    }

    @Test("PATCH /v1/tasks/:id includes signalResolution when editing an awaitingConfirmation task")
    func updateTaskIncludesSignalResolutionWhenPresent() async throws {
        let stub = TaskStubHTTP.make(status: 200, json: taskJSON(status: "pending"))
        let command = UpdateTaskCommand(
            taskID: UUID(uuidString: taskID)!, title: "Novo título", weight: .high,
            scheduledDate: "2026-10-11", assigneeIDs: [], note: nil, signalResolution: .resetToPending
        )

        _ = try await stub.repository.updateTask(command, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["signalResolution"] as? String == "resetToPending")
    }

    @Test("Maps every documented SPEC-007 §5.3 error code to its TaskError case")
    func errorMapping() async {
        await expectError(status: 403, json: #"{"code":"ACTION_NOT_ALLOWED"}"#, .actionNotAllowed)
        await expectError(status: 404, json: #"{"code":"RESOURCE_NOT_FOUND"}"#, .notFound)
        await expectError(status: 409, json: #"{"code":"TASK_ALREADY_COMPLETED"}"#, .alreadyCompleted)
        await expectError(status: 409, json: #"{"code":"MISSION_COMPLETED_PROTECTED"}"#, .missionCompletedProtected)
        await expectError(status: 409, json: #"{"code":"MISSION_WOULD_HAVE_NO_TASKS"}"#, .missionWouldHaveNoTasks)
        await expectError(status: 422, json: #"{"code":"SIGNAL_RESOLUTION_REQUIRED"}"#, .signalResolutionRequired)
        await expectError(
            status: 422,
            json: #"{"code":"VALIDATION_FAILED","fieldErrors":{"title":["TITLE_INVALID_LENGTH"]}}"#,
            .validationFailed(["title": ["TITLE_INVALID_LENGTH"]])
        )
        await expectError(status: 503, json: #"{"code":"DEPENDENCY_UNAVAILABLE"}"#, .unavailable)
        await expectError(status: 500, json: "{}", .unavailable)
        await expectError(status: 400, json: #"{"code":"UNKNOWN_FIELD"}"#, .rejected)
    }

    @Test("POST /v1/tasks/:id/reopening sends confirm explicitly and decodes only the task")
    func reopenTaskSuccess() async throws {
        let stub = TaskStubHTTP.make(status: 200, json: #"{"task":\#(taskJSON(status: "pending"))}"#)

        let task = try await stub.repository.reopenTask(id: UUID(uuidString: taskID)!, confirm: false, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/tasks/\(taskID)/reopening")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["confirm"] as? Bool == false)
        #expect(task.status == .pending)
    }

    @Test("409 TASK_NOT_COMPLETED and MISSION_REOPEN_REQUIRES_CONFIRMATION map to SPEC-011's dedicated cases")
    func reopenTaskErrorMapping() async {
        await expectError(status: 409, json: #"{"code":"TASK_NOT_COMPLETED"}"#, .taskNotCompleted)
        await expectError(
            status: 409,
            json: #"{"code":"MISSION_REOPEN_REQUIRES_CONFIRMATION","missionsAffected":[{"id":"00000000-0000-0000-0000-0000000000f2","title":"Arrumar o quintal"}],"hasAcceptedReward":true}"#,
            .missionReopenRequiresConfirmation(
                missionsAffected: [AffectedMission(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000f2")!, title: "Arrumar o quintal")],
                hasAcceptedReward: true
            )
        )
    }

    @Test("SPEC-010 CA-01/02/05: completion POST has no body and decodes the canonical task")
    func completeTaskSuccess() async throws {
        let stub = TaskStubHTTP.make(
            status: 200,
            json: #"{"task":\#(taskJSON(status: "completed")),"affectedResources":[]}"#
        )

        let task = try await stub.repository.completeTask(id: UUID(uuidString: taskID)!, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/tasks/\(taskID)/completion")
        #expect(request.body.isEmpty)
        #expect(request.headers["Authorization"] == "Bearer access-1")
        #expect(task.status == .completed)
    }

    @Test("SPEC-010 CA-06: a competing completion reports the named conflict for canonical reload")
    func completeTaskConflict() async {
        let stub = TaskStubHTTP.make(status: 409, json: #"{"code":"TASK_ALREADY_COMPLETED"}"#)

        await #expect(throws: TaskError.alreadyCompleted) {
            _ = try await stub.repository.completeTask(id: UUID(uuidString: taskID)!, accessToken: "access-1")
        }
        #expect(stub.requests().count == 1)
    }

    @Test("SPEC-010 safety: an ambiguous POST is reported once for reconciliation")
    func completeTaskNetworkFailureIsUncertain() async {
        let stub = TaskStubHTTP.make(failure: URLError(.timedOut))

        await #expect(throws: TaskError.uncertainOutcome) {
            _ = try await stub.repository.completeTask(id: UUID(uuidString: taskID)!, accessToken: "access-1")
        }
        #expect(stub.requests().count == 1)
    }

    private func expectError(status: Int, json: String, _ expected: TaskError) async {
        let stub = TaskStubHTTP.make(status: status, json: json)
        await #expect(throws: expected) {
            _ = try await stub.repository.task(id: UUID(uuidString: taskID)!, accessToken: "access-1")
        }
    }
}

/// Routes requests of one test to its own canned response, keyed by a unique host so tests can run in parallel.
/// Scoped to this file (distinct names from `HTTPFamilyRepositoryTests`'s own `StubHTTP`, same target).
final class TaskStubHTTP: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registry: [String: TaskStubHTTP] = [:]

    private let status: Int
    private let data: Data
    private let failure: URLError?
    private var captured: [TaskCapturedRequest] = []
    let repository: HTTPTaskRepository

    private init(status: Int, data: Data, failure: URLError?, host: String) {
        self.status = status
        self.data = data
        self.failure = failure
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TaskStubURLProtocol.self]
        repository = HTTPTaskRepository(
            baseURL: URL(string: "https://\(host)/v1")!,
            session: URLSession(configuration: configuration)
        )
    }

    static func make(status: Int = 200, json: String = "{}", failure: URLError? = nil) -> TaskStubHTTP {
        let host = "task-stub-\(UUID().uuidString.lowercased()).test"
        let stub = TaskStubHTTP(status: status, data: Data(json.utf8), failure: failure, host: host)
        lock.withLock { registry[host] = stub }
        return stub
    }

    static func stub(for host: String?) -> TaskStubHTTP? {
        lock.withLock { host.flatMap { registry[$0] } }
    }

    func requests() -> [TaskCapturedRequest] {
        Self.lock.withLock { captured }
    }

    fileprivate func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
        let url = request.url!
        Self.lock.withLock {
            captured.append(
                TaskCapturedRequest(
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

struct TaskCapturedRequest: Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data
}

private final class TaskStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = TaskStubHTTP.stub(for: request.url?.host) else {
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

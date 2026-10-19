import Foundation
@testable import FamilyRoutine
import Testing

struct HTTPFamilyRepositoryTests {
    private let familyID = "00000000-0000-0000-0000-0000000000f1"
    private let memberID = "00000000-0000-0000-0000-0000000000a1"
    private let sessionID = "00000000-0000-0000-0000-0000000000b1"

    private var command: CreateFamilyCommand {
        CreateFamilyCommand(
            creationGrant: "grant-1",
            creatorName: "Maria Silva",
            creatorNickname: nil,
            familyName: "Casa Silva",
            timeZoneID: "America/Sao_Paulo"
        )
    }

    @Test("SPEC-002 CA-01 posts only the contract fields with the installation proof and decodes the 201")
    func createFamilySuccess() async throws {
        let stub = StubHTTP.make(status: 201, json: createdFamilyJSON)

        let created = try await stub.repository.createFamily(command, installationProof: "proof-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/families")
        #expect(request.headers["X-Installation-Proof"] == "proof-1")
        #expect(request.headers["Authorization"] == nil)
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(Set(body.keys) == ["creationGrant", "creatorName", "creatorNickname", "name", "timeZoneId"])
        #expect(body["creationGrant"] as? String == "grant-1")
        #expect(body["name"] as? String == "Casa Silva")
        #expect(body["creatorNickname"] is NSNull)
        #expect(created.familyID == UUID(uuidString: familyID))
        #expect(created.session.profile.role == .administrator)
        #expect(created.session.profile.isFamilyCreator)
        #expect(created.session.credentials.refreshToken == "refresh-1")
        #expect(created.session.credentials.token.accessToken == "access-1")
    }

    @Test("SPEC-002 CA-04 maps rejections without treating them as uncertain")
    func createFamilyRejections() async {
        await expectCreateFamilyError(status: 401, json: #"{"code":"CREATION_GRANT_INVALID"}"#, .creationGrantInvalid)
        await expectCreateFamilyError(
            status: 422,
            json: #"{"code":"VALIDATION_FAILED","fieldErrors":{"name":["FAMILY_NAME_REQUIRED"]}}"#,
            .validationFailed(["name": ["FAMILY_NAME_REQUIRED"]])
        )
        await expectCreateFamilyError(status: 429, json: #"{"code":"RATE_LIMIT_EXCEEDED"}"#, .rateLimited)
        await expectCreateFamilyError(status: 400, json: #"{"code":"UNKNOWN_FIELD"}"#, .rejected)
    }

    @Test("SPEC-002 CA-09 treats 503, 500 and unreadable 201 as an uncertain outcome")
    func createFamilyUncertain() async {
        await expectCreateFamilyError(status: 503, json: #"{"code":"DEPENDENCY_UNAVAILABLE"}"#, .uncertainOutcome)
        await expectCreateFamilyError(status: 500, json: "{}", .uncertainOutcome)
        await expectCreateFamilyError(status: 201, json: "{}", .uncertainOutcome)
    }

    @Test("SPEC-002 CA-09 never retries POST /v1/families after a network failure")
    func createFamilyNetworkFailureIsUncertainAndNotRetried() async {
        let stub = StubHTTP.make(failure: URLError(.timedOut))

        await #expect(throws: FamilyError.uncertainOutcome) {
            _ = try await stub.repository.createFamily(command, installationProof: "proof")
        }
        #expect(stub.requests().count == 1)
    }

    @Test("SPEC-002 CA-10 uploads the profile photo as multipart with purpose and profile.jpg")
    func uploadPhoto() async throws {
        let stub = StubHTTP.make(status: 201, json: #"{"mediaId":"media-1","state":"READY","width":10,"height":10}"#)
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

        let mediaID = try await stub.repository.uploadProfilePhoto(jpeg, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(mediaID == "media-1")
        #expect(request.url.path == "/v1/media")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        let contentType = try #require(request.headers["Content-Type"])
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
        let body = String(decoding: request.body, as: UTF8.self)
        #expect(body.contains("name=\"purpose\"\r\n\r\nprofilePhoto"))
        #expect(body.contains("name=\"file\"; filename=\"profile.jpg\""))
        #expect(body.contains("Content-Type: image/jpeg"))
        #expect(request.body.range(of: jpeg) != nil)
    }

    @Test("SPEC-002 CA-10 patches only photoMediaId on the profile")
    func setPhoto() async throws {
        let stub = StubHTTP.make(status: 200, json: #"{"photoMediaId":"media-1"}"#)

        try await stub.repository.setProfilePhoto(mediaID: "media-1", accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "PATCH")
        #expect(request.url.path == "/v1/me/profile")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body as NSDictionary == ["photoMediaId": "media-1"] as NSDictionary)
    }

    @Test("SPEC-002 CA-10 surfaces media refusals as failures")
    func uploadPhotoRefusal() async {
        let stub = StubHTTP.make(status: 413, json: #"{"code":"MEDIA_TOO_LARGE"}"#)

        await #expect(throws: FamilyError.rejected) {
            _ = try await stub.repository.uploadProfilePhoto(Data([1]), accessToken: "a")
        }
    }

    @Test("SPEC-002 CA-11 creates members sending the backend role wire value")
    func createMember() async throws {
        let stub = StubHTTP.make(
            status: 201,
            json: #"{"id":"\#(memberID)","name":"Joana","role":"kids","isFamilyCreator":false,"createdAt":"2026-10-06T12:00:00.000Z"}"#
        )

        let member = try await stub.repository.createMember(name: "Joana", role: .kid, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.url.path == "/v1/family/members")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body as NSDictionary == ["name": "Joana", "role": "kids"] as NSDictionary)
        #expect(member.role == .kid)
        #expect(member.id == UUID(uuidString: memberID))
    }

    @Test("SPEC-002 CA-11 issues an invite with an empty JSON object")
    func issueInvite() async throws {
        let inviteID = "00000000-0000-0000-0000-0000000000c1"
        let stub = StubHTTP.make(
            status: 201,
            json: #"{"inviteId":"\#(inviteID)","link":"https://x.test/i/1","password":"PW-1"}"#
        )

        let invite = try await stub.repository.issueInvite(memberID: UUID(uuidString: memberID)!, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.url.path == "/v1/family/members/\(memberID)/invites")
        #expect(String(decoding: request.body, as: UTF8.self) == "{}")
        #expect(invite.password == "PW-1")
        #expect(invite.link == "https://x.test/i/1")
    }

    @Test("MemberRole accepts both kid and kids on the wire")
    func roleDecoding() throws {
        let decoder = JSONDecoder()
        #expect(try decoder.decode(MemberRole.self, from: Data(#""kids""#.utf8)) == .kid)
        #expect(try decoder.decode(MemberRole.self, from: Data(#""kid""#.utf8)) == .kid)
        #expect(try String(decoding: JSONEncoder().encode(MemberRole.kid), as: UTF8.self) == #""kids""#)
    }

    private func expectCreateFamilyError(
        status: Int,
        json: String,
        _ expected: FamilyError,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        let stub = StubHTTP.make(status: status, json: json)
        await #expect(throws: expected, sourceLocation: sourceLocation) {
            _ = try await stub.repository.createFamily(command, installationProof: "proof")
        }
    }

    private var createdFamilyJSON: String {
        """
        {"family":{"id":"\(familyID)","name":"Casa Silva","timeZoneId":"America/Sao_Paulo","createdAt":"2026-10-06T12:00:00Z"},
        "member":{"id":"\(memberID)","name":"Maria Silva","nickname":null,"role":"administrator","isFamilyCreator":true},
        "session":{"sessionId":"\(sessionID)","memberId":"\(memberID)","familyId":"\(familyID)","role":"administrator",
        "isFamilyCreator":true,"accessToken":"access-1","accessTokenExpiresAt":"2026-10-06T12:15:00.000Z","refreshToken":"refresh-1"}}
        """
    }
}

struct CapturedRequest: Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data
}

/// Routes requests of one test to its own canned response, keyed by a unique host so tests can run in parallel.
final class StubHTTP: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registry: [String: StubHTTP] = [:]

    private let status: Int
    private let data: Data
    private let failure: URLError?
    private var captured: [CapturedRequest] = []
    let repository: HTTPFamilyRepository

    private init(status: Int, data: Data, failure: URLError?, host: String) {
        self.status = status
        self.data = data
        self.failure = failure
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        repository = HTTPFamilyRepository(
            baseURL: URL(string: "https://\(host)/v1")!,
            session: URLSession(configuration: configuration)
        )
    }

    static func make(status: Int = 200, json: String = "{}", failure: URLError? = nil) -> StubHTTP {
        let host = "stub-\(UUID().uuidString.lowercased()).test"
        let stub = StubHTTP(status: status, data: Data(json.utf8), failure: failure, host: host)
        lock.withLock { registry[host] = stub }
        return stub
    }

    static func stub(for host: String?) -> StubHTTP? {
        lock.withLock { host.flatMap { registry[$0] } }
    }

    func requests() -> [CapturedRequest] {
        Self.lock.withLock { captured }
    }

    fileprivate func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
        let url = request.url!
        Self.lock.withLock {
            captured.append(
                CapturedRequest(
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

private final class StubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = StubHTTP.stub(for: request.url?.host) else {
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

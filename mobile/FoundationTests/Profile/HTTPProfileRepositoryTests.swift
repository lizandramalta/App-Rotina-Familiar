import Foundation
@testable import FamilyRoutine
import Testing

struct HTTPProfileRepositoryTests {
    private let memberID = "00000000-0000-0000-0000-0000000000a1"
    private let awardID = "00000000-0000-0000-0000-0000000000e1"
    private let missionID = "00000000-0000-0000-0000-0000000000f1"

    private let profileJSON = """
    {"memberId":"00000000-0000-0000-0000-0000000000a1","name":"Maria Silva","familyName":"Família Silva",
    "nickname":"Mari","photoMediaId":"media-1","totalParticipations":7,
    "nextTier":{"code":"silver","requiredMissionCount":10,"remaining":3}}
    """

    @Test("SPEC-006 CA-01 GET /v1/me/profile decodes familyName, nickname, photo and next tier")
    func getOwnProfile() async throws {
        let stub = ProfileStubHTTP.make(status: 200, json: profileJSON)

        let profile = try await stub.repository.getOwnProfile(accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "GET")
        #expect(request.url.path == "/v1/me/profile")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        #expect(request.body.isEmpty)
        #expect(profile == OwnProfile(
            memberID: UUID(uuidString: memberID)!,
            name: "Maria Silva",
            familyName: "Família Silva",
            nickname: "Mari",
            photoMediaID: "media-1",
            totalParticipations: 7,
            nextTier: NextBadgeTier(code: .silver, requiredMissionCount: 10, remaining: 3)
        ))
    }

    @Test("SPEC-006 CA-01 decodes null nickname, null photo and null next tier (diamond)")
    func getOwnProfileNulls() async throws {
        let stub = ProfileStubHTTP.make(
            status: 200,
            json: """
            {"memberId":"\(memberID)","name":"Maria","familyName":"Casa","nickname":null,"photoMediaId":null,
            "totalParticipations":50,"nextTier":null}
            """
        )

        let profile = try await stub.repository.getOwnProfile(accessToken: "a")

        #expect(profile.nickname == nil)
        #expect(profile.photoMediaID == nil)
        #expect(profile.nextTier == nil)
    }

    @Test("SPEC-006 CA-02 PATCH sends only the fields that were set; unchanged ones are omitted")
    func updateOmitsUnchangedFields() async throws {
        let stub = ProfileStubHTTP.make(status: 200, json: profileJSON)

        let profile = try await stub.repository.updateOwnProfile(
            UpdateOwnProfileCommand(name: "Maria S.", nickname: .set("Mari")),
            accessToken: "access-1"
        )

        let request = try #require(stub.requests().first)
        #expect(request.method == "PATCH")
        #expect(request.url.path == "/v1/me/profile")
        #expect(request.headers["Content-Type"] == "application/json")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body as NSDictionary == ["name": "Maria S.", "nickname": "Mari"] as NSDictionary)
        #expect(profile.familyName == "Família Silva")
    }

    @Test("SPEC-006 CA-02 PATCH sends an explicit null to remove nickname and photo")
    func updateClearsWithExplicitNull() async throws {
        let stub = ProfileStubHTTP.make(status: 200, json: profileJSON)

        _ = try await stub.repository.updateOwnProfile(
            UpdateOwnProfileCommand(nickname: .clear, photoMediaID: .clear),
            accessToken: "a"
        )

        let request = try #require(stub.requests().first)
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(Set(body.keys) == ["nickname", "photoMediaId"])
        #expect(body["nickname"] is NSNull)
        #expect(body["photoMediaId"] is NSNull)
    }

    @Test("SPEC-006 CA-02 PATCH links a photo and an empty command sends an empty object")
    func updatePhotoAndEmpty() async throws {
        let stub = ProfileStubHTTP.make(status: 200, json: profileJSON)

        _ = try await stub.repository.updateOwnProfile(
            UpdateOwnProfileCommand(photoMediaID: .set("media-2")),
            accessToken: "a"
        )
        _ = try await stub.repository.updateOwnProfile(UpdateOwnProfileCommand(), accessToken: "a")

        let requests = stub.requests()
        let first = try #require(JSONSerialization.jsonObject(with: requests[0].body) as? [String: Any])
        #expect(first as NSDictionary == ["photoMediaId": "media-2"] as NSDictionary)
        #expect(String(decoding: requests[1].body, as: UTF8.self) == "{}")
    }

    @Test("SPEC-006 CA-10 GET /v1/me/badges decodes awards with and without fractional seconds")
    func getOwnBadges() async throws {
        let stub = ProfileStubHTTP.make(
            status: 200,
            json: """
            {"totalParticipations":12,"nextTier":{"code":"gold","requiredMissionCount":25,"remaining":13},
            "awards":[
            {"awardId":"\(awardID)","tier":"bronze","requiredMissionCount":5,"awardedAt":"2026-09-20T12:00:00Z"},
            {"awardId":"00000000-0000-0000-0000-0000000000e2","tier":"silver","requiredMissionCount":10,"awardedAt":"2026-10-01T12:00:00.250Z"}]}
            """
        )

        let overview = try await stub.repository.getOwnBadges(accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.url.path == "/v1/me/badges")
        #expect(overview.totalParticipations == 12)
        #expect(overview.nextTier == NextBadgeTier(code: .gold, requiredMissionCount: 25, remaining: 13))
        #expect(overview.awards.map(\.tier) == [.bronze, .silver])
        #expect(overview.awards[0].awardID == UUID(uuidString: awardID))
        #expect(overview.awards[0].awardedAt == Date(timeIntervalSince1970: 1_789_905_600))
        #expect(overview.awards[1].awardedAt.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) == 0.25)
    }

    @Test("SPEC-006 CA-11 GET /v1/me/badges/{awardId} decodes the contributing missions")
    func getBadgeDetail() async throws {
        let stub = ProfileStubHTTP.make(
            status: 200,
            json: """
            {"awardId":"\(awardID)","tier":"bronze","awardedAt":"2026-09-20T12:00:00Z",
            "contributingMissions":[{"missionId":"\(missionID)","title":"Organizar a sala","completedAt":"2026-09-18T20:00:00Z"}]}
            """
        )

        let detail = try await stub.repository.getBadgeDetail(awardID: UUID(uuidString: awardID)!, accessToken: "a")

        let request = try #require(stub.requests().first)
        #expect(request.url.path == "/v1/me/badges/\(awardID)")
        #expect(detail.tier == .bronze)
        #expect(detail.contributingMissions == [
            ContributingMission(
                missionID: UUID(uuidString: missionID)!,
                title: "Organizar a sala",
                completedAt: Date(timeIntervalSince1970: 1_789_761_600)
            ),
        ])
    }

    @Test("SPEC-006 CA-11 a null completedAt falls back to the award date instead of failing the whole detail")
    func badgeDetailNullCompletion() async throws {
        let stub = ProfileStubHTTP.make(
            status: 200,
            json: """
            {"awardId":"\(awardID)","tier":"bronze","awardedAt":"2026-09-20T12:00:00Z",
            "contributingMissions":[{"missionId":"\(missionID)","title":"Sala","completedAt":null}]}
            """
        )

        let detail = try await stub.repository.getBadgeDetail(awardID: UUID(uuidString: awardID)!, accessToken: "a")

        #expect(detail.contributingMissions.first?.completedAt == detail.awardedAt)
    }

    @Test("SPEC-006 uploads the profile photo as multipart and returns the READY media id")
    func uploadPhoto() async throws {
        let stub = ProfileStubHTTP.make(status: 201, json: #"{"mediaId":"media-9","state":"READY","width":10,"height":10}"#)
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

        let mediaID = try await stub.repository.uploadProfilePhoto(jpeg, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(mediaID == "media-9")
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/media")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        #expect(try #require(request.headers["Content-Type"]).hasPrefix("multipart/form-data; boundary="))
        let body = String(decoding: request.body, as: UTF8.self)
        #expect(body.contains("name=\"purpose\"\r\n\r\nprofilePhoto"))
        #expect(body.contains("Content-Type: image/jpeg"))
        #expect(request.body.range(of: jpeg) != nil)
    }

    @Test("SPEC-006 a photo that is not READY yet is not returned as linkable")
    func uploadNotReady() async {
        let stub = ProfileStubHTTP.make(status: 201, json: #"{"mediaId":"media-9","state":"UPLOADING","width":1,"height":1}"#)

        await #expect(throws: ProfileError.unavailable) {
            _ = try await stub.repository.uploadProfilePhoto(Data([1]), accessToken: "a")
        }
    }

    @Test("SPEC-006 CA-15 GET /v1/media/{id}/content returns the bytes")
    func getMediaContent() async throws {
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x01])
        let stub = ProfileStubHTTP.make(status: 200, data: bytes)

        let data = try await stub.repository.getMediaContent(mediaID: "media-1", accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(data == bytes)
        #expect(request.method == "GET")
        #expect(request.url.path == "/v1/media/media-1/content")
        #expect(request.headers["Authorization"] == "Bearer access-1")
    }

    @Test("SPEC-006 CA-15 an empty 200 body is not a photo")
    func getMediaContentEmpty() async {
        let stub = ProfileStubHTTP.make(status: 200, data: Data())

        await #expect(throws: ProfileError.unavailable) {
            _ = try await stub.repository.getMediaContent(mediaID: "m", accessToken: "a")
        }
    }

    @Test("maps HTTP statuses to profile errors", arguments: [
        (401, #"{"code":"SESSION_EXPIRED"}"#, ProfileError.unauthorized),
        (403, #"{"code":"ACTION_NOT_ALLOWED"}"#, ProfileError.actionNotAllowed),
        (404, #"{"code":"RESOURCE_NOT_FOUND"}"#, ProfileError.notFound),
        (413, #"{"code":"MEDIA_TOO_LARGE"}"#, ProfileError.mediaTooLarge),
        (415, #"{"code":"MEDIA_FORMAT_UNSUPPORTED"}"#, ProfileError.mediaFormatUnsupported),
        (429, #"{"code":"RATE_LIMIT_EXCEEDED"}"#, ProfileError.rateLimited),
        (400, #"{"code":"UNKNOWN_FIELD"}"#, ProfileError.rejected),
        (503, #"{"code":"DEPENDENCY_UNAVAILABLE"}"#, ProfileError.unavailable),
        (500, "{}", ProfileError.unavailable),
        (
            422,
            #"{"code":"VALIDATION_FAILED","fieldErrors":{"name":["NAME_INVALID_LENGTH"]}}"#,
            ProfileError.validationFailed(["name": ["NAME_INVALID_LENGTH"]])
        ),
        (
            422,
            #"{"code":"VALIDATION_FAILED","fieldErrors":{"nickname":["NICKNAME_INVALID_LENGTH"]}}"#,
            ProfileError.validationFailed(["nickname": ["NICKNAME_INVALID_LENGTH"]])
        ),
        (
            422,
            #"{"code":"PHOTO_MEDIA_NOT_OWNED"}"#,
            ProfileError.validationFailed(["photoMediaId": ["PHOTO_MEDIA_NOT_OWNED"]])
        ),
        (
            422,
            #"{"code":"PHOTO_MEDIA_NOT_READY"}"#,
            ProfileError.validationFailed(["photoMediaId": ["PHOTO_MEDIA_NOT_READY"]])
        ),
    ])
    func errorMapping(status: Int, json: String, expected: ProfileError) async {
        let stub = ProfileStubHTTP.make(status: status, json: json)

        await #expect(throws: expected) {
            _ = try await stub.repository.updateOwnProfile(UpdateOwnProfileCommand(name: "x"), accessToken: "a")
        }
    }

    @Test("a network failure is .network and an unreadable 200 is .unavailable")
    func networkAndDecoding() async {
        let offline = ProfileStubHTTP.make(failure: URLError(.notConnectedToInternet))
        await #expect(throws: ProfileError.network) {
            _ = try await offline.repository.getOwnProfile(accessToken: "a")
        }

        let broken = ProfileStubHTTP.make(status: 200, json: "{}")
        await #expect(throws: ProfileError.unavailable) {
            _ = try await broken.repository.getOwnProfile(accessToken: "a")
        }
    }

    @Test("errors are mapped on GET routes too")
    func errorsOnGet() async {
        let stub = ProfileStubHTTP.make(status: 404, json: #"{"code":"RESOURCE_NOT_FOUND"}"#)
        await #expect(throws: ProfileError.notFound) {
            _ = try await stub.repository.getBadgeDetail(awardID: UUID(), accessToken: "a")
        }
        await #expect(throws: ProfileError.notFound) {
            _ = try await stub.repository.getMediaContent(mediaID: "m", accessToken: "a")
        }
    }
}

/// Routes the requests of one test to its own canned response, keyed by a unique host so tests can run in parallel.
final class ProfileStubHTTP: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registry: [String: ProfileStubHTTP] = [:]

    private let status: Int
    private let data: Data
    private let failure: URLError?
    private var captured: [CapturedRequest] = []
    let repository: HTTPProfileRepository

    private init(status: Int, data: Data, failure: URLError?, host: String) {
        self.status = status
        self.data = data
        self.failure = failure
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProfileStubURLProtocol.self]
        repository = HTTPProfileRepository(
            baseURL: URL(string: "https://\(host)/v1")!,
            session: URLSession(configuration: configuration)
        )
    }

    static func make(status: Int = 200, json: String = "{}", failure: URLError? = nil) -> ProfileStubHTTP {
        make(status: status, data: Data(json.utf8), failure: failure)
    }

    static func make(status: Int = 200, data: Data, failure: URLError? = nil) -> ProfileStubHTTP {
        let host = "profile-stub-\(UUID().uuidString.lowercased()).test"
        let stub = ProfileStubHTTP(status: status, data: data, failure: failure, host: host)
        lock.withLock { registry[host] = stub }
        return stub
    }

    static func stub(for host: String?) -> ProfileStubHTTP? {
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

private final class ProfileStubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = ProfileStubHTTP.stub(for: request.url?.host) else {
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

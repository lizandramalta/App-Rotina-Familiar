import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-017 §5.1/§5.2 — `POST /v1/missions/{missionId}/reward-acceptance` (SCRUM-90, decisão R-1).
struct RewardAcceptanceHTTPTests {
    private let missionID = UUID(uuidString: "00000000-0000-0000-0000-0000000000e1")!
    private let itemID = UUID(uuidString: "00000000-0000-0000-0000-0000000000f6")!

    private var acceptedJSON: String {
        """
        {"id":"\(missionID.uuidString.lowercased())","familyId":"00000000-0000-0000-0000-0000000000f1",
        "title":"Semana organizada","note":null,"status":"completed","taskIds":[],
        "completedAt":"2026-10-08T12:00:00Z","isRedemptionAvailable":false,
        "acceptedReward":{"rewardItemId":"\(itemID.uuidString.lowercased())","title":"Noite de pizza",
        "details":"Escolher juntos o sabor e o filme","source":"custom","acceptedAt":"2026-10-08T13:00:00.000Z"},
        "createdAt":"2026-10-07T15:00:00Z"}
        """
    }

    @Test("CA-08 sends only rewardItemId and returns the accepted snapshot of the 200")
    func acceptsReward() async throws {
        let stub = MissionStubHTTP.make(status: 200, json: acceptedJSON)

        let accepted = try await stub.repository.acceptReward(missionID: missionID, rewardItemID: itemID, accessToken: "access-1")

        let request = try #require(stub.requests().first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/missions/\(missionID.uuidString.lowercased())/reward-acceptance")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body as NSDictionary == ["rewardItemId": itemID.uuidString] as NSDictionary)
        #expect(accepted == AcceptedMissionReward(rewardItemID: itemID, title: "Noite de pizza"))
    }

    @Test("R-1 maps definitive conflicts and refusals", arguments: [
        (409, "MISSION_REWARD_ALREADY_ACCEPTED", RewardAcceptanceError.alreadyAccepted),
        (409, "MISSION_REWARD_REDEMPTION_UNAVAILABLE", .unavailable),
        (404, "RESOURCE_NOT_FOUND", .unavailable),
        (403, "INSUFFICIENT_PERMISSIONS", .unavailable),
        (422, "REWARD_ITEM_NOT_ELIGIBLE", .rejected),
        (401, "SESSION_EXPIRED", .rejected),
        (503, "DEPENDENCY_UNAVAILABLE", .uncertain),
    ])
    func mapsErrors(status: Int, code: String, expected: RewardAcceptanceError) async {
        let stub = MissionStubHTTP.make(status: status, json: #"{"code":"\#(code)"}"#)

        await #expect(throws: expected) {
            _ = try await stub.repository.acceptReward(missionID: missionID, rewardItemID: itemID, accessToken: "a")
        }
    }

    @Test("CA-07 a lost response is uncertain, never a confirmed accept")
    func lostResponseIsUncertain() async {
        let stub = MissionStubHTTP.make(failure: URLError(.timedOut))

        await #expect(throws: RewardAcceptanceError.uncertain) {
            _ = try await stub.repository.acceptReward(missionID: missionID, rewardItemID: itemID, accessToken: "a")
        }
    }

    @Test("CA-07 a 200 without a readable snapshot is uncertain")
    func unreadableSuccessIsUncertain() async {
        let stub = MissionStubHTTP.make(status: 200, json: #"{"id":"x"}"#)

        await #expect(throws: RewardAcceptanceError.uncertain) {
            _ = try await stub.repository.acceptReward(missionID: missionID, rewardItemID: itemID, accessToken: "a")
        }
    }
}

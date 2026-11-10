import Foundation

/// Reads the APNs payload of a weekly recognition: only `type` and `recognitionId` (SPEC-020 §5).
/// The id alone authorizes nothing; TEL-052 always refetches it with a valid session.
nonisolated enum WeeklyRecognitionNotification {
    static let type = "weeklyRecognition"

    static func recognitionID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard userInfo["type"] as? String == type,
              let rawID = userInfo["recognitionId"] as? String else { return nil }
        return UUID(uuidString: rawID)
    }
}

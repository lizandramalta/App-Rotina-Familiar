import Foundation
@testable import FamilyRoutine
import Testing

/// Internal access from Minhas tarefas (UX-020 §1, E-1) and notification routing — SCRUM-103.
@MainActor
struct WeeklyRecognitionEntryTests {
    private static let iso = ISO8601DateFormatter()

    private func makeEntry(
        list: [Result<[WeeklyRecognition], RecognitionError>],
        now: String,
        session: RecognitionSessionStub = RecognitionSessionStub()
    ) -> WeeklyRecognitionEntryViewModel {
        WeeklyRecognitionEntryViewModel(
            getRecognition: GetOwnWeeklyRecognitionUseCase(
                repository: RecognitionRepositorySpy(list: list),
                session: session
            ),
            now: { Self.iso.date(from: now)! }
        )
    }

    @Test("E-1 the latest result is featured during the week after its cycle, without any push")
    func featuredDuringFollowingWeek() async {
        let entry = makeEntry(list: [.success([RecognitionFixtures.recognition()])], now: "2026-10-08T12:00:00Z")

        await entry.refresh()

        #expect(entry.featured?.id == RecognitionFixtures.id)
    }

    @Test("E-1 the card disappears once the following week ends (Monday 00:00 local)")
    func hiddenAfterFollowingWeek() async {
        let entry = makeEntry(list: [.success([RecognitionFixtures.recognition()])], now: "2026-10-12T03:00:00Z")

        await entry.refresh()

        #expect(entry.featured == nil)
    }

    @Test("E-1 the last instant of the following week is still featured")
    func featuredUntilLastInstant() async {
        let entry = makeEntry(list: [.success([RecognitionFixtures.recognition()])], now: "2026-10-12T02:59:59Z")

        await entry.refresh()

        #expect(entry.featured != nil)
    }

    @Test("E-1 only the most recent cycle is considered")
    func usesMostRecentCycle() async {
        let older = RecognitionFixtures.recognition(
            id: UUID(),
            endsAt: RecognitionFixtures.endsAt.addingTimeInterval(-7 * 86_400)
        )
        let entry = makeEntry(list: [.success([older, RecognitionFixtures.recognition()])], now: "2026-10-06T12:00:00Z")

        await entry.refresh()

        #expect(entry.featured?.id == RecognitionFixtures.id)
    }

    @Test("a transient failure keeps the confirmed card; no result means no card")
    func failureKeepsCard() async {
        let entry = makeEntry(
            list: [.success([RecognitionFixtures.recognition()]), .failure(.network), .success([])],
            now: "2026-10-08T12:00:00Z"
        )

        await entry.refresh()
        await entry.refresh()
        #expect(entry.featured != nil)

        await entry.refresh()
        #expect(entry.featured == nil)
    }

    @Test("an unrecoverable session hides the card")
    func sessionExpiredHidesCard() async {
        let entry = makeEntry(
            list: [.success([RecognitionFixtures.recognition()]), .failure(.sessionExpired)],
            now: "2026-10-08T12:00:00Z",
            session: RecognitionSessionStub(token: "a", recoveredToken: nil)
        )

        await entry.refresh()
        await entry.refresh()

        #expect(entry.featured == nil)
    }

    @Test("APNs payload: only weeklyRecognition with a valid id opens TEL-052")
    func parsesNotificationPayload() {
        let id = RecognitionFixtures.id.uuidString.lowercased()

        #expect(WeeklyRecognitionNotification.recognitionID(from: ["type": "weeklyRecognition", "recognitionId": id])
            == RecognitionFixtures.id)
        #expect(WeeklyRecognitionNotification.recognitionID(from: ["type": "familyApplause", "recognitionId": id]) == nil)
        #expect(WeeklyRecognitionNotification.recognitionID(from: ["type": "weeklyRecognition", "recognitionId": "x"]) == nil)
        #expect(WeeklyRecognitionNotification.recognitionID(from: ["type": "weeklyRecognition"]) == nil)
    }

    @Test("a pending notification waits for an authenticated stack and is consumed once")
    func routerConsumesOnce() {
        let router = RecognitionNotificationRouter()
        router.receive(RecognitionFixtures.id)

        #expect(router.pendingRecognitionID == RecognitionFixtures.id)
        #expect(router.consume() == RecognitionFixtures.id)
        #expect(router.consume() == nil)
    }
}

import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct FamilyTasksViewModelTests {
    private let range = FamilyDateRange(startDate: "2026-10-26", endDate: "2026-10-31")

    private func makeRepository(
        role: MemberRole = .administrator,
        memberID: UUID = UUID()
    ) -> (FamilyRepositorySpy, UUID) {
        let repository = FamilyRepositorySpy()
        let overview = FamilyOverview(
            range: range,
            familyCreatedAt: "2026-10-01",
            progress: FamilyProgress(
                total: 25, completed: 17, pending: role == .administrator ? 6 : 8,
                awaitingConfirmation: role == .administrator ? 2 : 0, percentage: 68
            ),
            members: [
                FamilyMemberProgress(
                    memberID: memberID, name: "Maria", role: role,
                    progress: FamilyProgress(
                        total: 10, completed: 7, pending: role == .administrator ? 2 : 3,
                        awaitingConfirmation: role == .administrator ? 1 : 0, percentage: 70
                    )
                ),
            ]
        )
        let item = FamilyTaskItem(
            task: FamilyTask(
                id: UUID(), title: "Regar as plantas", weight: .low,
                scheduledDate: "2026-10-28", assigneeIDs: [memberID], note: nil,
                status: .pending, routineID: nil, createdAt: .now
            ),
            displayStatus: .pending
        )
        repository.setFamilyOverviewResult(.success(overview))
        repository.setFamilyTaskPageResult(.success(
            FamilyTaskPage(range: range, items: [item], nextCursor: "next")
        ))
        return (repository, memberID)
    }

    @Test("SPEC-009 CA-06/12: TEL-011 group counts use the full overview, not the first page")
    func countsAcrossPages() async {
        let (repository, memberID) = makeRepository()
        let model = FamilyTasksViewModel(
            range: range, memberID: nil, currentMemberID: memberID,
            role: .administrator, familyCreatedAt: "2026-10-01",
            familyRepository: repository, accessTokenProvider: { "token" }
        )

        await model.load()

        #expect(model.items.count == 1)
        #expect(model.nextCursor == "next")
        #expect(model.count(for: .all) == 25)
        #expect(model.count(for: .pending) == 6)
        #expect(model.count(for: .awaitingConfirmation) == 2)
        #expect(model.count(for: .completed) == 17)
    }

    @Test("SPEC-009 CA-07/12: member preview uses role-projected totals for the selected person")
    func memberPreviewAndRoleProjection() async throws {
        let (repository, memberID) = makeRepository(role: .member)
        let model = FamilyTasksViewModel(
            range: range, memberID: memberID, role: .member,
            familyCreatedAt: "2026-10-01",
            familyRepository: repository, accessTokenProvider: { "token" }
        )

        #expect(!model.availableStatuses.contains(.awaitingConfirmation))
        #expect(try await model.previewCount(range: range, status: .pending) == 3)
        #expect(try await model.previewCount(range: range, status: .all) == 10)
    }
}

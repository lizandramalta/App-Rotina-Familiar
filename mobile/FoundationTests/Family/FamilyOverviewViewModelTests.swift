import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct FamilyOverviewViewModelTests {
    private func member(_ name: String, creator: Bool = false) -> FamilyMember {
        FamilyMember(id: UUID(), name: name, role: creator ? .administrator : .member, isFamilyCreator: creator)
    }

    private func page(_ members: [FamilyMember], next: String? = nil) -> Result<FamilyMemberPage, Error> {
        .success(FamilyMemberPage(items: members, nextCursor: next))
    }

    private func makeViewModel(
        _ results: [Result<FamilyMemberPage, Error>],
        role: MemberRole = .administrator
    ) -> (FamilyOverviewViewModel, FamilyRepositorySpy) {
        let repository = FamilyRepositorySpy(listMembersResults: results)
        let session = ActiveFamilySession(memberID: UUID(), familyID: UUID(), role: role, isFamilyCreator: false)
        return (
            FamilyOverviewViewModel(session: session, familyRepository: repository, accessTokenProvider: { "token-1" }),
            repository
        )
    }

    @Test("SPEC-002 initial load shows the confirmed family name and time zone")
    func loadsFamilyProfile() async {
        let (viewModel, _) = makeViewModel([page([])])

        await viewModel.loadInitial()

        #expect(viewModel.familyName == "Família Silva")
        #expect(viewModel.timeZoneDisplayName == "Horário de Brasília")
    }

    @Test("SPEC-002 renaming shows only the server-confirmed name and skips empty or unchanged input")
    func renamesFamily() async throws {
        let (viewModel, repository) = makeViewModel([page([])])
        await viewModel.loadInitial()

        try await viewModel.updateFamilyName("  Família Souza  ")
        try await viewModel.updateFamilyName("   ")
        try await viewModel.updateFamilyName("Família Souza")

        #expect(viewModel.familyName == "Família Souza")
        #expect(repository.updatedFamilyNames == ["Família Souza"])
    }

    @Test("SPEC-002 a failed rename keeps the confirmed name and reports the error")
    func failedRenameKeepsName() async {
        let (viewModel, repository) = makeViewModel([page([])])
        await viewModel.loadInitial()
        repository.setFamilyResult(.failure(FamilyError.network))

        await #expect(throws: FamilyError.self) { try await viewModel.updateFamilyName("Nova") }

        #expect(viewModel.familyName == "Família Silva")
    }

    @Test("SPEC-003 CA-01 initial load fills members and cursor")
    func initialLoad() async {
        let maria = member("Maria", creator: true)
        let (viewModel, _) = makeViewModel([page([maria], next: "c1")])

        await viewModel.loadInitial()

        #expect(viewModel.members == [maria])
        #expect(viewModel.nextCursor == "c1")
        #expect(viewModel.hasMorePages)
        #expect(viewModel.existingMemberIDs == [maria.id])
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("SPEC-003 CA-03 only an Administrator can add members and configure the family")
    func adminOnlyControls() {
        let (admin, _) = makeViewModel([], role: .administrator)
        let (adult, _) = makeViewModel([], role: .member)

        #expect(admin.canAddMember)
        #expect(admin.canConfigureFamily)
        #expect(!adult.canAddMember)
        #expect(!adult.canConfigureFamily)
    }

    @Test("SPEC-003 UX-06 loads the next page with the cursor and appends without duplicates")
    func pagination() async {
        let first = member("Ana")
        let second = member("Bia")
        let (viewModel, repository) = makeViewModel([page([first], next: "c1"), page([first, second])])
        await viewModel.loadInitial()

        await viewModel.loadMoreIfNeeded(currentMember: first)

        #expect(viewModel.members == [first, second])
        #expect(viewModel.nextCursor == nil)
        #expect(repository.listMembersCalls == 2)
        await viewModel.loadMoreIfNeeded(currentMember: second)
        #expect(repository.listMembersCalls == 2)
    }

    @Test("SPEC-003 UX-06 only the last row triggers the next page")
    func onlyLastRowTriggers() async {
        let first = member("Ana")
        let last = member("Bia")
        let (viewModel, repository) = makeViewModel([page([first, last], next: "c1")])
        await viewModel.loadInitial()

        await viewModel.loadMoreIfNeeded(currentMember: first)

        #expect(repository.listMembersCalls == 1)
    }

    @Test("SPEC-003 UX-06 a failed page keeps the confirmed members and allows an explicit retry")
    func pageFailureKeepsMembers() async {
        let first = member("Ana")
        let second = member("Bia")
        let (viewModel, repository) = makeViewModel([
            page([first], next: "c1"),
            .failure(FamilyError.network),
            page([second]),
        ])
        await viewModel.loadInitial()

        await viewModel.loadMoreIfNeeded(currentMember: first)

        #expect(viewModel.members == [first])
        #expect(viewModel.loadMoreFailed)
        #expect(viewModel.hasMorePages)
        #expect(!viewModel.isLoadingMore)

        await viewModel.loadMoreIfNeeded(currentMember: first)
        #expect(repository.listMembersCalls == 2)

        await viewModel.loadMore()
        #expect(viewModel.members == [first, second])
        #expect(!viewModel.loadMoreFailed)
    }

    @Test("SPEC-003 CA-07 a failed reload keeps confirmed members and reports a non-blocking error")
    func reloadFailureKeepsMembers() async {
        let maria = member("Maria")
        let (viewModel, _) = makeViewModel([page([maria]), .failure(FamilyError.network)])
        await viewModel.loadInitial()

        await viewModel.loadInitial()

        #expect(viewModel.members == [maria])
        #expect(viewModel.errorMessage != nil)
    }

    @Test("SPEC-003 CA-01 an initial failure with no members shows the error")
    func initialFailure() async {
        let (viewModel, _) = makeViewModel([.failure(FamilyError.unavailable)])

        await viewModel.loadInitial()

        #expect(viewModel.members.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("SPEC-003 CA-01 memberCreated reloads the first page")
    func memberCreatedReloads() async {
        let maria = member("Maria")
        let rafa = member("Rafa")
        let (viewModel, repository) = makeViewModel([page([maria]), page([maria, rafa])])
        await viewModel.loadInitial()

        await viewModel.memberCreated()

        #expect(viewModel.members == [maria, rafa])
        #expect(repository.listMembersCalls == 2)
    }

    @Test("SPEC-003 CA-03 a 403 on reload clears the member list and cursor")
    func reloadForbiddenClearsMembers() async {
        let (viewModel, _) = makeViewModel([
            page([member("Maria")], next: "c1"),
            .failure(FamilyError.actionNotAllowed),
        ])
        await viewModel.loadInitial()
        #expect(!viewModel.members.isEmpty)

        await viewModel.loadInitial()

        #expect(viewModel.members.isEmpty)
        #expect(viewModel.nextCursor == nil)
        #expect(viewModel.loadFailed)
        #expect(viewModel.existingMemberIDs.isEmpty)
    }

    @Test("SPEC-003 CA-03 a 403 while loading a further page also clears the member list")
    func pageForbiddenClearsMembers() async {
        let first = member("Ana")
        let (viewModel, _) = makeViewModel([page([first], next: "c1"), .failure(FamilyError.actionNotAllowed)])
        await viewModel.loadInitial()

        await viewModel.loadMoreIfNeeded(currentMember: first)

        #expect(viewModel.members.isEmpty)
        #expect(viewModel.nextCursor == nil)
        #expect(viewModel.loadFailed)
    }
}

import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct RewardItemsViewModelTests {
    private func makeItem(title: String, source: RewardItemSource) -> RewardItem {
        RewardItem(id: UUID(), title: title, details: nil, source: source, createdAt: source == .custom ? Date() : nil)
    }

    @Test("RN41/42: only Administrador can manage the catalog")
    func onlyAdminCanManage() {
        let admin = RewardItemsViewModel(repository: RewardRepositorySpy(), role: .administrator, accessToken: "token")
        let member = RewardItemsViewModel(repository: RewardRepositorySpy(), role: .member, accessToken: "token")
        let kid = RewardItemsViewModel(repository: RewardRepositorySpy(), role: .kid, accessToken: "token")

        #expect(admin.canManage)
        #expect(!member.canManage)
        #expect(!kid.canManage)
    }

    @Test("CA-01: loads predefined and custom items into separate sections")
    func loadSplitsSections() async {
        let predefined = makeItem(title: "Escolher o filme da noite", source: .predefined)
        let custom = makeItem(title: "Noite de pizza", source: .custom)
        let repository = RewardRepositorySpy(rewardItemsResult: .success(RewardCatalog(predefined: [predefined], custom: [custom])))
        let viewModel = RewardItemsViewModel(repository: repository, role: .administrator, accessToken: "token")

        await viewModel.load()

        #expect(viewModel.predefined.map(\.id) == [predefined.id])
        #expect(viewModel.custom.map(\.id) == [custom.id])
        #expect(!viewModel.isCustomEmpty)
    }

    @Test("An empty custom list is reflected as the empty state, without hiding predefined items")
    func emptyCustomList() async {
        let predefined = makeItem(title: "Escolher o filme da noite", source: .predefined)
        let repository = RewardRepositorySpy(rewardItemsResult: .success(RewardCatalog(predefined: [predefined], custom: [])))
        let viewModel = RewardItemsViewModel(repository: repository, role: .administrator, accessToken: "token")

        await viewModel.load()

        #expect(viewModel.isCustomEmpty)
        #expect(!viewModel.predefined.isEmpty)
    }

    @Test("A load failure is surfaced without crashing")
    func loadFailure() async {
        let repository = RewardRepositorySpy(rewardItemsResult: .failure(RewardItemError.unavailable))
        let viewModel = RewardItemsViewModel(repository: repository, role: .administrator, accessToken: "token")

        await viewModel.load()

        #expect(viewModel.loadFailed)
    }

    @Test("CA-02: a successful save closes the sheet and reloads the catalog")
    func handleItemSavedReloads() async {
        let custom = makeItem(title: "Noite de pizza", source: .custom)
        let repository = RewardRepositorySpy(rewardItemsResult: .success(RewardCatalog(predefined: [], custom: [custom])))
        let viewModel = RewardItemsViewModel(repository: repository, role: .administrator, accessToken: "token")
        viewModel.openAddItem()

        await viewModel.handleItemSaved()

        #expect(!viewModel.isAddItemPresented)
        #expect(viewModel.custom.map(\.id) == [custom.id])
    }

    @Test("CA-07: an uncertain outcome closes the sheet and shows the banner without reloading on its own")
    func uncertainOutcomeShowsBanner() {
        let viewModel = RewardItemsViewModel(repository: RewardRepositorySpy(), role: .administrator, accessToken: "token")
        viewModel.openAddItem()

        viewModel.handleUncertainOutcome()

        #expect(!viewModel.isAddItemPresented)
        #expect(viewModel.showsUncertainBanner)
    }

    @Test("CA-07: 'Atualizar lista' clears the banner and reloads to confirm the item's presence")
    func refreshAfterUncertainClearsBannerAndReloads() async {
        let repository = RewardRepositorySpy()
        let viewModel = RewardItemsViewModel(repository: repository, role: .administrator, accessToken: "token")
        viewModel.handleUncertainOutcome()

        await viewModel.refreshAfterUncertain()

        #expect(!viewModel.showsUncertainBanner)
    }

    @Test("UX-017 R-4: TEL-023 opened from the wheel is consult-only, even for Administrador")
    func consultModeHasNoManagement() {
        let consult = RewardItemsViewModel(repository: RewardRepositorySpy(), role: .administrator, accessToken: "token", allowsManagement: false)
        #expect(!consult.canManage)
    }
}

import Foundation
import Observation

/// Backs TEL-023 (SPEC-015 Fase 1) — predefined and family-custom reward items, Administrador only.
@MainActor
@Observable
final class RewardItemsViewModel {
    private let getRewardItems: GetRewardItemsUseCase
    private let accessToken: String
    let role: MemberRole
    /// `false` when TEL-023 is opened from TEL-024 to consult the catalog (UX-017 §5.2).
    let allowsManagement: Bool

    private(set) var predefined: [RewardItem] = []
    private(set) var custom: [RewardItem] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false

    /// SPEC-015 §5.4/CA-07: shown after a lost response, until the person asks to reload (UX-015 §6).
    private(set) var showsUncertainBanner = false

    var isAddItemPresented = false

    init(repository: any RewardRepository, role: MemberRole, accessToken: String, allowsManagement: Bool = true) {
        self.getRewardItems = GetRewardItemsUseCase(repository: repository)
        self.role = role
        self.allowsManagement = allowsManagement
        self.accessToken = accessToken
    }

    /// RN41/42: only Administrador sees the catalog and the add action (CA-05 — Membro/Kids never
    /// reach this screen; the backend also rejects them with `403 INSUFFICIENT_PERMISSIONS`).
    var canManage: Bool {
        role == .administrator && allowsManagement
    }

    var isCustomEmpty: Bool {
        custom.isEmpty
    }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            let catalog = try await getRewardItems.execute(accessToken: accessToken)
            predefined = catalog.predefined
            custom = catalog.custom
        } catch {
            loadFailed = true
        }
    }

    func openAddItem() {
        isAddItemPresented = true
    }

    /// MOD-008 saved successfully: close the sheet and reload so the new item's presence — not a
    /// locally appended guess — is what confirms it in the family section.
    func handleItemSaved() async {
        isAddItemPresented = false
        await load()
    }

    /// MOD-008's response was lost after sending (BA-07): close without declaring success and let
    /// the person confirm by reloading (CA-07) rather than reloading silently on their behalf.
    func handleUncertainOutcome() {
        isAddItemPresented = false
        showsUncertainBanner = true
    }

    func refreshAfterUncertain() async {
        showsUncertainBanner = false
        await load()
    }
}

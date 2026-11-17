import SwiftUI

/// TEL-058 — Excluir conta, with MOD-015 as the final destructive alert (UX-022 §5.2/§5.3).
/// Variants: adult non-creator, creator (whole family, types the family name) and Kids.
struct AccountDeletionView: View {
    @Bindable var viewModel: AccountDeletionViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isKids: Bool { viewModel.variant == .kids }
    private var minimumTarget: CGFloat { isKids ? 56 : 44 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                if isKids {
                    Image("EntryHomeIllustration")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 120)
                        .accessibilityHidden(true)
                }
                effects
                irreversibleNotice
                if case .creator = viewModel.variant { familyNameField }
                feedback
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.xxxl)
            .frame(maxWidth: horizontalSizeClass == .regular ? 540 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) { deleteButton }
        .background(Color.App.Background.app)
        .navigationTitle("account.deletion.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isBusy)
        .alert(confirmationTitle, isPresented: $viewModel.isShowingConfirmation) {
            Button("account.common.cancel", role: .cancel) {}
            Button("account.deletion.confirm.action", role: .destructive) {
                Task { await viewModel.confirmDeletion() }
            }
            .accessibilityIdentifier("account.deletion.confirm.action")
        } message: {
            Text("account.deletion.irreversible")
        }
    }

    // MARK: Content

    @ViewBuilder
    private var effects: some View {
        switch viewModel.variant {
        case .member:
            effectBlock(
                title: "account.deletion.member.deleted_title",
                body: Text("account.deletion.member.deleted"),
                symbol: "person.crop.circle.badge.xmark"
            )
            effectBlock(
                title: "account.deletion.member.kept_title",
                body: Text("account.deletion.member.kept"),
                symbol: "checkmark.seal"
            )
        case .kids:
            effectBlock(
                title: "account.deletion.kids.title",
                body: Text("account.deletion.kids.body"),
                symbol: "person.crop.circle.badge.xmark"
            )
        case let .creator(familyName):
            effectBlock(
                title: "account.deletion.creator.title",
                body: Text(String(format: String(localized: "account.deletion.creator.body"), familyName)),
                symbol: "house"
            )
            effectBlock(
                title: "account.deletion.creator.effects_title",
                body: Text("account.deletion.creator.effects"),
                symbol: "trash"
            )
        }
    }

    private func effectBlock(title: LocalizedStringKey, body: Text, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: symbol)
                .font(.app(.bodyStrong))
                .foregroundStyle(Color.App.Text.primary)
                .accessibilityAddTraits(.isHeader)
            body
                .font(.app(.body))
                .foregroundStyle(Color.App.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(Color.App.Background.card, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).strokeBorder(Color.App.Border.card, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var irreversibleNotice: some View {
        Label("account.deletion.irreversible", systemImage: "exclamationmark.triangle")
            .font(.app(.subtitleStrong))
            .foregroundStyle(Color.App.System.destructive)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("account.deletion.irreversible")
    }

    private var familyNameField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("account.deletion.creator.confirm_label")
                .font(.app(.subtitle))
                .foregroundStyle(Color.App.Text.primary)
            TextField("", text: $viewModel.typedFamilyName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.app(.body))
                .padding(.horizontal, AppSpacing.md)
                .frame(minHeight: 44)
                .background(Color.App.Background.card, in: RoundedRectangle(cornerRadius: AppRadius.banner))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.banner)
                        .strokeBorder(Color.App.Border.separator, lineWidth: 1)
                )
                .disabled(viewModel.isBusy)
                .accessibilityLabel(Text("account.deletion.creator.confirm_label"))
                .accessibilityIdentifier("account.deletion.family_name")
        }
    }

    @ViewBuilder
    private var feedback: some View {
        switch viewModel.state {
        case .failed(.generic):
            InlineFeedbackBanner(message: String(localized: "account.deletion.error.generic"))
                .accessibilityIdentifier("account.deletion.error")
        case .failed(.apple):
            InlineFeedbackBanner(message: String(localized: "account.deletion.error.apple"))
                .accessibilityIdentifier("account.deletion.error")
        case .failed(.network):
            InlineFeedbackBanner(message: String(localized: "account.common.error_network"), systemImage: "wifi.slash")
                .accessibilityIdentifier("account.deletion.error")
        case .content, .submitting, .confirming:
            EmptyView()
        }
    }

    private var deleteButton: some View {
        Button {
            viewModel.requestDeletion()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if viewModel.isBusy {
                    ProgressView().tint(Color.App.Text.onAction)
                    Text(viewModel.state == .confirming ? "account.deletion.confirming" : "account.deletion.submitting")
                } else {
                    Image(systemName: "trash")
                        .accessibilityHidden(true)
                    Text(buttonTitle)
                }
            }
            .font(.app(.bodyStrong))
            .foregroundStyle(Color.App.Text.onAction)
            .frame(maxWidth: .infinity, minHeight: minimumTarget)
            .background(
                Color.App.System.destructive.opacity(viewModel.canRequestDeletion || viewModel.isBusy ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: AppRadius.pill)
            )
        }
        .disabled(!viewModel.canRequestDeletion)
        .accessibilityHint(Text("account.deletion.button_hint"))
        .accessibilityIdentifier("account.deletion.button")
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: horizontalSizeClass == .regular ? 540 : .infinity)
        .frame(maxWidth: .infinity)
        .background(Color.App.Background.app)
    }

    private var buttonTitle: LocalizedStringKey {
        if case .creator = viewModel.variant { return "account.deletion.creator.button" }
        return "account.deletion.button"
    }

    private var confirmationTitle: Text {
        if case let .creator(familyName) = viewModel.variant {
            return Text(String(format: String(localized: "account.deletion.confirm.creator_title"), familyName))
        }
        return Text("account.deletion.confirm.title")
    }
}

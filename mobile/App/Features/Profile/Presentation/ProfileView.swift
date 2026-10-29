import SwiftUI
import UIKit

/// TEL-030 — Meu perfil (Figma 566:40 iPhone, 568:81 Kids, 568:304 iPad retrato, 645:13677 iPad paisagem).
/// Opening MOD-009 and TEL-054 is wired through `viewModel.isShowingEditor` / `selectedBadgeForDetail`.
struct ProfileView: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegular: Bool { horizontalSizeClass == .regular }
    private var minimumTarget: CGFloat { viewModel.isKid ? 56 : 44 }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content(isLandscape: isRegular && proxy.size.width > proxy.size.height)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("profile.title")
        .toolbar {
            if viewModel.state == .loaded {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("profile.edit_button") { viewModel.startEditing() }
                        .frame(minWidth: minimumTarget, minHeight: minimumTarget)
                        .accessibilityIdentifier("profile.edit.button")
                }
            }
        }
        .task { await viewModel.load() }
        .navigationDestination(item: $viewModel.selectedBadgeForDetail) { item in
            if let detailViewModel = viewModel.makeBadgeDetailViewModel(for: item) {
                BadgeDetailView(viewModel: detailViewModel)
            }
        }
        .sheet(isPresented: $viewModel.isShowingLeaveAdminPlaceholder) { leaveAdministrationConfirmation }
        .sheet(
            item: Binding(get: { viewModel.editor }, set: { if $0 == nil { viewModel.dismissEditor() } })
        ) { editor in
            OwnProfileEditorView(viewModel: editor)
        }
    }

    /// MOD-010 — confirmation for SPEC-003 CA-05.
    private var leaveAdministrationConfirmation: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Label("profile.role.leave_administration", systemImage: "person.badge.minus")
                    .font(.headline)
                Text("profile.role.leave_confirmation.message")
                    .multilineTextAlignment(.center)
                if viewModel.leaveAdministrationFailed {
                    Label("profile.role.leave_confirmation.error", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                Button("profile.role.leave_administration", role: .destructive) {
                    Task { await viewModel.leaveAdministration() }
                }
                .disabled(viewModel.isLeavingAdministration)
                if viewModel.isLeavingAdministration { ProgressView() }
            }
            .padding(24)
            .accessibilityIdentifier("profile.role.leave_confirmation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("profile.common.close") { viewModel.isShowingLeaveAdminPlaceholder = false }
                        .disabled(viewModel.isLeavingAdministration)
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func content(isLandscape: Bool) -> some View {
        switch viewModel.state {
        case .loading:
            skeleton.frame(maxWidth: isRegular ? 600 : .infinity)
        case .error:
            errorCard.frame(maxWidth: isRegular ? 600 : .infinity)
        case .loaded:
            if isLandscape {
                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 18) {
                        identityCard
                        if viewModel.showsRoleSection { roleSection }
                    }
                    .frame(width: 420)
                    achievements.frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 18) {
                    identityCard
                    achievements
                    if viewModel.showsRoleSection { roleSection }
                }
                .frame(maxWidth: isRegular ? 600 : .infinity)
            }
        }
    }

    // MARK: Identity

    private var identityCard: some View {
        VStack(spacing: 6) {
            avatar
            Text(viewModel.displayTitle)
                .font(.system(size: 22, weight: .bold))
                .accessibilityIdentifier("profile.identity.title")
            Text(viewModel.displaySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("profile.identity.subtitle")
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = viewModel.avatarData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .accessibilityLabel("profile.avatar.photo")
        } else {
            Circle()
                .fill(Color(uiColor: .systemGray5))
                .frame(width: 96, height: 96)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("profile.avatar.default")
        }
    }

    // MARK: Achievements

    private var achievements: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.badges.section")
                .font(.system(size: 22, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.totalParticipations)")
                    .font(.system(size: 34, weight: .bold))
                Text(viewModel.totalText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile.badges.total")
                Text(viewModel.nextTierText)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("profile.badges.next_tier")
                ProgressView(value: viewModel.progressFraction)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isRegular ? 4 : 2),
                spacing: 12
            ) {
                ForEach(viewModel.badgeItems) { item in
                    badgeCell(item)
                }
            }

            Text(viewModel.badgesFooter)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("profile.badges.footer")
        }
    }

    private func badgeCell(_ item: BadgeDisplayItem) -> some View {
        let name = ProfileViewModel.tierName(item.tier)
        let remaining = viewModel.missionsRemaining(for: item)
        return Button {
            viewModel.selectBadge(item)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: item.isConquered ? "medal.fill" : "medal")
                        .font(.system(size: 28))
                        .foregroundStyle(item.isConquered ? item.tier.badgeTint : Color(uiColor: .tertiaryLabel))
                        .frame(width: 40, height: 40)
                    Spacer()
                    if item.isConquered {
                        Image(systemName: "chevron.forward")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(name)
                    .font(.headline)
                    .foregroundStyle(item.isConquered ? Color.primary : Color.secondary)
                Text(String(format: String(localized: "profile.badge.missions"), item.requiredMissionCount))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if item.isConquered {
                    Label("profile.badge.conquered", systemImage: "checkmark")
                        .font(.footnote.weight(.semibold))
                } else {
                    Text(String(format: String(localized: "profile.badge.remaining"), remaining))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                if item.isConquered {
                    RoundedRectangle(cornerRadius: 18).fill(Color(uiColor: .secondarySystemGroupedBackground))
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(uiColor: .systemGray6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color(uiColor: .systemGray4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!item.isConquered)
        .accessibilityIdentifier("profile.badge.\(item.tier.rawValue)")
        .accessibilityLabel(
            item.isConquered
                ? String(format: String(localized: "profile.badge.a11y_conquered"), name)
                : String(format: String(localized: "profile.badge.a11y_pending"), name, remaining)
        )
        .accessibilityHint(item.isConquered ? Text("profile.badge.a11y_hint") : Text(verbatim: ""))
    }

    // MARK: Role in the family

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("profile.role.section")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack {
                    Text("profile.role.label")
                    Spacer()
                    Text(viewModel.roleTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile.role.value")
                }
                .frame(minHeight: 50)
                .padding(.horizontal, 16)

                if viewModel.canLeaveAdministration {
                    Divider()
                    Button(role: .destructive) {
                        viewModel.isShowingLeaveAdminPlaceholder = true
                    } label: {
                        Text("profile.role.leave_administration")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("profile.role.leave_button")
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))

            Text(viewModel.roleFooter)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .accessibilityIdentifier("profile.role.footer")
        }
    }

    // MARK: Loading and error

    private var skeleton: some View {
        let placeholder = Color(uiColor: .systemGray5)
        return VStack(spacing: 18) {
            VStack(spacing: 10) {
                Circle().fill(placeholder).frame(width: 96, height: 96)
                Capsule().fill(placeholder).frame(width: 140, height: 14)
                Capsule().fill(placeholder).frame(width: 200, height: 14)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isRegular ? 4 : 2), spacing: 12) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        Circle().fill(placeholder).frame(width: 40, height: 40)
                        Capsule().fill(placeholder).frame(width: 80, height: 12)
                        Capsule().fill(placeholder).frame(width: 50, height: 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(uiColor: .systemGray6), in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("profile.loading")
        .accessibilityIdentifier("profile.loading")
    }

    private var errorCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 10) {
                Text("profile.error_load")
                    .accessibilityIdentifier("profile.error.message")
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Text("profile.common.retry")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: minimumTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .accessibilityIdentifier("profile.error.retry")
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .contain)
    }
}

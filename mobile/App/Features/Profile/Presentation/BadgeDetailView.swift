import SwiftUI

/// TEL-054 — Detalhe do marco (Figma 567:37 iPhone, 568:228 Kids, 568:492 iPad).
struct BadgeDetailView: View {
    @State private var viewModel: BadgeDetailViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(viewModel: BadgeDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                switch viewModel.state {
                case .loading: skeleton
                case .error: errorCard
                case .loaded: missionList
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: horizontalSizeClass == .regular ? 600 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .navigationDestination(item: $viewModel.selectedMission) { mission in missionPlaceholder(mission) }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "medal.fill")
                .font(.system(size: 40))
                .foregroundStyle(viewModel.tier.badgeTint)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            Text(viewModel.headerTitle)
                .font(.system(size: 22, weight: .bold))
                .accessibilityIdentifier("profile.badge_detail.title")
            Text(viewModel.awardedDateText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("profile.badge_detail.awarded_at")
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private var missionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.sectionTitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("profile.badge_detail.section")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.missions.enumerated()), id: \.element.id) { index, mission in
                    if index > 0 { Divider().padding(.leading, 16) }
                    Button {
                        viewModel.selectedMission = mission
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mission.title).font(.body).foregroundStyle(.primary)
                                Text(viewModel.completedDateText(for: mission))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile.badge_detail.mission_row")
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        }
    }

    private var skeleton: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< 3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    Capsule().fill(Color(uiColor: .systemGray5)).frame(width: 180, height: 14)
                    Capsule().fill(Color(uiColor: .systemGray5)).frame(width: 120, height: 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("profile.badge_detail.loading_date")
        .accessibilityIdentifier("profile.badge_detail.loading")
    }

    private var errorCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill").font(.title3).foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 10) {
                Text("profile.badge_detail.error")
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Text("profile.common.retry")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .accessibilityIdentifier("profile.badge_detail.retry")
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    /// Typed stand-in for TEL-021 (Missão), owned by another spec.
    private func missionPlaceholder(_ mission: ContributingMission) -> some View {
        ContentUnavailableView {
            Label(mission.title, systemImage: "star")
        } description: {
            Text("destination.contentPending")
        }
        .navigationTitle(mission.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("profile.badge_detail.mission_placeholder")
    }
}

extension BadgeTier {
    var badgeTint: Color {
        switch self {
        case .bronze: .brown
        case .silver: .gray
        case .gold: .yellow
        case .diamond: .cyan
        }
    }
}

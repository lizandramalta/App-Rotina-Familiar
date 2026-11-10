import SwiftUI

/// TEL-024 — Roleta da missão (SPEC-017 Fase 2, UX-017 §5.2; Figma 575:1119). Administrador only;
/// reached from TEL-021. The local result is always labelled as not saved until the server confirms.
struct RewardWheelView: View {
    @State private var viewModel: RewardWheelViewModel
    let onAccepted: (AcceptedMissionReward) -> Void
    let onLeave: () -> Void
    let onOpenCatalog: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isResultFocused: Bool
    @AccessibilityFocusState private var isBannerFocused: Bool

    init(
        viewModel: RewardWheelViewModel,
        onAccepted: @escaping (AcceptedMissionReward) -> Void,
        onLeave: @escaping () -> Void,
        onOpenCatalog: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onAccepted = onAccepted
        self.onLeave = onLeave
        self.onOpenCatalog = onOpenCatalog
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                switch viewModel.catalogState {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 260)
                        .accessibilityIdentifier("reward.wheel.loading")
                case .failed:
                    loadFailure
                case .loaded:
                    loadedContent
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
        .navigationBarTitleDisplayMode(.inline)
        // The draw is never lost by mistake mid-request: back is blocked while confirming.
        .navigationBarBackButtonHidden(!viewModel.canExit)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reward.wheel.screen")
        .task { await viewModel.load() }
        .onChange(of: viewModel.resultRevision) { _, _ in
            if let item = viewModel.selectedItem {
                AccessibilityNotification.Announcement(Self.resultAnnouncement(for: item)).post()
            }
            isResultFocused = true
        }
        .onChange(of: viewModel.phase) { _, phase in
            if phase == .uncertain || phase == .error { isBannerFocused = true }
        }
        .onChange(of: viewModel.confirmedReward) { _, reward in
            guard let reward else { return }
            AccessibilityNotification.Announcement(
                String(format: String(localized: "reward.wheel.accepted_announcement"), reward.title)
            ).post()
            onAccepted(reward)
        }
        .alert(alertTitle, isPresented: Binding(
            get: { viewModel.alert != nil },
            set: { if !$0 { viewModel.alert = nil } }
        )) {
            Button("reward.wheel.view_mission") {
                viewModel.alert = nil
                onLeave()
            }
        } message: {
            Text(alertMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("reward.wheel.title")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(String(format: String(localized: "reward.wheel.mission_context"), viewModel.missionTitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if viewModel.showsRefreshMission {
            statusBanner
        }
        RewardWheel(
            count: viewModel.items.count,
            highlightedIndex: viewModel.phase == .spinning ? nil : viewModel.selectedIndex,
            rotation: viewModel.rotation
        )
        .animation(
            reduceMotion ? nil : .timingCurve(0.15, 0.8, 0.25, 1, duration: viewModel.spinAnimationDuration),
            value: viewModel.rotation
        )
        .frame(width: 240, height: 252)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)

        if let item = viewModel.selectedItem, viewModel.phase != .spinning {
            resultCard(item)
        } else if viewModel.phase == .idle {
            Text("reward.wheel.instruction")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        actions
    }

    private func resultCard(_ item: RewardItem) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "gift")
                .accessibilityHidden(true)
            Text(item.title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            if let details = item.details, !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Label("reward.wheel.pending", systemImage: "info.circle")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray6), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Self.resultAnnouncement(for: item)))
        .accessibilityFocused($isResultFocused)
        .accessibilityIdentifier("reward.wheel.result")
    }

    private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                viewModel.phase == .error ? "reward.wheel.error" : "reward.wheel.uncertain",
                systemImage: "exclamationmark.circle.fill"
            )
            .font(.subheadline)
            Button {
                Task { await viewModel.refreshMission() }
            } label: {
                if viewModel.phase == .reconciling {
                    ProgressView()
                        .frame(minWidth: 140, minHeight: 36)
                } else {
                    Text("reward.wheel.refresh_mission")
                        .frame(minWidth: 140, minHeight: 36)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.primary)
            .disabled(viewModel.phase == .reconciling)
            .accessibilityIdentifier("reward.wheel.refresh_mission")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityFocused($isBannerFocused)
        .accessibilityIdentifier("reward.wheel.status_banner")
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            if viewModel.selectedItem == nil || viewModel.phase == .spinning {
                primaryButton(
                    "reward.wheel.draw",
                    identifier: "reward.wheel.draw",
                    enabled: viewModel.canDraw
                ) {
                    Task { await viewModel.draw(reduceMotion: reduceMotion) }
                }
            } else {
                Button {
                    Task { await viewModel.accept() }
                } label: {
                    Group {
                        if viewModel.phase == .submitting {
                            Label("reward.wheel.submitting", systemImage: "hourglass")
                        } else {
                            Text("reward.wheel.accept")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.primary)
                .disabled(!viewModel.canAccept)
                .accessibilityIdentifier("reward.wheel.accept")

                Button {
                    Task { await viewModel.draw(reduceMotion: reduceMotion) }
                } label: {
                    Text("reward.wheel.draw_again")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Color.primary)
                .disabled(!viewModel.canDraw)
                .accessibilityIdentifier("reward.wheel.draw_again")

                Button("reward.wheel.exit") { onLeave() }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .tint(Color.primary)
                    .disabled(!viewModel.canExit)
                    .accessibilityIdentifier("reward.wheel.exit")
            }

            Button("reward.wheel.consult") { onOpenCatalog() }
                .frame(maxWidth: .infinity, minHeight: 44)
                .tint(Color.primary)
                .disabled(!viewModel.canExit || viewModel.phase == .spinning)
                .accessibilityIdentifier("reward.wheel.consult")
        }
    }

    private func primaryButton(
        _ title: LocalizedStringKey,
        identifier: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.primary)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }

    private var loadFailure: some View {
        VStack(spacing: 14) {
            Text("reward.wheel.load_error")
                .font(.headline)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.load() }
            } label: {
                Text("missions.common.retry")
                    .frame(minWidth: 160, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Color.primary)
            .accessibilityIdentifier("reward.wheel.retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reward.wheel.load_error")
    }

    private var alertTitle: LocalizedStringKey {
        viewModel.alert == .alreadyAccepted ? "reward.wheel.already_accepted_title" : "reward.wheel.unavailable_title"
    }

    private var alertMessage: LocalizedStringKey {
        viewModel.alert == .alreadyAccepted ? "reward.wheel.already_accepted" : "reward.wheel.unavailable"
    }

    /// Title, optional description and the "not saved yet" status, read together (UX-017 §8).
    static func resultAnnouncement(for item: RewardItem) -> String {
        [item.title, item.details, String(localized: "reward.wheel.pending")]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }
}

/// Equal slices clockwise from the top pointer (`RewardWheelGeometry`). Slices carry no text: the
/// catalog size varies and the result card names the item (decisão R-5).
private struct RewardWheel: View {
    let count: Int
    let highlightedIndex: Int?
    let rotation: Double

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.title3)
                .foregroundStyle(.primary)
            ZStack {
                ForEach(0 ..< max(count, 1), id: \.self) { index in
                    WheelSlice(index: index, count: max(count, 1))
                        .fill(fill(for: index))
                }
                Circle().stroke(Color.primary, lineWidth: 2)
                Circle().fill(Color.primary).frame(width: 26, height: 26)
            }
            .rotationEffect(.degrees(rotation))
            .frame(width: 228, height: 228)
        }
    }

    private func fill(for index: Int) -> Color {
        if index == highlightedIndex { return Color(.systemGray) }
        return index.isMultiple(of: 2) ? Color(.systemGray4) : Color(.systemGray5)
    }
}

private struct WheelSlice: Shape {
    let index: Int
    let count: Int

    func path(in rect: CGRect) -> Path {
        let slice = RewardWheelGeometry.sliceAngle(count: count)
        // SwiftUI angles start at 3 o'clock; -90° moves the origin to the top pointer.
        let start = Angle.degrees(Double(index) * slice - 90)
        let end = Angle.degrees(Double(index + 1) * slice - 90)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}

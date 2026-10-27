import SwiftUI

/// TEL-050 — Família (Figma nodes 372:4825, 372:5195, 561:173, UX-003 §5.1).
struct FamilyOverviewView: View {
    @State private var viewModel: FamilyOverviewViewModel
    @State private var showsRangeFilter = false
    private let makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)?

    init(
        viewModel: FamilyOverviewViewModel,
        makeFamilySettingsViewModel: (() -> FamilySettingsViewModel)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeFamilySettingsViewModel = makeFamilySettingsViewModel
    }

    var body: some View {
        List {
            if let message = viewModel.errorMessage {
                Section {
                    Label {
                        Text(message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("family.members.error")

                    Button("family.member.detail.retry") {
                        Task { await viewModel.loadInitial() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }

            if let overview = viewModel.overview {
                Section {
                    Button {
                        showsRangeFilter = true
                    } label: {
                        Label {
                            Text(
                                String(
                                    format: String(localized: "family.tasks.range"),
                                    overview.range.startDate,
                                    overview.range.endDate
                                )
                            )
                        } icon: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("family.overview.range_filter")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("family.overview.progress")
                            .font(.headline)
                        Text(
                            String(
                                format: String(localized: "family.overview.completed_total"),
                                overview.progress.completed,
                                overview.progress.total
                            )
                        )
                        .font(.title3.weight(.bold))
                        if overview.progress.total > 0 {
                            ProgressView(value: Double(overview.progress.completed), total: Double(overview.progress.total))
                                .tint(.green)
                        } else {
                            Text("family.overview.no_tasks")
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 16) {
                            statusCount("family.tasks.status.pending", count: overview.progress.pending)
                            if overview.progress.awaitingConfirmation > 0 {
                                statusCount("family.tasks.status.awaiting", count: overview.progress.awaitingConfirmation)
                            }
                        }
                        .font(.footnote)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("family.overview.progress")
                }

                if let tasks = viewModel.makeFamilyTasksViewModel() {
                    Section {
                        NavigationLink {
                            FamilyTasksView(viewModel: tasks)
                        } label: {
                            Label("family.tasks.title", systemImage: "checklist")
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("family.overview.all_tasks")
                    }
                }
            } else if viewModel.isLoadingOverview {
                Section {
                    ProgressView().frame(maxWidth: .infinity)
                        .accessibilityIdentifier("family.overview.progress_loading")
                }
            }

            if viewModel.overviewFailed {
                Section {
                    Label("family.overview.error_load", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Button("family.member.detail.retry") {
                        Task { await viewModel.loadInitial() }
                    }
                }
            }

            if viewModel.canReviewKidsConfirmations {
                Section {
                    NavigationLink {
                        if let queue = viewModel.makeKidsReviewQueue() {
                            KidsReviewQueueView(viewModel: queue)
                        }
                    } label: {
                        Label("family.overview.kids_confirmations", systemImage: "checkmark.shield")
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("family.overview.kids_confirmations")
                }
            }

            if let overview = viewModel.overview {
                Section("family.overview.members_section") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(overview.members) { member in
                            NavigationLink {
                                MemberDetailView(viewModel: viewModel.makeMemberDetailViewModel(memberID: member.id)) {
                                    Task { await viewModel.loadInitial() }
                                }
                            } label: {
                                memberRing(member)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("family.member.ring.\(member.id.uuidString.lowercased())")
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .accessibilityIdentifier("family.members.list")
        .navigationTitle(viewModel.familyName.isEmpty ? String(localized: "family.overview.title") : viewModel.familyName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if viewModel.canConfigureFamily {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FamilySettingsHubView(viewModel: viewModel, makeFamilySettingsViewModel: makeFamilySettingsViewModel)
                    } label: {
                        Image(systemName: "gearshape")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("family.settings.title")
                    .accessibilityIdentifier("family.navigation.settings_button")
                }
            }
        }
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.loadInitial() }
        .sheet(isPresented: $showsRangeFilter) {
            if let overview = viewModel.overview {
                FamilyRangeFilterSheet(
                    range: overview.range,
                    firstDate: overview.familyCreatedAt,
                    timeZoneID: viewModel.timeZoneID
                ) { range in
                    Task { await viewModel.applyRange(range) }
                }
            }
        }
    }

    private func memberRing(_ member: FamilyMemberProgress) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat((member.progress.percentage ?? 0) / 100))
                    .stroke(.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(member.progress.percentage.map { "\(Int($0.rounded()))%" } ?? "—")
                    .font(.subheadline.weight(.bold))
            }
            .frame(width: 72, height: 72)
            Text(member.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            Text(
                String(
                    format: String(localized: "family.overview.member_completed"),
                    member.progress.completed,
                    member.progress.total
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 128)
        .accessibilityElement(children: .combine)
    }

    private func statusCount(_ title: LocalizedStringKey, count: Int) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
            Text(title)
        }
    }
}

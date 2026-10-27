import SwiftUI

/// TEL-011 task list and the task section of TEL-032 (SPEC-009 CA-06/07/09/12).
struct FamilyTasksView: View {
    @State var viewModel: FamilyTasksViewModel
    @State private var showsRangeFilter = false

    init(viewModel: FamilyTasksViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                Button {
                    showsRangeFilter = true
                } label: {
                    Label(
                        String(format: String(localized: "family.tasks.range"),
                               viewModel.range.startDate, viewModel.range.endDate),
                        systemImage: "line.3.horizontal.decrease"
                    )
                    .font(.subheadline)
                    .frame(minHeight: 44)
                }
                .accessibilityIdentifier("family.tasks.range")
            }

            if !viewModel.members.isEmpty {
                Section {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            memberChip(nil, name: String(localized: "family.tasks.member_all"))
                            ForEach(viewModel.members) { member in
                                memberChip(member.memberID, name: member.name)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            Section {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.availableStatuses, id: \.self) { status in
                            Button {
                                Task { await viewModel.applyStatus(status) }
                            } label: {
                                Text(statusTitle(status))
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        viewModel.status == status ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(viewModel.status == status ? .white : .primary)
                            }
                            .accessibilityAddTraits(viewModel.status == status ? .isSelected : [])
                            .accessibilityIdentifier("family.tasks.status.\(status.rawValue)")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }

            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
                    .accessibilityIdentifier("family.tasks.loading")
            }

            if viewModel.failed {
                Section {
                    Label("family.tasks.error", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Button("family.member.detail.retry") {
                        Task { await viewModel.load() }
                    }
                }
                .accessibilityIdentifier("family.tasks.error")
            }

            if !viewModel.isLoading && viewModel.items.isEmpty && !viewModel.failed {
                ContentUnavailableView("family.tasks.empty", systemImage: "checklist")
                    .accessibilityIdentifier("family.tasks.empty")
            }

            forEachStatus(.pending)
            if viewModel.role == .administrator {
                forEachStatus(.awaitingConfirmation)
            }
            forEachStatus(.completed)

            if viewModel.isLoadingMore {
                ProgressView().frame(maxWidth: .infinity)
            }
            if viewModel.loadMoreFailed {
                Button("family.member.detail.retry") {
                    Task { await viewModel.loadMore() }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(viewModel.isMemberDetail ? "family.member.tasks.title" : "family.tasks.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let report = viewModel.makeReportView() {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink {
                            report
                        } label: {
                            Label("family.tasks.generate_pdf", systemImage: "doc.richtext")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("family.tasks.more")
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showsRangeFilter) {
            if let first = viewModel.familyCreatedAt {
                FamilyRangeFilterSheet(
                    range: viewModel.range, firstDate: first, timeZoneID: viewModel.timeZoneID
                ) { range in Task { await viewModel.applyRange(range) } }
            }
        }
    }

    @ViewBuilder
    private func forEachStatus(_ status: TaskStatus) -> some View {
        let filtered = viewModel.items.filter { $0.displayStatus == status }
        if !filtered.isEmpty {
            Section(statusTitle(status)) {
                ForEach(filtered) { item in
                    NavigationLink(value: FamilyTaskRoute.detail(item.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.task.title)
                                .font(.body.weight(.semibold))
                            Text(item.task.scheduledDate)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                }
            }
        }
    }

    private func memberChip(_ id: UUID?, name: String) -> some View {
        Button {
            Task { await viewModel.applyMember(id) }
        } label: {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    viewModel.selectedMemberID == id ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground),
                    in: Capsule()
                )
                .foregroundStyle(viewModel.selectedMemberID == id ? .white : .primary)
        }
        .accessibilityAddTraits(viewModel.selectedMemberID == id ? .isSelected : [])
    }

    private func statusTitle(_ status: FamilyTaskStatusFilter) -> LocalizedStringKey {
        switch status {
        case .all: "family.tasks.status.all"
        case .pending: "family.tasks.status.pending"
        case .awaitingConfirmation: "family.tasks.status.awaiting"
        case .completed: "family.tasks.status.completed"
        }
    }

    private func statusTitle(_ status: TaskStatus) -> LocalizedStringKey {
        switch status {
        case .pending: "family.tasks.status.pending"
        case .awaitingConfirmation: "family.tasks.status.awaiting"
        case .completed: "family.tasks.status.completed"
        }
    }
}

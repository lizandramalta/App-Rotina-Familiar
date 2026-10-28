import SwiftUI
import UIKit

/// Approved TEL-011 composition; TEL-032 has its own compact daily list.
struct FamilyTasksDesignedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State var viewModel: FamilyTasksViewModel
    let onOpenTask: (UUID) -> Void
    @State private var showsFilter = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                header
                Text("family.tasks.title")
                    .font(.system(size: 28, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                memberFilters
                periodSummary

                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .accessibilityIdentifier("family.tasks.loading")
                }
                if viewModel.failed { failureCard }
                if !viewModel.isLoading && viewModel.items.isEmpty && !viewModel.failed {
                    ContentUnavailableView("family.tasks.empty", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("family.tasks.empty")
                }

                taskSection(.pending)
                if viewModel.role == .administrator { taskSection(.awaitingConfirmation) }
                taskSection(.completed)

                if viewModel.isLoadingMore {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if viewModel.loadMoreFailed {
                    Button("family.member.detail.retry") { Task { await viewModel.loadMore() } }
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showsFilter) {
            if let firstDate = viewModel.familyCreatedAt {
                FamilyTasksFilterSheet(
                    range: viewModel.range,
                    status: viewModel.status,
                    statuses: viewModel.availableStatuses,
                    firstDate: firstDate,
                    timeZoneID: viewModel.timeZoneID,
                    countProvider: { range, status in
                        try await viewModel.previewCount(range: range, status: status)
                    },
                    onApply: { range, status in
                        Task { await viewModel.applyFilters(range: range, status: status) }
                    }
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            roundButton("chevron.left", label: "family.tasks.back") { dismiss() }
            Spacer()
            roundButton("line.3.horizontal.decrease.circle.fill", label: "family.period.filter_title") {
                showsFilter = true
            }
            .disabled(viewModel.familyCreatedAt == nil)
            .accessibilityIdentifier("family.tasks.range")
        }
    }

    private func roundButton(
        _ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 20, height: 20)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
        .overlay(Circle().strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        .accessibilityLabel(label)
    }

    private var memberFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                memberChip(nil, name: String(localized: "family.tasks.member_all"))
                ForEach(viewModel.members) { member in
                    let name = member.memberID == viewModel.currentMemberID
                        ? String(localized: "family.tasks.member_you") : member.name
                    memberChip(member.memberID, name: name)
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("family.tasks.member_filters")
    }

    private func memberChip(_ id: UUID?, name: String) -> some View {
        let selected = viewModel.selectedMemberID == id
        return Button {
            Task { await viewModel.applyMember(id) }
        } label: {
            HStack(spacing: 6) {
                if id != nil { avatar(String(name.prefix(1))) }
                Text(name).font(.system(size: 15, weight: selected ? .semibold : .regular))
            }
            .padding(.leading, id == nil ? 12 : 6)
            .padding(.trailing, 12)
            .frame(minHeight: 36)
            .background(selected ? Color.primary : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id.map { "family.tasks.member.\($0.uuidString)" } ?? "family.tasks.member.all")
    }

    private var periodSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rangeLabel)
                .font(.system(size: 20, weight: .semibold))
                .accessibilityIdentifier("family.tasks.period")
            if containsToday {
                Text(String(format: String(localized: "family.tasks.today"),
                            dateText(Date(), pattern: "EEEE, d 'de' MMMM")))
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .padding(.top, 2)
    }

    private var failureCard: some View {
        VStack(spacing: 12) {
            Label("family.tasks.error", systemImage: "exclamationmark.triangle")
            Button("family.member.detail.retry") { Task { await viewModel.load() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("family.tasks.error")
    }

    @ViewBuilder
    private func taskSection(_ status: TaskStatus) -> some View {
        let rows = viewModel.items.filter { $0.displayStatus == status }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                let count = viewModel.count(for: statusFilter(status))
                let heading = count.map {
                    String(format: String(localized: "family.tasks.section_count"),
                           statusTitle(status).uppercased(), $0)
                } ?? statusTitle(status).uppercased()
                Text(heading)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 16)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { index in
                        if index > 0 { Divider().padding(.leading, 16) }
                        let item = rows[index]
                        Button {
                            onOpenTask(item.id)
                        } label: {
                            taskRow(item)
                        }
                        .buttonStyle(.plain)
                        .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func taskRow(_ item: FamilyTaskItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: statusSymbol(item.displayStatus))
                .font(.system(size: 20))
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            Text(item.task.title)
                .font(.system(size: 17))
                .foregroundStyle(item.displayStatus == .completed ? .secondary : .primary)
                .strikethrough(item.displayStatus == .completed)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            assignees(item.task.assigneeIDs)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel(item))
        .accessibilityHint("tasks.personal.openDetailHint")
        .accessibilityIdentifier("family.tasks.row.\(item.id.uuidString)")
    }

    @ViewBuilder
    private func assignees(_ ids: [UUID]) -> some View {
        if ids.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                Text("family.tasks.unassigned")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .accessibilityHidden(true)
        } else {
            HStack(spacing: -6) {
                ForEach(Array(ids.prefix(3)), id: \.self) { id in
                    avatar(String((memberName(id) ?? "?").prefix(1)))
                }
                if ids.count > 3 {
                    Text("+\(ids.count - 3)")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(Color(uiColor: .systemGray5), in: Circle())
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func avatar(_ initial: String) -> some View {
        Text(initial.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(width: 24, height: 24)
            .background(Color(uiColor: .systemGray4), in: Circle())
            .overlay(Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: 1.5))
    }

    private func memberName(_ id: UUID) -> String? {
        if id == viewModel.currentMemberID { return String(localized: "family.tasks.member_you") }
        return viewModel.members.first(where: { $0.memberID == id })?.name
    }

    private func rowAccessibilityLabel(_ item: FamilyTaskItem) -> String {
        let names = item.task.assigneeIDs.isEmpty
            ? String(localized: "family.tasks.unassigned")
            : item.task.assigneeIDs.map {
                memberName($0) ?? String(localized: "family.tasks.unknown_member")
            }.joined(separator: ", ")
        return "\(item.task.title), \(statusTitle(item.displayStatus)), \(names)"
    }

    private func statusSymbol(_ status: TaskStatus) -> String {
        switch status {
        case .pending: "circle"
        case .awaitingConfirmation: "clock"
        case .completed: "checkmark.circle.fill"
        }
    }

    private func statusFilter(_ status: TaskStatus) -> FamilyTaskStatusFilter {
        switch status {
        case .pending: .pending
        case .awaitingConfirmation: .awaitingConfirmation
        case .completed: .completed
        }
    }

    private func statusTitle(_ status: TaskStatus) -> String {
        switch status {
        case .pending: String(localized: "family.tasks.status.pending")
        case .awaitingConfirmation: String(localized: "family.tasks.status.awaiting")
        case .completed: String(localized: "family.tasks.status.completed")
        }
    }

    private var rangeLabel: String {
        guard let start = civilDate(viewModel.range.startDate),
              let end = civilDate(viewModel.range.endDate) else { return "" }
        if familyCalendar.isDate(start, equalTo: end, toGranularity: .month) {
            return String(format: String(localized: "family.tasks.range_same_month"),
                          familyCalendar.component(.day, from: start),
                          familyCalendar.component(.day, from: end),
                          dateText(end, pattern: "MMM"))
        }
        return String(format: String(localized: "family.tasks.range_other_month"),
                      dateText(start, pattern: "d MMM"), dateText(end, pattern: "d MMM"))
    }

    private var containsToday: Bool {
        let today = dateText(Date(), pattern: "yyyy-MM-dd")
        return viewModel.range.startDate <= today && today <= viewModel.range.endDate
    }


    private var familyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: viewModel.timeZoneID) ?? .current
        return calendar
    }

    private func civilDate(_ wire: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = familyCalendar
        formatter.timeZone = familyCalendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: wire)
    }

    private func dateText(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = familyCalendar
        formatter.timeZone = familyCalendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

}

private struct ReportFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct FamilyReportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

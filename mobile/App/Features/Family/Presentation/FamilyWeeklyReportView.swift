import PDFKit
import SwiftUI
import UIKit

/// TEL-051 — SPEC-019 CA-05–07: select a week, render locally, then share explicitly.
struct FamilyWeeklyReportView: View {
    let range: FamilyDateRange
    let familyCreatedAt: String
    let familyName: String
    let timeZoneID: String
    let repository: any FamilyRepository
    let accessToken: String

    @State private var referenceDate = Date()
    @State private var pdfURL: URL?
    @State private var isGenerating = false
    @State private var failed = false
    /// Server cut-off of the last generated snapshot; before generating, "now" is the effective cut-off.
    @State private var generatedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                weekCard
                if failed { errorBanner }
                Button {
                    Task { await generate() }
                } label: {
                    if isGenerating {
                        ProgressView().tint(Color.App.Text.onAction)
                    } else {
                        Label("family.tasks.generate_pdf", systemImage: "doc.richtext")
                    }
                }
                .buttonStyle(AppPillButtonStyle(kind: .primary))
                .disabled(isGenerating)
                .accessibilityIdentifier("family.report.generate")
                if let pdfURL { preview(pdfURL) }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.lg)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .background(Color.App.Background.app.ignoresSafeArea())
        .navigationTitle("family.report.title")
        .navigationBarTitleDisplayMode(.inline)
        .hidesAppTabBar()
        .onAppear { referenceDate = min(civilDate(range.endDate) ?? Date(), Date()) }
        .onChange(of: referenceDate) { _, _ in generatedAt = nil }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("family.report.week_section")
                .font(.app(.cardTitle))
                .foregroundStyle(Color.App.Text.primary)
                .accessibilityAddTraits(.isHeader)
            if spansMultipleWeeks {
                DatePicker("family.report.week", selection: $referenceDate, in: dateBounds, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Color.App.Action.primary)
                    .environment(\.timeZone, calendar.timeZone)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(weekDescription)
                    .font(.app(.subtitleStrong))
                    .foregroundStyle(Color.App.Text.primary)
                Label(TimeZoneDisplay.displayName(for: timeZoneID), systemImage: "globe")
                    .font(.app(.note))
                    .foregroundStyle(Color.App.Text.secondary)
                if isCurrentWeek {
                    Text(String(format: String(localized: "family.report.partial_until"), partialCutoff))
                        .font(.app(.noteStrong))
                        .foregroundStyle(Color.App.Text.highlight)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.App.Background.cardHighlight, in: Capsule())
                        .accessibilityIdentifier("family.report.partial")
                }
            }
            .accessibilityElement(children: .combine)
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(cornerRadius: AppRadius.cardBoard)
    }

    private var errorBanner: some View {
        InlineFeedbackBanner(message: String(localized: "family.report.error"))
            .accessibilityIdentifier("family.report.error")
    }

    private func preview(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("family.report.preview")
                .font(.app(.cardTitle))
                .foregroundStyle(Color.App.Text.primary)
                .accessibilityAddTraits(.isHeader)
            FamilyPDFPreview(url: url)
                .frame(minHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .chalkStrokeBorder(RoundedRectangle(cornerRadius: AppRadius.card), color: Color.App.Border.separator, lineWidth: 1)
                .accessibilityIdentifier("family.report.preview")
            ShareLink(item: url) {
                Label("family.report.share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(AppPillButtonStyle(kind: .secondary))
            .accessibilityIdentifier("family.report.share")
        }
        .padding(AppSpacing.lg)
        .appCard(cornerRadius: AppRadius.cardBoard)
    }

    /// The selected Monday–Sunday week still contains today (UX-019: current week is partial).
    private var isCurrentWeek: Bool {
        monday(for: calendar.startOfDay(for: referenceDate)) == monday(for: calendar.startOfDay(for: Date()))
    }

    private var partialCutoff: String {
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated).hour().minute()
        style.timeZone = calendar.timeZone
        return (generatedAt ?? Date()).formatted(style)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return value
    }

    private func monday(for date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: date) ?? date
    }

    private var spansMultipleWeeks: Bool {
        guard let first = civilDate(range.startDate), let last = civilDate(range.endDate) else { return false }
        return monday(for: first) != monday(for: last)
    }

    private var dateBounds: ClosedRange<Date> {
        let first = max(civilDate(familyCreatedAt) ?? .distantPast, civilDate(range.startDate) ?? .distantPast)
        let last = min(civilDate(range.endDate) ?? Date(), Date())
        return first ... max(first, last)
    }

    private var weekDescription: String {
        let first = monday(for: referenceDate)
        let sunday = calendar.date(byAdding: .day, value: 6, to: first) ?? first
        // Shown in the family time zone, not the device's (UX-019 §2).
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
        style.timeZone = calendar.timeZone
        return "\(first.formatted(style)) – \(sunday.formatted(style))"
    }

    private func civilDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func generate() async {
        guard !isGenerating else { return }
        isGenerating = true
        failed = false
        defer { isGenerating = false }
        do {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            let snapshot = try await repository.getWeeklyReport(
                referenceDate: formatter.string(from: referenceDate), accessToken: accessToken
            )
            let data = FamilyPDFRenderer.render(snapshot: snapshot, familyName: familyName)
            let file = FileManager.default.temporaryDirectory
                .appending(path: "family-report-\(snapshot.period.startDate).pdf")
            try data.write(to: file, options: .atomic)
            pdfURL = file
            generatedAt = snapshot.isPartial ? snapshot.generatedAt : nil
        } catch {
            failed = true
        }
    }
}

private struct FamilyPDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(url: url)
    }
}

@MainActor
enum FamilyPDFRenderer {
    static func render(snapshot: WeeklyReportSnapshot, familyName: String) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()
            let text = UIColor.label
            let muted = UIColor.secondaryLabel
            func draw(_ value: String, y: CGFloat, size: CGFloat = 14, bold: Bool = false, color: UIColor = .label) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size),
                    .foregroundColor: color,
                ]
                (value as NSString).draw(in: CGRect(x: 40, y: y, width: 515, height: 32), withAttributes: attributes)
            }
            draw(familyName, y: 40, size: 24, bold: true, color: text)
            draw(String(localized: "family.report.title"), y: 78, size: 18, bold: true, color: text)
            draw("\(snapshot.period.startDate) – \(snapshot.period.endDate) · \(snapshot.timeZoneID)", y: 112, color: muted)
            draw(String(format: String(localized: "family.report.generated_at"), snapshot.generatedAt.formatted()), y: 136, color: muted)
            if snapshot.isPartial { draw(String(localized: "family.report.partial"), y: 164, color: muted) }
            if snapshot.isTransition { draw(String(localized: "family.report.transition"), y: 188, color: muted) }
            draw(String(localized: "family.report.progress"), y: 226, size: 17, bold: true)
            draw("\(snapshot.progress.completed) / \(snapshot.progress.total) · \(Int((snapshot.progress.percentage ?? 0).rounded()))%", y: 255)
            let bar = CGRect(x: 40, y: 290, width: 515, height: 18)
            UIColor.systemGray5.setFill(); UIBezierPath(roundedRect: bar, cornerRadius: 9).fill()
            if let percentage = snapshot.progress.percentage, percentage > 0 {
                UIColor(Color.App.Action.primary).setFill()
                UIBezierPath(roundedRect: CGRect(x: 40, y: 290, width: 515 * min(percentage, 100) / 100, height: 18), cornerRadius: 9).fill()
            }
            draw(String(localized: "family.report.shared_note"), y: 318, size: 10, color: muted)
            draw(String(localized: "family.report.load"), y: 352, size: 17, bold: true)
            draw(String(format: String(localized: "family.report.total_weight"), snapshot.totalWeight), y: 382)
            if snapshot.members.isEmpty || (snapshot.progress.total == 0 && snapshot.totalWeight == 0) {
                draw(String(localized: "family.report.no_tasks"), y: 424, color: muted)
            } else {
                var y: CGFloat = 424
                for member in snapshot.members {
                    if y > 750 { context.beginPage(); y = 50 }
                    draw(member.displayName, y: y, bold: true)
                    draw(String(format: String(localized: "family.report.member_summary"), member.weight, member.completedTasks), y: y + 22, color: muted)
                    UIColor.systemGray5.setFill()
                    UIBezierPath(roundedRect: CGRect(x: 40, y: y + 44, width: 280, height: 8), cornerRadius: 4).fill()
                    if let percentage = member.percentage, percentage > 0 {
                        UIColor(Color.App.Action.primarySoft).setFill()
                        UIBezierPath(roundedRect: CGRect(x: 40, y: y + 44, width: 280 * min(percentage, 100) / 100, height: 8), cornerRadius: 4).fill()
                    }
                    y += 72
                }
            }
        }
    }
}

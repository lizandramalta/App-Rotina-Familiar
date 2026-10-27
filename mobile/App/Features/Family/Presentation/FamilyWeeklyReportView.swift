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

    var body: some View {
        List {
            Section("family.report.week_section") {
                if spansMultipleWeeks {
                    DatePicker("family.report.week", selection: $referenceDate, in: dateBounds, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.timeZone, TimeZone(identifier: timeZoneID) ?? .current)
                }
                Text(weekDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if failed {
                Section {
                    Label("family.report.error", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            Section {
                Button {
                    Task { await generate() }
                } label: {
                    if isGenerating { ProgressView() }
                    else { Label("family.tasks.generate_pdf", systemImage: "doc.richtext") }
                }
                .disabled(isGenerating)
                .accessibilityIdentifier("family.report.generate")
            }
            if let pdfURL {
                Section("family.report.preview") {
                    FamilyPDFPreview(url: pdfURL)
                        .frame(minHeight: 420)
                        .accessibilityIdentifier("family.report.preview")
                    ShareLink(item: pdfURL) {
                        Label("family.report.share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("family.report.share")
                }
            }
        }
        .navigationTitle("family.report.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { referenceDate = min(civilDate(range.endDate) ?? Date(), Date()) }
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
        return "\(first.formatted(date: .abbreviated, time: .omitted)) – \(sunday.formatted(date: .abbreviated, time: .omitted))"
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
private enum FamilyPDFRenderer {
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
                UIColor.systemGreen.setFill()
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
                        UIColor.systemBlue.setFill()
                        UIBezierPath(roundedRect: CGRect(x: 40, y: y + 44, width: 280 * min(percentage, 100) / 100, height: 8), cornerRadius: 4).fill()
                    }
                    y += 72
                }
            }
        }
    }
}

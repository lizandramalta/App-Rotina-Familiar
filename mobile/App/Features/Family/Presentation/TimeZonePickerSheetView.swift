import SwiftUI

/// Searchable IANA time zone picker used by TEL-002.
struct TimeZonePickerSheetView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private static let identifiers = TimeZone.knownTimeZoneIdentifiers.sorted()

    private var filtered: [String] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            return Self.identifiers
        }
        return Self.identifiers.filter {
            $0.localizedStandardContains(term) || TimeZoneDisplay.city($0).localizedStandardContains(term)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { identifier in
                Button {
                    selection = identifier
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(TimeZoneDisplay.city(identifier))
                                .foregroundStyle(.primary)
                            Text(identifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if identifier == selection {
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityIdentifier("family.timezone.option.\(identifier)")
                .accessibilityAddTraits(identifier == selection ? .isSelected : [])
            }
            .accessibilityIdentifier("family.create.timezone_picker")
            .searchable(text: $query, prompt: Text("family.create.time_zone.search"))
            .navigationTitle("family.create.time_zone.label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("family.create.time_zone.close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

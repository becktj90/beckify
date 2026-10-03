import SwiftUI
import UIKit
import BeckifyMath

struct NumberField: View {
    let title: String
    let unit: String
    @Binding var text: String
    var placeholder: String = "0"
    var optional: Bool = false
    var allowsScientific: Bool = false
    /// Accept `10k`, `0.1u`, `2.2n` and switch to a keyboard that can type the suffix.
    var allowsEngineering: Bool = false
    var errorMessage: String? = nil
    var helpText: String? = nil
    var fieldID: String? = nil
    /// Spoken name when the visible title is a symbol such as Vrms or Vp.
    var spokenLabel: String? = nil
    var onSubmit: (() -> Void)? = nil
    var lowConfidence: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(Theme.TypeRole.fieldLabel)
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                if optional {
                    Text("optional")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted.opacity(0.7))
                }
                if lowConfidence {
                    Text("check")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.warn)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(Theme.foreground)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(onSubmit == nil ? .done : .go)
                    .onSubmit { onSubmit?() }
                    .formFieldFocus(fieldID ?? title)
                    .accessibilityLabel(spokenLabel ?? title)
                    .accessibilityHint(accessibilityHint)
                    .accessibilityIdentifier(fieldID.map { "numberField.\($0)" } ?? "numberField.\(title)")
                Text(unit)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: Theme.touchTarget)
            .background(Theme.inputFill, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(strokeColor, lineWidth: Theme.Stroke.hairline)
            )
            if let helpText, errorMessage == nil {
                Text(helpText)
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(Theme.muted)
            }
            if let errorMessage {
                FieldValidationText(message: errorMessage)
            }
        }
    }

    private var keyboard: UIKeyboardType {
        if allowsEngineering { return .asciiCapable }
        if allowsScientific { return .numbersAndPunctuation }
        return .decimalPad
    }

    private var accessibilityHint: String {
        let unitBit = optional ? "Optional. Unit \(unit)." : "Unit \(unit)."
        if allowsEngineering {
            return "\(unitBit) Suffixes such as k, M, m, u, n, and p are accepted."
        }
        return unitBit
    }

    private var strokeColor: Color {
        if errorMessage != nil { return Theme.bad.opacity(0.7) }
        if lowConfidence { return Theme.warn.opacity(0.85) }
        return Theme.border
    }
}

/// Alphanumeric / free-text input that matches NumberField chrome without forcing a decimal pad.
struct TextInputField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var optional: Bool = false
    var unit: String = ""
    var autocapitalization: TextInputAutocapitalization = .never
    var fieldID: String? = nil
    var onSubmit: (() -> Void)? = nil
    var lowConfidence: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(Theme.TypeRole.fieldLabel)
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                if optional {
                    Text("optional")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted.opacity(0.7))
                }
                if lowConfidence {
                    Text("check")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.warn)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                TextField(placeholder, text: $text)
                    .keyboardType(.default)
                    .font(.title3.monospaced().weight(.medium))
                    .foregroundStyle(Theme.foreground)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(onSubmit == nil ? .done : .go)
                    .onSubmit { onSubmit?() }
                    .formFieldFocus(fieldID ?? title)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(fieldID.map { "textField.\($0)" } ?? "textField.\(title)")
                if !unit.isEmpty {
                    Text(unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: Theme.touchTarget)
            .background(Theme.inputFill, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(lowConfidence ? Theme.warn.opacity(0.85) : Theme.border, lineWidth: Theme.Stroke.hairline)
            )
        }
    }
}

struct ResultRow: View {
    let label: String
    let value: String
    var emphasis: Bool = false
    var tone: Color = Theme.foreground

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 12)
            Text(value)
                .font(emphasis ? .title3.monospacedDigit().weight(.semibold) : .body.monospacedDigit())
                .foregroundStyle(tone)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct ResultCard<Content: View>: View {
    var title: String = "Results"
    var copyText: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if let copyText, !copyText.isEmpty {
                    CopyResultButton(text: copyText, compact: true, accessibilityName: "Copy \(title) results")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}

struct FormulaCard: View {
    let text: String
    var citation: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FORMULA")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(.body.monospaced())
                .foregroundStyle(Theme.accent)
            if let citation {
                Text(citation)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Theme.accent.opacity(0.12), Theme.accent2.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
        )
        .brandGlow()
    }
}

struct DisclaimerBanner: View {
    var text: String = Theme.disclaimer

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warn)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warn.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SaveJobBar: View {
    @Binding var jobName: String
    var notes: Binding<String>? = nil
    var canSave: Bool
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SAVE A NOTE")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            Text("On-device bench / field snapshot. Not a project gallery.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            HStack(alignment: .center, spacing: 10) {
                TextField("Name this saved note", text: $jobName)
                    .textInputAutocapitalization(.words)
                    .formFieldFocus("jobName")
                    .frame(minHeight: Theme.touchTarget)
                    .accessibilityLabel("Saved note name")
                    .accessibilityHint("Required. Give this result a name before saving.")
                Button("Save", action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.touchTarget)
                    .disabled(!canSave || jobName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityHint(saveAccessibilityHint)
            }
            if let notes {
                TextField("Optional note", text: notes)
                    .font(.subheadline)
                    .foregroundStyle(Theme.foreground)
                    .formFieldFocus("jobNotes")
                    .accessibilityLabel("Optional additional note")
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var saveAccessibilityHint: String {
        if !canSave {
            return "Save is unavailable until a current result is ready."
        }
        if jobName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a name for this saved note."
        }
        return "Saves this result on this device."
    }
}

/// Name plus a hostable page for a finished Voltage Drop or Conduit Fill result.
/// Sits with Save a note. Copy and Jobs stay on device. Not a prompt and not required.
struct ContractorShareBar: View {
    let tool: ContractorShareTool
    let fields: [ContractorShareField]
    var enabled: Bool

    @AppStorage("com.beckify.toolbox.contractorDisplayName") private var contractorName = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var hosted: HostedShareLink?

    private var trimmedName: String {
        contractorName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SHARE A LINK")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
            Text("Public page with this result and the name. Text it from the share sheet. Copy and Jobs stay on this device.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .center, spacing: 10) {
                TextField("Contractor or company", text: $contractorName)
                    .textInputAutocapitalization(.words)
                    .formFieldFocus("contractorName")
                    .frame(minHeight: Theme.touchTarget)
                    .accessibilityLabel("Contractor or company")
                Button(busy ? "Sharing…" : "Share") {
                    Task { await host() }
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .frame(minHeight: Theme.touchTarget)
                .disabled(!enabled || busy || trimmedName.isEmpty)
                .accessibilityIdentifier("contractorShareButton")
            }
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Theme.bad)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("contractorShareError")
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sheet(item: $hosted) { link in
            ActivityShareSheet(items: [link.url])
        }
    }

    private func host() async {
        guard enabled, !busy else { return }
        guard let body = ContractorShareValidation.requestJSON(tool: tool, contractor: contractorName, fields: fields) else {
            errorText = "Enter a name. Calculate again if this result is stale."
            return
        }
        busy = true
        errorText = nil
        defer { busy = false }
        var request = URLRequest(url: ContractorShareLink.createURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 429 {
                errorText = "Too many links. Try again later."
                return
            }
            if status == 503 {
                errorText = "Link hosting is not available right now."
                return
            }
            guard status == 200, let url = ContractorShareLink.acceptedPageURL(from: data) else {
                errorText = "Could not create a link."
                return
            }
            hosted = HostedShareLink(url: url)
        } catch {
            errorText = "Could not create a link."
        }
    }
}

private struct HostedShareLink: Identifiable {
    let id = UUID()
    let url: URL
}

/// Compact Table 250.122 size shown beside inputs (conduit fill, before Calculate).
struct EquipmentGroundingSummary: View {
    var recommendation: EquipmentGroundingRecommendation
    var countedInFill: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MINIMUM EGC")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
            Text("\(recommendation.label) \(recommendation.material.displayName)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.copper)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(recommendation.citation.articleOrTable) · \(recommendation.basisLabel)")
                .font(Theme.TypeRole.help)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if let countedInFill {
                Text(countedInFill
                     ? "Included in this fill (+1 conductor)."
                     : "Not in the fill. Turn Count EGC on to add this one conductor.")
                    .font(Theme.TypeRole.help)
                    .foregroundStyle(countedInFill ? Theme.good : Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.copper.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.copper.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [
            "Minimum equipment grounding conductor \(recommendation.label) \(recommendation.material.displayName).",
            recommendation.citation.articleOrTable,
            recommendation.basisLabel,
        ]
        if let countedInFill {
            parts.append(countedInFill ? "Counted in the fill." : "Not counted in the fill.")
        }
        return parts.joined(separator: " ")
    }
}

/// Shared NEC 2023 Table 250.122 row. Hidden when the circuit does not imply a ground.
struct EquipmentGroundingCard: View {
    var title: String = "Equipment grounding conductor"
    var recommendation: EquipmentGroundingRecommendation?
    var countedInFill: Bool? = nil

    var body: some View {
        if let recommendation {
            ResultCard(title: title, copyText: recommendation.copyLine) {
                ResultRow(label: "Minimum EGC", value: recommendation.label, emphasis: true, tone: Theme.copper)
                ResultRow(label: "Material", value: recommendation.material.displayName)
                ResultRow(label: "Table row", value: "≤ \(recommendation.tableRatingAmps) A")
                ResultRow(label: "Basis", value: recommendation.basisLabel, tone: Theme.muted)
                ResultRow(
                    label: recommendation.citation.articleOrTable,
                    value: recommendation.citation.edition.displayName,
                    tone: Theme.muted
                )
                if let countedInFill {
                    ResultRow(
                        label: "Counted in fill",
                        value: countedInFill ? "Yes · +1 conductor" : "No",
                        tone: countedInFill ? Theme.good : Theme.muted
                    )
                }
                ForEach(Array(recommendation.notes.prefix(4).enumerated()), id: \.offset) { _, note in
                    Text(note)
                        .font(Theme.TypeRole.help)
                        .foregroundStyle(Theme.muted)
                        .padding(.vertical, 2)
                }
            }
        }
    }
}

struct ErrorText: View {
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Can’t calculate")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.bad)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.foreground)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bad.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Can’t calculate. \(message)")
    }
}

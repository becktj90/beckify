import SwiftUI

struct NumberField: View {
    let title: String
    let unit: String
    @Binding var text: String
    var placeholder: String = "0"
    var optional: Bool = false
    var allowsScientific: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                if optional {
                    Text("optional")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted.opacity(0.7))
                }
            }
            HStack(alignment: .firstTextBaseline) {
                TextField(placeholder, text: $text)
                    .keyboardType(allowsScientific ? .numbersAndPunctuation : .decimalPad)
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(Theme.foreground)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text(unit)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
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
    }
}

struct ResultCard<Content: View>: View {
    var title: String = "Results"
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
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
            Text("On-device homework / field snapshot. Not a project gallery.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            HStack {
                TextField("Name — e.g. lab 3, AHU-3 feeder", text: $jobName)
                    .textInputAutocapitalization(.words)
                Button("Save", action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(!canSave || jobName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let notes {
                TextField("Optional note", text: notes)
                    .font(.subheadline)
                    .foregroundStyle(Theme.foreground)
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ErrorText: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(Theme.bad)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bad.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

import SwiftUI
import BeckifyMath

/// Shared Calculate / Reset chrome for explicit engineering worksheets.
struct CalculateActionBar: View {
    var isStale: Bool = false
    var errorMessage: String? = nil
    var successTick: Int = 0
    var onCalculate: () -> Void
    var onReset: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if isStale {
                StaleResultBanner()
            }
            if let errorMessage, !errorMessage.isEmpty {
                ErrorText(message: errorMessage)
            }
            HStack(spacing: Theme.Space.sm) {
                Button(action: onCalculate) {
                    Label("Calculate", systemImage: "equal.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: Theme.touchTarget)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityIdentifier("calculateButton")
                .calculationSuccessPulse(trigger: successTick)

                if let onReset {
                    Button("Reset", action: onReset)
                        .buttonStyle(.bordered)
                        .frame(minHeight: Theme.touchTarget)
                        .accessibilityIdentifier("resetCalculationButton")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct StaleResultBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.xs) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(Theme.warn)
                .accessibilityHidden(true)
            Text("Inputs changed — Calculate again.")
                .font(Theme.TypeRole.help.weight(.semibold))
                .foregroundStyle(Theme.foreground)
        }
        .padding(Theme.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warn.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .stroke(Theme.warn.opacity(0.35), lineWidth: Theme.Stroke.hairline)
        )
        .accessibilityIdentifier("staleResultBanner")
        .accessibilityLabel("Inputs changed. Calculate again.")
    }
}

/// Bottom instrument dock: Calculate (explicit tools) + sticky answer.
struct ToolDock<Accessory: View>: View {
    var stickyAnswer: String?
    var copyText: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            accessory()
            if let stickyAnswer, !stickyAnswer.isEmpty {
                StickyAnswerBar(answer: stickyAnswer, copyText: copyText)
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.top, Theme.Space.xs)
        .padding(.bottom, Theme.Space.xs)
        .background(.bar)
    }
}

extension ToolDock where Accessory == EmptyView {
    init(stickyAnswer: String?, copyText: String?) {
        self.stickyAnswer = stickyAnswer
        self.copyText = copyText
        self.accessory = { EmptyView() }
    }
}

/// Marks a successful explicit calculation with a short, reduced-motion-safe cue.
struct CalculationSuccessPulse: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.success, trigger: trigger)
            .animation(Theme.Motion.preferred(Theme.Motion.result, reduceMotion: reduceMotion), value: trigger)
    }
}

extension View {
    func calculationSuccessPulse(trigger: Int) -> some View {
        modifier(CalculationSuccessPulse(trigger: trigger))
    }
}

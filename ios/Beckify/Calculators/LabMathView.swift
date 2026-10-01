import SwiftUI
import BeckifyMath

/// Typeset transfer math: stacked fractions, subscripts, and superscripts.
/// VoiceOver stays on the plain `LabIO.expression` string; this view is visual.
struct LabMathView: View {
    var math: LabMath
    @ScaledMetric(relativeTo: .body) private var baseSize: CGFloat = 18

    var body: some View {
        node(math, size: baseSize, wrap: true)
            .foregroundStyle(Theme.foreground)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func node(_ math: LabMath, size: CGFloat, wrap: Bool) -> some View {
        switch math {
        case .row(let items):
            if wrap {
                MathFlow(spacing: size * 0.12, lineSpacing: size * 0.22) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        node(item, size: size, wrap: false)
                    }
                }
            } else {
                HStack(alignment: .center, spacing: size * 0.04) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        node(item, size: size, wrap: false)
                    }
                }
                .fixedSize()
            }
        case .fraction(let numerator, let denominator):
            fraction(numerator, denominator, size: size)
        case .radical(let body):
            radical(body, size: size)
        case .glyph(let text, let face):
            Text(text)
                .font(faceFont(size: size, face: face))
                .padding(.horizontal, horizontalPad(face, size: size))
                .fixedSize()
        case .script(let base, let sub, let sup):
            script(base, sub: sub, sup: sup, size: size)
        case .delimited(let body, let open, let close):
            delimited(body, open: open, close: close, size: size)
        }
    }

    private func fraction(_ numerator: LabMath, _ denominator: LabMath, size: CGFloat) -> some View {
        let child = size * 0.86
        return VStack(spacing: max(2, size * 0.16)) {
            node(numerator, size: child, wrap: false)
            node(denominator, size: child, wrap: false)
        }
        .fixedSize()
        .overlay {
            Rectangle()
                .fill(Theme.foreground)
                .frame(height: max(1, size * 0.06))
        }
        .accessibilityElement(children: .ignore)
    }

    private func radical(_ body: LabMath, size: CGFloat) -> some View {
        let tall = body.fractionCount > 0
        return HStack(alignment: .center, spacing: 0) {
            Text("√")
                .font(faceFont(size: size * (tall ? 1.65 : 1.2), face: .upright))
            node(body, size: size * 0.92, wrap: false)
                .padding(.horizontal, size * 0.12)
                .padding(.top, size * 0.08)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.foreground)
                        .frame(height: max(1, size * 0.06))
                }
        }
        .fixedSize()
    }

    private func script(_ base: LabMath, sub: LabMath?, sup: LabMath?, size: CGFloat) -> some View {
        let scriptSize = size * 0.62
        // Padding on the base (not offset) so the subscript hangs below the line
        // and the layout still reserves the space.
        let bottomPad: CGFloat = {
            if sub != nil, sup != nil { return scriptSize * 0.22 }
            if sub != nil { return scriptSize * 0.42 }
            if sup != nil { return scriptSize * 0.95 }
            return 0
        }()
        return HStack(alignment: .bottom, spacing: 0) {
            node(base, size: size, wrap: false)
                .padding(.bottom, bottomPad)
            VStack(alignment: .leading, spacing: 0) {
                if let sup {
                    node(sup, size: scriptSize, wrap: false)
                }
                if let sub {
                    node(sub, size: scriptSize, wrap: false)
                }
            }
        }
        .fixedSize()
    }

    private func delimited(_ body: LabMath, open: String, close: String, size: CGFloat) -> some View {
        let tall = body.fractionCount > 0
        let paren = size * (tall ? 1.9 : 1.05)
        return HStack(alignment: .center, spacing: 1) {
            Text(open)
                .font(faceFont(size: paren, face: .upright))
            node(body, size: size, wrap: false)
            Text(close)
                .font(faceFont(size: paren, face: .upright))
        }
        .fixedSize()
    }

    private func faceFont(size: CGFloat, face: LabMathFace) -> Font {
        switch face {
        case .italic:
            return .system(size: size, weight: .medium, design: .serif).italic()
        case .number:
            return .system(size: size, weight: .semibold, design: .serif)
        case .upright, .relation, .operation:
            return .system(size: size, weight: .medium, design: .serif)
        }
    }

    private func horizontalPad(_ face: LabMathFace, size: CGFloat) -> CGFloat {
        switch face {
        case .relation: return size * 0.18
        case .operation: return size * 0.1
        default: return 0
        }
    }
}

/// Left-to-right row that wraps before a child would overflow. Used for the
/// top-level transfer line so a long H(s) stays inside the card at Dynamic Type.
private struct MathFlow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let lines = lines(maxWidth: maxWidth, subviews: subviews)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.reduce(CGFloat(0)) { $0 + $1.height } + lineSpacing * CGFloat(max(0, lines.count - 1))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let lines = lines(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        var cursor = 0
        for line in lines {
            var x = bounds.minX
            for index in 0..<line.count {
                let sub = subviews[cursor]
                let size = sub.sizeThatFits(.unspecified)
                let dy = line.height - size.height
                sub.place(at: CGPoint(x: x, y: y + max(0, dy / 2)), proposal: ProposedViewSize(size))
                x += size.width + spacing
                cursor += 1
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line {
        var count: Int
        var width: CGFloat
        var height: CGFloat
    }

    private func lines(maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var result: [Line] = []
        var count = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
        func flush() {
            if count > 0 {
                result.append(Line(count: count, width: width, height: height))
                count = 0
                width = 0
                height = 0
            }
        }
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            let next = width == 0 ? size.width : width + spacing + size.width
            if width > 0, next > maxWidth {
                flush()
            }
            width = width == 0 ? size.width : width + spacing + size.width
            height = max(height, size.height)
            count += 1
        }
        flush()
        return result
    }
}

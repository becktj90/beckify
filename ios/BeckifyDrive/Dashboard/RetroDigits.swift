import SwiftUI

/// Seven-segment numerals in Beckify's retro CRT style: lit segments with a
/// soft phosphor glow over faint unlit ones. Digits, minus, dash, decimal
/// point, and space. Hidden from VoiceOver; the parent card speaks the value.
struct RetroDigits: View {
    let text: String
    /// Digit height in points.
    let height: CGFloat
    let color: Color
    var glow = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let glyphs = Self.glyphs(text)
        let width = glyphs.reduce(CGFloat(0)) { $0 + $1.advance(height: height) }
        Canvas { context, size in
            var x: CGFloat = 0
            for glyph in glyphs {
                let cell = CGRect(x: x, y: 0, width: glyph.advance(height: height), height: size.height)
                draw(glyph, in: cell, context: &context)
                x += cell.width
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    // MARK: Glyphs

    enum Glyph: Equatable {
        case segments(Set<Segment>)
        case point
        case space

        func advance(height: CGFloat) -> CGFloat {
            switch self {
            case .segments, .space: return height * 0.62
            case .point: return height * 0.22
            }
        }
    }

    /// a top, b top-right, c bottom-right, d bottom, e bottom-left, f top-left, g middle.
    enum Segment: CaseIterable {
        case a, b, c, d, e, f, g
    }

    static let digitSegments: [Character: Set<Segment>] = [
        "0": [.a, .b, .c, .d, .e, .f],
        "1": [.b, .c],
        "2": [.a, .b, .g, .e, .d],
        "3": [.a, .b, .g, .c, .d],
        "4": [.f, .g, .b, .c],
        "5": [.a, .f, .g, .c, .d],
        "6": [.a, .f, .g, .e, .c, .d],
        "7": [.a, .b, .c],
        "8": [.a, .b, .c, .d, .e, .f, .g],
        "9": [.a, .b, .c, .d, .f, .g],
        "-": [.g],
        "–": [.g],
        "—": [.g],
    ]

    static func glyphs(_ text: String) -> [Glyph] {
        text.map { character in
            if character == "." { return .point }
            if let segments = digitSegments[character] { return .segments(segments) }
            return .space
        }
    }

    // MARK: Drawing

    private func draw(_ glyph: Glyph, in cell: CGRect, context: inout GraphicsContext) {
        switch glyph {
        case .space:
            return
        case .point:
            let side = height * 0.11
            let dot = Path(roundedRect: CGRect(x: cell.midX - side / 2, y: cell.maxY - side, width: side, height: side), cornerRadius: side * 0.2)
            fill(dot, lit: true, context: &context)
        case .segments(let lit):
            for segment in Segment.allCases {
                fill(path(segment, in: cell), lit: lit.contains(segment), context: &context)
            }
        }
    }

    private func fill(_ path: Path, lit: Bool, context: inout GraphicsContext) {
        guard lit else {
            context.fill(path, with: .color(DriveTheme.segmentGhost))
            return
        }
        if glow && colorScheme == .dark {
            var glowing = context
            glowing.addFilter(.blur(radius: height * 0.06))
            glowing.fill(path, with: .color(color.opacity(0.55)))
        }
        context.fill(path, with: .color(color))
    }

    /// Hexagonal segment inside a cell with a small side margin.
    private func path(_ segment: Segment, in cell: CGRect) -> Path {
        let t = height * 0.12
        let gap = t * 0.18
        let margin = cell.width * 0.12
        let left = cell.minX + margin
        let right = cell.maxX - margin
        let top = cell.minY + t / 2
        let bottom = cell.maxY - t / 2
        let middle = cell.midY
        switch segment {
        case .a: return horizontal(from: left, to: right, y: top, t: t, gap: gap)
        case .g: return horizontal(from: left, to: right, y: middle, t: t, gap: gap)
        case .d: return horizontal(from: left, to: right, y: bottom, t: t, gap: gap)
        case .f: return vertical(x: left, from: top, to: middle, t: t, gap: gap)
        case .b: return vertical(x: right, from: top, to: middle, t: t, gap: gap)
        case .e: return vertical(x: left, from: middle, to: bottom, t: t, gap: gap)
        case .c: return vertical(x: right, from: middle, to: bottom, t: t, gap: gap)
        }
    }

    private func horizontal(from x0: CGFloat, to x1: CGFloat, y: CGFloat, t: CGFloat, gap: CGFloat) -> Path {
        let a = x0 + gap
        let b = x1 - gap
        var path = Path()
        path.move(to: CGPoint(x: a, y: y))
        path.addLine(to: CGPoint(x: a + t / 2, y: y - t / 2))
        path.addLine(to: CGPoint(x: b - t / 2, y: y - t / 2))
        path.addLine(to: CGPoint(x: b, y: y))
        path.addLine(to: CGPoint(x: b - t / 2, y: y + t / 2))
        path.addLine(to: CGPoint(x: a + t / 2, y: y + t / 2))
        path.closeSubpath()
        return path
    }

    private func vertical(x: CGFloat, from y0: CGFloat, to y1: CGFloat, t: CGFloat, gap: CGFloat) -> Path {
        let a = y0 + gap
        let b = y1 - gap
        var path = Path()
        path.move(to: CGPoint(x: x, y: a))
        path.addLine(to: CGPoint(x: x + t / 2, y: a + t / 2))
        path.addLine(to: CGPoint(x: x + t / 2, y: b - t / 2))
        path.addLine(to: CGPoint(x: x, y: b))
        path.addLine(to: CGPoint(x: x - t / 2, y: b - t / 2))
        path.addLine(to: CGPoint(x: x - t / 2, y: a + t / 2))
        path.closeSubpath()
        return path
    }
}

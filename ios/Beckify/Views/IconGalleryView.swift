import SwiftUI

/// Scrollable design-review gallery of every toolbox glyph.
struct IconGalleryView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 108, maximum: 140), spacing: Theme.Space.sm),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.Space.md) {
                ForEach(ToolboxCatalog.tools) { tool in
                    IconGalleryCell(tool: tool)
                }
            }
            .padding(Theme.Space.md)
        }
        .background(Theme.background)
        .navigationTitle("Icon Gallery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct IconGalleryCell: View {
    let tool: ToolDefinition

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                    .fill(Theme.iconGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
                            .stroke(Theme.border, lineWidth: Theme.Stroke.hairline)
                    )
                ToolGlyph(kind: .forTool(tool.id), size: 52, selected: true)
            }
            .aspectRatio(1, contentMode: .fit)

            Text(tool.title)
                .font(Theme.TypeRole.sectionLabel)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(tool.id.rawValue)
                .font(.caption2.monospaced())
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .padding(Theme.Space.xs)
        .instrumentPanel(corner: Theme.Radius.card)
    }
}

#Preview("Icon Gallery — Light") {
    NavigationStack {
        IconGalleryView()
    }
    .preferredColorScheme(.light)
}

#Preview("Icon Gallery — Dark") {
    NavigationStack {
        IconGalleryView()
    }
    .preferredColorScheme(.dark)
}

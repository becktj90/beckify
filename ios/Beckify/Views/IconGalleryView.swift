import SwiftUI

/// Side-by-side evaluation of every primary tool glyph for optical consistency.
struct IconGalleryView: View {
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 14)]

    private var tools: [ToolDefinition] { ToolboxCatalog.tools }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(tools) { tool in
                    VStack(spacing: 8) {
                        ToolGlyphBadge(kind: GlyphKind.forTool(tool.id), size: 72)
                        Text(tool.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.foreground)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(tool.title)
                }
            }
            .padding(Theme.Space.md)
        }
        .instrumentPanelBackground()
        .navigationTitle("Icon gallery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

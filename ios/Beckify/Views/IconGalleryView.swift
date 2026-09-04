import SwiftUI
import BeckifyMath

/// Design-review gallery of the Beckify instrument glyph set — category shelf
/// marks plus every per-tool schematic, grouped Field then Toolkit.
struct IconGalleryView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 108, maximum: 140), spacing: Theme.Space.sm),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                categorySection
                ForEach(ToolHomeArea.allCases, id: \.self) { area in
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Text(area.title.uppercased())
                            .font(Theme.TypeRole.sectionLabel)
                            .tracking(0.8)
                            .foregroundStyle(Theme.muted)
                        LazyVGrid(columns: columns, spacing: Theme.Space.md) {
                            ForEach(ToolboxCatalog.tools(in: area)) { tool in
                                IconGalleryCell(tool: tool)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Space.md)
        }
        .background(Theme.background)
        .navigationTitle("Icon Gallery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("CATEGORIES")
                .font(Theme.TypeRole.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(Theme.muted)

            LazyVGrid(columns: columns, spacing: Theme.Space.md) {
                ForEach(ToolCategory.allCases) { category in
                    CategoryGalleryCell(category: category)
                }
            }
        }
    }
}

private struct CategoryGalleryCell: View {
    let category: ToolCategory

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        CategoryWell(category: category, size: geo.size.width)
                    }
                }

            Text(category.displayName)
                .font(Theme.TypeRole.sectionLabel)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(Theme.Space.xs)
        .instrumentPanel(corner: Theme.Radius.card)
    }
}

private struct IconGalleryCell: View {
    let tool: ToolDefinition

    private var area: ToolHomeArea { ToolboxCatalog.area(of: tool.id) }

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        IconWell(toolID: tool.id, size: geo.size.width, selected: true)
                    }
                }

            Text(tool.title)
                .font(Theme.TypeRole.sectionLabel)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            HomeAreaBadge(area: area)

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

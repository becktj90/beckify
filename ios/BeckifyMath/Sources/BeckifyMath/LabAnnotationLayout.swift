import Foundation

/// Screen-space annotation placement for Electronics Lab schematic and breadboard.
/// Prefer 13–15 pt labels with monospaced digits; keep “All” detail in the inspector.
public enum LabAnnotationLayer: String, CaseIterable, Sendable, Identifiable {
    case minimal
    case values
    case measurements
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .minimal: return "Minimal"
        case .values: return "Values"
        case .measurements: return "Measurements"
        case .all: return "All (inspector)"
        }
    }

    /// Layers that may be drawn on the picture itself (not the inspector).
    public static var onPicture: Set<LabAnnotationLayer> {
        [.minimal, .values, .measurements]
    }
}

public struct LabVec2: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct LabRect2: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }

    public func insetBy(_ dx: Double, _ dy: Double) -> LabRect2 {
        LabRect2(x: x + dx, y: y + dy, width: max(0, width - 2 * dx), height: max(0, height - 2 * dy))
    }

    public func intersects(_ other: LabRect2) -> Bool {
        minX < other.maxX && maxX > other.minX && minY < other.maxY && maxY > other.minY
    }

    public func contains(_ point: LabVec2) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

public struct LabAnnotationRequest: Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var anchor: LabVec2
    public var layer: LabAnnotationLayer
    public var preferredOffsets: [LabVec2]
    public var fontSize: Double

    public init(
        id: String,
        text: String,
        anchor: LabVec2,
        layer: LabAnnotationLayer,
        preferredOffsets: [LabVec2] = LabAnnotationEngine.defaultOffsets,
        fontSize: Double = 14
    ) {
        self.id = id
        self.text = text
        self.anchor = anchor
        self.layer = layer
        self.preferredOffsets = preferredOffsets
        self.fontSize = fontSize
    }
}

public struct LabPlacedAnnotation: Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var frame: LabRect2
    public var fontSize: Double
    public var layer: LabAnnotationLayer
    public var leaderFrom: LabVec2?
    public var leaderTo: LabVec2

    public init(
        id: String,
        text: String,
        frame: LabRect2,
        fontSize: Double,
        layer: LabAnnotationLayer,
        leaderFrom: LabVec2?,
        leaderTo: LabVec2
    ) {
        self.id = id
        self.text = text
        self.frame = frame
        self.fontSize = fontSize
        self.layer = layer
        self.leaderFrom = leaderFrom
        self.leaderTo = leaderTo
    }
}

public enum LabAnnotationFormat {
    public static func partLabel(refdes: String, valueText: String?, layer: LabAnnotationLayer) -> String? {
        let ref = refdes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ref.isEmpty else { return nil }
        switch layer {
        case .minimal:
            return ref
        case .values, .measurements, .all:
            if let valueText, !valueText.isEmpty {
                return "\(ref)  \(valueText)"
            }
            return ref
        }
    }

    public static func measurementLabel(name: String, reading: String?, layer: LabAnnotationLayer) -> String? {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        switch layer {
        case .minimal, .values:
            return nil
        case .measurements, .all:
            guard let reading, !reading.isEmpty else { return nil }
            return "\(title)  \(reading)"
        }
    }
}

public enum LabAnnotationEngine {
    public static let defaultFontSize: Double = 14
    public static let minFontSize: Double = 13
    public static let maxFontSize: Double = 15

    public static let defaultOffsets: [LabVec2] = [
        LabVec2(x: 0, y: -18),
        LabVec2(x: 0, y: 18),
        LabVec2(x: 22, y: 0),
        LabVec2(x: -22, y: 0),
        LabVec2(x: 18, y: -16),
        LabVec2(x: -18, y: -16),
        LabVec2(x: 18, y: 16),
        LabVec2(x: -18, y: 16),
        LabVec2(x: 0, y: -34),
        LabVec2(x: 0, y: 34),
        LabVec2(x: 36, y: 0),
        LabVec2(x: -36, y: 0),
    ]

    public static func measure(_ text: String, fontSize: Double) -> (width: Double, height: Double) {
        let size = min(max(fontSize, minFontSize), maxFontSize)
        let width = Double(text.count) * size * 0.62 + 10
        let height = size + 8
        return (width, height)
    }

    public static func place(
        requests: [LabAnnotationRequest],
        obstacles: [LabRect2],
        canvas: LabRect2,
        activeLayers: Set<LabAnnotationLayer>
    ) -> [LabPlacedAnnotation] {
        var placed: [LabPlacedAnnotation] = []
        var occupied = obstacles

        for request in requests {
            guard activeLayers.contains(request.layer) else { continue }
            let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let font = min(max(request.fontSize, minFontSize), maxFontSize)
            let size = measure(trimmed, fontSize: font)
            var chosen: LabPlacedAnnotation?

            for (index, offset) in request.preferredOffsets.enumerated() {
                let center = LabVec2(x: request.anchor.x + offset.x, y: request.anchor.y + offset.y)
                var frame = LabRect2(
                    x: center.x - size.width / 2,
                    y: center.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                frame = clamp(frame, to: canvas)
                if overlaps(frame, occupied) { continue }
                let needsLeader = index >= 4 || hypot(offset.x, offset.y) > 28
                chosen = LabPlacedAnnotation(
                    id: request.id,
                    text: trimmed,
                    frame: frame,
                    fontSize: font,
                    layer: request.layer,
                    leaderFrom: needsLeader ? request.anchor : nil,
                    leaderTo: nearestEdge(from: request.anchor, to: frame)
                )
                break
            }

            if chosen == nil {
                let center = LabVec2(x: request.anchor.x, y: request.anchor.y - 48)
                var frame = LabRect2(
                    x: center.x - size.width / 2,
                    y: center.y - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                frame = clamp(frame, to: canvas)
                var found = false
                for nudge in [0.0, 40, -40, 80, -80, 120, -120] {
                    let trial = LabRect2(x: frame.x + nudge, y: frame.y, width: frame.width, height: frame.height)
                    let clamped = clamp(trial, to: canvas)
                    if !overlaps(clamped, occupied) {
                        frame = clamped
                        found = true
                        break
                    }
                }
                if !found, let free = nearestFreeSlot(size: size, anchor: request.anchor, occupied: occupied, canvas: canvas) {
                    frame = free
                }
                chosen = LabPlacedAnnotation(
                    id: request.id,
                    text: trimmed,
                    frame: frame,
                    fontSize: font,
                    layer: request.layer,
                    leaderFrom: request.anchor,
                    leaderTo: nearestEdge(from: request.anchor, to: frame)
                )
            }

            if let chosen {
                placed.append(chosen)
                occupied.append(chosen.frame.insetBy(-2, -2))
            }
        }
        return placed
    }

    public static func hasOverlap(placed: [LabPlacedAnnotation], obstacles: [LabRect2] = []) -> Bool {
        var rects = obstacles
        for item in placed {
            if overlaps(item.frame, rects) { return true }
            rects.append(item.frame)
        }
        return false
    }

    /// Scans the canvas on a coarse grid and returns the free slot closest to the anchor.
    private static func nearestFreeSlot(
        size: (width: Double, height: Double),
        anchor: LabVec2,
        occupied: [LabRect2],
        canvas: LabRect2
    ) -> LabRect2? {
        guard size.width <= canvas.width, size.height <= canvas.height else { return nil }
        let step = 8.0
        var best: (frame: LabRect2, distance: Double)?
        var y = canvas.minY
        while y + size.height <= canvas.maxY {
            var x = canvas.minX
            while x + size.width <= canvas.maxX {
                let frame = LabRect2(x: x, y: y, width: size.width, height: size.height)
                if !overlaps(frame, occupied) {
                    let distance = hypot(frame.midX - anchor.x, frame.midY - anchor.y)
                    if best == nil || distance < best!.distance { best = (frame, distance) }
                }
                x += step
            }
            y += step
        }
        return best?.frame
    }

    private static func overlaps(_ frame: LabRect2, _ others: [LabRect2]) -> Bool {
        others.contains { $0.intersects(frame) }
    }

    private static func clamp(_ frame: LabRect2, to canvas: LabRect2) -> LabRect2 {
        var x = frame.x
        var y = frame.y
        if frame.width <= canvas.width {
            x = min(max(frame.x, canvas.minX), canvas.maxX - frame.width)
        } else {
            x = canvas.minX
        }
        if frame.height <= canvas.height {
            y = min(max(frame.y, canvas.minY), canvas.maxY - frame.height)
        } else {
            y = canvas.minY
        }
        return LabRect2(x: x, y: y, width: frame.width, height: frame.height)
    }

    private static func nearestEdge(from anchor: LabVec2, to frame: LabRect2) -> LabVec2 {
        let cx = min(max(anchor.x, frame.minX), frame.maxX)
        let cy = min(max(anchor.y, frame.minY), frame.maxY)
        let candidates = [
            LabVec2(x: frame.midX, y: frame.minY),
            LabVec2(x: frame.midX, y: frame.maxY),
            LabVec2(x: frame.minX, y: frame.midY),
            LabVec2(x: frame.maxX, y: frame.midY),
            LabVec2(x: cx, y: cy),
        ]
        return candidates.min(by: {
            hypot($0.x - anchor.x, $0.y - anchor.y) < hypot($1.x - anchor.x, $1.y - anchor.y)
        })!
    }
}

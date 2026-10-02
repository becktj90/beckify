import Foundation

/// Construction identity for drawing and fill — separate from Table 310.16
/// temperature columns. Never infer insulation type from 60 / 75 / 90 °C.
public struct ConductorConstructionProfile: Equatable, Sendable, Hashable {
    public var insulation: ConductorInsulationKind
    /// When true, Table 5 area for `insulation` is listed. When false, the
    /// drawing uses an equivalent-area circle from circular mils and says so.
    public var listedInTable5: Bool

    public init(insulation: ConductorInsulationKind = .thhn, listedInTable5: Bool = true) {
        self.insulation = insulation
        self.listedInTable5 = listedInTable5
    }

    public var displayName: String { insulation.displayName }

    public static let thhn = ConductorConstructionProfile(insulation: .thhn)
    public static let xhhw = ConductorConstructionProfile(insulation: .xhhw)
    public static let rhw = ConductorConstructionProfile(insulation: .rhw)
}

/// One verified set of dimensions for a conductor size + construction.
/// Metal diameter comes from Chapter 9 Table 8 circular mils.
/// Overall diameter comes from Chapter 9 Table 5 area when listed;
/// otherwise from an equivalent-area circle on the metal CM (labeled).
public struct ConductorGeometry: Equatable, Sendable {
    public var size: String
    public var sizeLabel: String
    public var material: ConductorMaterial
    public var construction: ConductorConstructionProfile
    public var circularMils: Double
    public var metalDiameterInches: Double
    public var overallDiameterInches: Double
    public var insulatedAreaSquareInches: Double
    public var insulationWallInches: Double
    /// True when overall OD came from Table 5. False = equivalent-area fallback.
    public var overallFromTable5: Bool
    public var geometryNote: String
    public var citations: [CodeCitation]

    public var metalAreaSquareInches: Double {
        Double.pi * metalDiameterInches * metalDiameterInches / 4
    }
}

public enum ConductorGeometryModel {
    public static let table5Citation = CodeCitation(
        articleOrTable: "Chapter 9 Table 5",
        units: "in²",
        sourceDescription: "Approximate insulated conductor area used for overall diameter. Construction type is selected separately from the 60/75/90 °C ampacity columns."
    )

    public static let table8Citation = CodeCitation(
        articleOrTable: "Chapter 9 Table 8",
        units: "circular mils",
        sourceDescription: "Conductor metal area. Metal diameter = √(CM) / 1000 in."
    )

    /// Resolve geometry for a size. Construction is never invented from temp rating.
    public static func resolve(
        size: String,
        material: ConductorMaterial,
        construction: ConductorConstructionProfile = .thhn
    ) -> ConductorGeometry? {
        guard let cm = NECTables.circularMils[size], cm > 0 else { return nil }
        let metal = sqrt(cm) / 1000
        let listedArea = NECTables.conductorArea(size: size, insulation: construction.insulation)
        let overallFromTable5: Bool
        let area: Double
        let note: String
        if let listed = listedArea, listed > 0, construction.listedInTable5 {
            overallFromTable5 = true
            area = listed
            note = "Overall OD from Chapter 9 Table 5 (\(construction.displayName)). Metal Ø from Table 8. Drawn to scale — not actual size on screen."
        } else {
            // Equivalent-area fallback: circle matching metal CM when insulation
            // area is unknown. Still labeled — never pretend it is Table 5.
            overallFromTable5 = false
            area = Double.pi * metal * metal / 4
            note = "Insulation OD not listed for this construction. Drawing uses an equivalent-area circle on Table 8 metal CM only — not a jacketed Table 5 size."
        }
        let overall = ConduitCrossSection.overallDiameter(areaSquareInches: area)
        let wall = max(0, (overall - metal) / 2)
        return ConductorGeometry(
            size: size,
            sizeLabel: NECTables.wireLabel(size),
            material: material,
            construction: construction,
            circularMils: cm,
            metalDiameterInches: metal,
            overallDiameterInches: overall,
            insulatedAreaSquareInches: area,
            insulationWallInches: wall,
            overallFromTable5: overallFromTable5,
            geometryNote: note,
            citations: [table8Citation, table5Citation]
        )
    }

    /// Diameter of an equivalent-area circle for a given Table 5 area (in).
    public static func overallDiameter(areaSquareInches: Double) -> Double {
        ConduitCrossSection.overallDiameter(areaSquareInches: areaSquareInches)
    }
}

/// Role of a drawn conductor in the Wire Size & Ampacity section.
public enum AmpacityConductorRole: String, Equatable, Sendable, Hashable {
    case phase
    case egc

    public var shortLabel: String {
        switch self {
        case .phase: return "Phase"
        case .egc: return "EGC"
        }
    }
}

public struct AmpacityDrawnConductor: Equatable, Sendable, Identifiable {
    public var id: Int
    public var role: AmpacityConductorRole
    public var geometry: ConductorGeometry
    /// Center in inches, orthographic view, origin at layout center.
    public var centerXInches: Double
    public var centerYInches: Double
}

public struct AmpacityCallout: Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: Kind
    public var title: String
    public var value: String
    public var anchorXInches: Double
    public var anchorYInches: Double
    public var labelXInches: Double
    public var labelYInches: Double

    public enum Kind: String, Equatable, Sendable {
        case geometry
        case ampacity
    }
}

public struct AmpacityInspectorRow: Equatable, Sendable, Identifiable {
    public var id: String
    public var section: Section
    public var title: String
    public var value: String

    public enum Section: String, Equatable, Sendable {
        case geometry
        case ampacity
    }
}

/// Orthographic cross-section for Wire Size & Ampacity.
/// Parallel phase conductors are individual equals. Optional EGC shares the scale.
public struct AmpacityConductorLayout: Equatable, Sendable {
    public var phaseGeometry: ConductorGeometry
    public var egcGeometry: ConductorGeometry?
    public var parallelRuns: Int
    public var conductors: [AmpacityDrawnConductor]
    public var callouts: [AmpacityCallout]
    public var inspectorRows: [AmpacityInspectorRow]
    public var scaleBarInches: Double
    public var viewWidthInches: Double
    public var viewHeightInches: Double
    public var packingNote: String
    public var accessibilitySummary: String

    public static func make(
        phase: ConductorGeometry,
        egc: ConductorGeometry?,
        parallelRuns: Int,
        usableAmps: Double?,
        requiredAmps: Double?,
        ambientC: Double?,
        ccc: Int?,
        limitedByTermination: Bool?
    ) -> AmpacityConductorLayout {
        let runs = max(parallelRuns, 1)
        let gap = phase.overallDiameterInches * 0.12
        let pitch = phase.overallDiameterInches + gap
        var drawn: [AmpacityDrawnConductor] = []
        let phaseSpan = Double(runs - 1) * pitch
        let startX = -phaseSpan / 2
        for i in 0..<runs {
            drawn.append(AmpacityDrawnConductor(
                id: i,
                role: .phase,
                geometry: phase,
                centerXInches: startX + Double(i) * pitch,
                centerYInches: 0
            ))
        }
        if let egc {
            let egcX = (drawn.map(\.centerXInches).max() ?? 0)
                + phase.overallDiameterInches / 2
                + egc.overallDiameterInches / 2
                + gap * 2
            drawn.append(AmpacityDrawnConductor(
                id: runs,
                role: .egc,
                geometry: egc,
                centerXInches: egcX,
                centerYInches: 0
            ))
        }

        let maxR = drawn.map { abs($0.centerXInches) + $0.geometry.overallDiameterInches / 2 }.max() ?? phase.overallDiameterInches
        let heightPad = max(phase.overallDiameterInches, egc?.overallDiameterInches ?? 0) * 1.8
        let viewW = max(maxR * 2 + phase.overallDiameterInches * 0.8, phase.overallDiameterInches * 3)
        let viewH = heightPad * 2.4

        // Scale bar: prefer a round inch fraction near one overall OD.
        let scaleBar = preferredScaleBar(near: phase.overallDiameterInches)

        let callouts = placeCallouts(
            phase: phase,
            firstPhase: drawn.first { $0.role == .phase },
            egc: drawn.first { $0.role == .egc },
            usableAmps: usableAmps,
            requiredAmps: requiredAmps,
            viewHalfWidth: viewW / 2,
            viewHalfHeight: viewH / 2
        )

        var rows: [AmpacityInspectorRow] = [
            AmpacityInspectorRow(id: "size", section: .geometry, title: "Size", value: phase.sizeLabel),
            AmpacityInspectorRow(id: "mat", section: .geometry, title: "Material", value: phase.material.displayName),
            AmpacityInspectorRow(id: "const", section: .geometry, title: "Construction", value: phase.construction.displayName),
            AmpacityInspectorRow(id: "cm", section: .geometry, title: "Circular mils", value: formatCM(phase.circularMils)),
            AmpacityInspectorRow(id: "metal", section: .geometry, title: "Metal Ø", value: inch(phase.metalDiameterInches)),
            AmpacityInspectorRow(id: "od", section: .geometry, title: "Overall Ø", value: inch(phase.overallDiameterInches) + (phase.overallFromTable5 ? "" : " (equiv.)")),
            AmpacityInspectorRow(id: "wall", section: .geometry, title: "Insulation wall", value: inch(phase.insulationWallInches)),
            AmpacityInspectorRow(id: "runs", section: .geometry, title: "Parallel phase conductors", value: "\(runs)"),
        ]
        if let egc {
            rows.append(AmpacityInspectorRow(id: "egc", section: .geometry, title: "EGC", value: "\(egc.sizeLabel) · \(inch(egc.overallDiameterInches)) OD"))
        }
        if let ambientC {
            rows.append(AmpacityInspectorRow(id: "amb", section: .ampacity, title: "Ambient", value: String(format: "%.0f °C", ambientC)))
        }
        if let ccc {
            rows.append(AmpacityInspectorRow(id: "ccc", section: .ampacity, title: "CCC count", value: "\(ccc)"))
        }
        if let usableAmps {
            rows.append(AmpacityInspectorRow(id: "usable", section: .ampacity, title: "Usable ampacity", value: FormatTrace.amps(usableAmps)))
        }
        if let requiredAmps {
            rows.append(AmpacityInspectorRow(id: "req", section: .ampacity, title: "Required", value: FormatTrace.amps(requiredAmps)))
        }
        if let limitedByTermination {
            rows.append(AmpacityInspectorRow(
                id: "clamp",
                section: .ampacity,
                title: "Clamp that won",
                value: limitedByTermination ? "Termination (110.14(C))" : "Ambient × CCC"
            ))
        }

        let packing: String
        if phase.overallFromTable5 {
            packing = "Drawn to scale from Table 5 / Table 8 numbers. Not actual size on this screen."
        } else {
            packing = "Drawn to scale on an equivalent-area metal circle. Insulation OD not listed — not actual size on this screen."
        }

        var summaryParts = [
            "\(phase.sizeLabel) \(phase.material.displayName) \(phase.construction.displayName).",
            "Metal diameter \(inch(phase.metalDiameterInches)), overall \(inch(phase.overallDiameterInches)).",
        ]
        if runs > 1 {
            summaryParts.append("\(runs) parallel phase conductors drawn as individual equals.")
        }
        if let egc {
            summaryParts.append("EGC \(egc.sizeLabel) at the same scale.")
        }
        if let usableAmps {
            summaryParts.append("Usable \(FormatTrace.amps(usableAmps)).")
        }
        summaryParts.append(packing)

        return AmpacityConductorLayout(
            phaseGeometry: phase,
            egcGeometry: egc,
            parallelRuns: runs,
            conductors: drawn,
            callouts: callouts,
            inspectorRows: rows,
            scaleBarInches: scaleBar,
            viewWidthInches: viewW,
            viewHeightInches: viewH,
            packingNote: packing,
            accessibilitySummary: summaryParts.joined(separator: " ")
        )
    }

    private static func inch(_ value: Double) -> String {
        String(format: "%.3f in", value)
    }

    private static func formatCM(_ value: Double) -> String {
        if value >= 1000 {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return (formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))") + " CM"
        }
        return String(format: "%.0f CM", value)
    }

    private static func preferredScaleBar(near reference: Double) -> Double {
        let candidates: [Double] = [0.05, 0.1, 0.2, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0]
        return candidates.min(by: { abs($0 - reference) < abs($1 - reference) }) ?? reference
    }

    /// Collision-aware leaders: try preferred slots, skip overlaps with conductors and other labels.
    private static func placeCallouts(
        phase: ConductorGeometry,
        firstPhase: AmpacityDrawnConductor?,
        egc: AmpacityDrawnConductor?,
        usableAmps: Double?,
        requiredAmps: Double?,
        viewHalfWidth: Double,
        viewHalfHeight: Double
    ) -> [AmpacityCallout] {
        guard let first = firstPhase else { return [] }
        let r = phase.overallDiameterInches / 2
        var placed: [AmpacityCallout] = []
        var occupied: [(x: Double, y: Double, w: Double, h: Double)] = []

        func occupies(x: Double, y: Double, w: Double = 0.55, h: Double = 0.22) {
            occupied.append((x, y, w, h))
        }

        func collides(_ x: Double, _ y: Double, w: Double = 0.55, h: Double = 0.22) -> Bool {
            for box in occupied {
                if abs(x - box.x) < (w + box.w) / 2 && abs(y - box.y) < (h + box.h) / 2 {
                    return true
                }
            }
            // Keep labels outside the conductor disks.
            for c in [firstPhase, egc].compactMap({ $0 }) {
                let dx = x - c.centerXInches
                let dy = y - c.centerYInches
                let keepOut = c.geometry.overallDiameterInches / 2 + 0.12
                if dx * dx + dy * dy < keepOut * keepOut { return true }
            }
            return abs(x) > viewHalfWidth - 0.05 || abs(y) > viewHalfHeight - 0.05
        }

        func place(
            id: String,
            kind: AmpacityCallout.Kind,
            title: String,
            value: String,
            anchorX: Double,
            anchorY: Double,
            candidates: [(Double, Double)]
        ) {
            for (lx, ly) in candidates where !collides(lx, ly) {
                placed.append(AmpacityCallout(
                    id: id,
                    kind: kind,
                    title: title,
                    value: value,
                    anchorXInches: anchorX,
                    anchorYInches: anchorY,
                    labelXInches: lx,
                    labelYInches: ly
                ))
                occupies(x: lx, y: ly)
                return
            }
        }

        let metalAnchorX = first.centerXInches
        let metalAnchorY = first.centerYInches + phase.metalDiameterInches / 2
        place(
            id: "metal",
            kind: .geometry,
            title: "Metal Ø",
            value: inch(phase.metalDiameterInches),
            anchorX: metalAnchorX,
            anchorY: metalAnchorY,
            candidates: [
                (first.centerXInches - r - 0.35, first.centerYInches + r + 0.25),
                (first.centerXInches - r - 0.45, first.centerYInches),
                (first.centerXInches, first.centerYInches + r + 0.4),
            ]
        )

        let odAnchorX = first.centerXInches + r
        let odAnchorY = first.centerYInches
        place(
            id: "od",
            kind: .geometry,
            title: "Overall Ø",
            value: inch(phase.overallDiameterInches),
            anchorX: odAnchorX,
            anchorY: odAnchorY,
            candidates: [
                (first.centerXInches + r + 0.4, first.centerYInches + r + 0.15),
                (first.centerXInches + r + 0.45, first.centerYInches - r - 0.2),
                (first.centerXInches, first.centerYInches - r - 0.4),
            ]
        )

        if let usableAmps {
            place(
                id: "usable",
                kind: .ampacity,
                title: "Usable",
                value: FormatTrace.amps(usableAmps),
                anchorX: first.centerXInches,
                anchorY: first.centerYInches - r,
                candidates: [
                    (first.centerXInches - r - 0.4, first.centerYInches - r - 0.3),
                    (first.centerXInches + r + 0.35, first.centerYInches - r - 0.35),
                    (first.centerXInches, first.centerYInches - r - 0.55),
                ]
            )
        }

        if let requiredAmps {
            place(
                id: "required",
                kind: .ampacity,
                title: "Required",
                value: FormatTrace.amps(requiredAmps),
                anchorX: first.centerXInches,
                anchorY: first.centerYInches + r,
                candidates: [
                    (first.centerXInches + r + 0.4, first.centerYInches + r + 0.35),
                    (first.centerXInches - r - 0.35, first.centerYInches + r + 0.4),
                    (first.centerXInches, first.centerYInches + r + 0.55),
                ]
            )
        }

        if let egc {
            place(
                id: "egc",
                kind: .geometry,
                title: "EGC",
                value: egc.geometry.sizeLabel,
                anchorX: egc.centerXInches,
                anchorY: egc.centerYInches + egc.geometry.overallDiameterInches / 2,
                candidates: [
                    (egc.centerXInches + egc.geometry.overallDiameterInches / 2 + 0.35, egc.centerYInches),
                    (egc.centerXInches, egc.centerYInches + egc.geometry.overallDiameterInches / 2 + 0.35),
                    (egc.centerXInches, egc.centerYInches - egc.geometry.overallDiameterInches / 2 - 0.35),
                ]
            )
        }

        return placed
    }
}

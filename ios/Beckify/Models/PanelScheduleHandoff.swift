import Foundation
import BeckifyMath

/// Seeds Load Calculation Worksheet from a confirmed panel schedule.
/// Always preview merge/replace + provenance before writing.
enum PanelScheduleHandoff {
    static func preview(
        circuits: [PanelCircuitDraft],
        voltage: Double,
        phases: Int,
        occupancy: LoadWorksheetOccupancy,
        mode: PanelHandoffMode,
        coverage: PanelCoverage,
        confirmed: Bool,
        agentID: String
    ) -> PanelWorksheetHandoffPreview {
        let existing = readExistingTotals()
        return PanelWorksheetHandoff.preview(
            circuits: circuits,
            voltage: voltage,
            phases: phases,
            occupancy: occupancy,
            mode: mode,
            existing: existing,
            coverage: coverage,
            confirmed: confirmed,
            agentID: agentID
        )
    }

    static func apply(_ preview: PanelWorksheetHandoffPreview) {
        let values = PanelWorksheetHandoff.values(for: preview)
        func write(_ field: String, _ value: Double) {
            let rounded = value.rounded()
            let text = rounded == 0 ? "0" : String(format: "%.0f", rounded)
            UserDefaults.standard.set(text, forKey: ToolInputStore.key(.loadWorksheet, field))
        }
        write("lightVA", values[.lighting] ?? 0)
        write("receptVA", values[.receptacle] ?? 0)
        write("contVA", values[.continuous] ?? 0)
        write("motorVA", values[.motor] ?? 0)
        UserDefaults.standard.set(preview.occupancy.rawValue, forKey: ToolInputStore.key(.loadWorksheet, "occ"))
        UserDefaults.standard.set(String(format: "%.0f", preview.voltage), forKey: ToolInputStore.key(.loadWorksheet, "volts"))
        UserDefaults.standard.set("\(preview.phases)", forKey: ToolInputStore.key(.loadWorksheet, "phases"))
        UserDefaults.standard.set(preview.provenance.joined(separator: "\n"), forKey: ToolInputStore.key(.loadWorksheet, "panelHandoffProvenance"))
        UserDefaults.standard.set(preview.mode.rawValue, forKey: ToolInputStore.key(.loadWorksheet, "panelHandoffMode"))
    }

    static func seedWorksheet(
        circuits: [PanelCircuitDraft],
        voltage: Double,
        phases: Int,
        occupancy: LoadWorksheetOccupancy
    ) {
        let preview = preview(
            circuits: circuits,
            voltage: voltage,
            phases: phases,
            occupancy: occupancy,
            mode: .replace,
            coverage: PanelCoverage.from(circuits: circuits, expectedSlots: nil, inferredSlots: 0),
            confirmed: true,
            agentID: "panel-handoff"
        )
        apply(preview)
    }

    private static func readExistingTotals() -> [LoadRowType: Double] {
        func read(_ field: String) -> Double {
            Double(UserDefaults.standard.string(forKey: ToolInputStore.key(.loadWorksheet, field)) ?? "") ?? 0
        }
        var totals: [LoadRowType: Double] = [:]
        let light = read("lightVA"); if light != 0 { totals[.lighting] = light }
        let recept = read("receptVA"); if recept != 0 { totals[.receptacle] = recept }
        let cont = read("contVA"); if cont != 0 { totals[.continuous] = cont }
        let motor = read("motorVA"); if motor != 0 { totals[.motor] = motor }
        return totals
    }
}

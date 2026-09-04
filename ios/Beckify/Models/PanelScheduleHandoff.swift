import Foundation
import BeckifyMath

/// Seeds Load Calculation Worksheet from a confirmed panel schedule.
/// Writes the same on-device keys that tool already persists — not a cloud handoff.
enum PanelScheduleHandoff {
    static func seedWorksheet(
        circuits: [PanelCircuitDraft],
        voltage: Double,
        phases: Int,
        occupancy: LoadWorksheetOccupancy
    ) {
        let totals = PanelScheduleDemand.categoryTotals(
            from: circuits,
            voltage: voltage,
            phases: phases
        )
        func write(_ field: String, _ value: Double) {
            let rounded = value.rounded()
            let text = rounded == 0 ? "0" : String(format: "%.0f", rounded)
            UserDefaults.standard.set(text, forKey: ToolInputStore.key(.loadWorksheet, field))
        }
        write("lightVA", totals[.lighting] ?? 0)
        write("receptVA", totals[.receptacle] ?? 0)
        write("contVA", totals[.continuous] ?? 0)
        write("motorVA", totals[.motor] ?? 0)
        UserDefaults.standard.set(
            occupancy.rawValue,
            forKey: ToolInputStore.key(.loadWorksheet, "occ")
        )
        UserDefaults.standard.set(
            String(format: "%.0f", voltage),
            forKey: ToolInputStore.key(.loadWorksheet, "volts")
        )
        UserDefaults.standard.set(
            "\(phases)",
            forKey: ToolInputStore.key(.loadWorksheet, "phases")
        )
    }
}

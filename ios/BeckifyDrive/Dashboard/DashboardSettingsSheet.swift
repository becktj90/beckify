import BeckifyMath
import SwiftUI

/// Units, appearance, and which cards show in what order. Tap Edit to drag.
struct DashboardSettingsSheet: View {
    @ObservedObject var preferences: DashboardPreferences
    let layout: DriveLayout
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Speed", selection: $preferences.units.speed) {
                        ForEach(DriveSpeedUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    Picker("Temperature", selection: $preferences.units.temperature) {
                        ForEach(DriveTemperatureUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    Picker("Power", selection: $preferences.units.power) {
                        ForEach(DrivePowerUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    Picker("Torque", selection: $preferences.units.torque) {
                        ForEach(DriveTorqueUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    Button("Use Region Settings") {
                        preferences.useSystemUnits()
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text("Distance, altitude, and pressure follow the speed unit.")
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $preferences.appearance) {
                        ForEach(DriveAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                ForEach(DashboardSection.sections(for: layout), id: \.self) { section in
                    Section(section.title) {
                        ForEach(preferences.layout.cards(in: section, for: layout, includeHidden: true), id: \.self) { card in
                            Toggle(card.title, isOn: visibility(of: card))
                        }
                        .onMove { offsets, destination in
                            preferences.layout.move(in: section, for: layout, from: offsets, to: destination)
                        }
                    }
                }

                Section {
                    Button("Reset Card Layout", role: .destructive) {
                        preferences.layout.reset()
                    }
                } footer: {
                    Text("Tap Edit to drag cards within a section. Hidden cards keep their place.")
                }
            }
            .tint(DriveTheme.accent)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func visibility(of card: DashboardCardID) -> Binding<Bool> {
        Binding(
            get: { !preferences.layout.isHidden(card) },
            set: { preferences.layout.setHidden(card, !$0) }
        )
    }
}

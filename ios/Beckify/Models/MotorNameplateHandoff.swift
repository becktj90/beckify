import Foundation
import BeckifyMath

/// Seeds Motor FLA / Nameplate Analyzer / Speed from a confirmed OCR review.
/// Writes the same on-device keys those tools already persist — not a cloud handoff.
enum MotorNameplateHandoff {
    static func seed(_ fields: [NameplateFieldID: String], into tool: ToolID) {
        let phase = fields[.phase] ?? ""
        let threePhase = phase != "1"
        let hpRaw = fields[.horsepower] ?? ""
        let voltsRaw = fields[.voltage] ?? ""
        let ampsRaw = fields[.amps] ?? ""
        let rpmRaw = fields[.rpm] ?? ""
        let hzRaw = fields[.frequency] ?? ""
        let sfRaw = fields[.serviceFactor] ?? ""

        switch tool {
        case .motorFLA:
            UserDefaults.standard.set(threePhase, forKey: ToolInputStore.key(.motorFLA, "threePhase"))
            if let hpValue = MotorFLA.horsepowerValue(hpRaw),
               let listed = MotorFLA.nearestListedHorsepower(value: hpValue, threePhase: threePhase) {
                UserDefaults.standard.set(listed, forKey: ToolInputStore.key(.motorFLA, "hp"))
            }
            if !voltsRaw.isEmpty {
                UserDefaults.standard.set(
                    NameplateFieldParser.preferredVoltage(raw: voltsRaw, threePhase: threePhase),
                    forKey: ToolInputStore.key(.motorFLA, "systemVolts")
                )
            }

        case .motorNameplate:
            if !ampsRaw.isEmpty {
                UserDefaults.standard.set(
                    NameplateFieldParser.preferredAmps(raw: ampsRaw, threePhase: threePhase),
                    forKey: ToolInputStore.key(.motorNameplate, "fla")
                )
            }
            if !hpRaw.isEmpty {
                UserDefaults.standard.set(hpRaw, forKey: ToolInputStore.key(.motorNameplate, "hp"))
            }
            if !voltsRaw.isEmpty {
                UserDefaults.standard.set(voltsRaw, forKey: ToolInputStore.key(.motorNameplate, "volts"))
            }
            if !sfRaw.isEmpty {
                UserDefaults.standard.set(sfRaw, forKey: ToolInputStore.key(.motorNameplate, "sf"))
            }
            if phase == "1" || phase == "3" {
                UserDefaults.standard.set(phase, forKey: ToolInputStore.key(.motorNameplate, "phases"))
            }

        case .motorSpeed:
            if !rpmRaw.isEmpty {
                UserDefaults.standard.set(rpmRaw, forKey: ToolInputStore.key(.motorSpeed, "rpm"))
                UserDefaults.standard.set(rpmRaw, forKey: ToolInputStore.key(.motorSpeed, "torqueRPM"))
            }
            if !hpRaw.isEmpty {
                UserDefaults.standard.set(hpRaw, forKey: ToolInputStore.key(.motorSpeed, "hp"))
            }
            let hz = NameplateFieldParser.frequencyHertz(hzRaw) ?? 60
            let line = hz == 50 ? "50 Hz" : "60 Hz"
            UserDefaults.standard.set(line, forKey: ToolInputStore.key(.motorSpeed, "line"))
            if let rpm = Double(NameplateFieldParser.primaryToken(rpmRaw)),
               let poles = NameplateFieldParser.inferredPoles(rpm: rpm, frequencyHz: hz) {
                UserDefaults.standard.set("\(poles)", forKey: ToolInputStore.key(.motorSpeed, "poles"))
            }

        default:
            break
        }
    }
}

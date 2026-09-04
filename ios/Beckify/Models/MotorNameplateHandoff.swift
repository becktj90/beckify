import Foundation
import BeckifyMath

/// Seeds Motor FLA / Nameplate Analyzer / Speed from a confirmed OCR review.
/// Writes the same on-device keys those tools already persist — not a cloud handoff.
enum MotorNameplateHandoff {
    static func seed(_ fields: [NameplateFieldID: String], into tool: ToolID) {
        let phase = fields[.phases] ?? ""
        let threePhase = NameplateFieldParser.explicitThreePhase(phase)
        let hpRaw = fields[.ratedHP] ?? ""
        let voltsRaw = fields[.voltage] ?? ""
        // Hard rule: only FLA seeds Analyzer FLA. Never MOCP or LRA.
        let ampsRaw = fields[.fla] ?? ""
        let rpmRaw = fields[.rpm] ?? ""
        let hzRaw = fields[.frequencyHz] ?? ""
        let sfRaw = fields[.sf] ?? ""
        let codeRaw = fields[.codeLetter] ?? ""
        let polesRaw = fields[.poles] ?? ""

        switch tool {
        case .motorFLA:
            if let threePhase {
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
            } else {
                if !hpRaw.isEmpty {
                    UserDefaults.standard.set(hpRaw, forKey: ToolInputStore.key(.motorFLA, "hp"))
                }
                if !voltsRaw.isEmpty {
                    UserDefaults.standard.set(
                        NameplateFieldParser.primaryToken(voltsRaw),
                        forKey: ToolInputStore.key(.motorFLA, "systemVolts")
                    )
                }
            }

        case .motorNameplate:
            if !ampsRaw.isEmpty {
                UserDefaults.standard.set(
                    NameplateFieldParser.preferredToken(raw: ampsRaw, phase: phase),
                    forKey: ToolInputStore.key(.motorNameplate, "fla")
                )
            }
            if !hpRaw.isEmpty {
                UserDefaults.standard.set(hpRaw, forKey: ToolInputStore.key(.motorNameplate, "hp"))
            }
            if !voltsRaw.isEmpty {
                UserDefaults.standard.set(
                    NameplateFieldParser.preferredToken(raw: voltsRaw, phase: phase),
                    forKey: ToolInputStore.key(.motorNameplate, "volts")
                )
            }
            if !sfRaw.isEmpty {
                UserDefaults.standard.set(sfRaw, forKey: ToolInputStore.key(.motorNameplate, "sf"))
            }
            if phase == "1" || phase == "3" {
                UserDefaults.standard.set(phase, forKey: ToolInputStore.key(.motorNameplate, "phases"))
            }
            if !codeRaw.isEmpty {
                UserDefaults.standard.set(codeRaw, forKey: ToolInputStore.key(.motorNameplate, "code"))
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
            if !polesRaw.isEmpty {
                UserDefaults.standard.set(polesRaw, forKey: ToolInputStore.key(.motorSpeed, "poles"))
            } else if let rpm = Double(NameplateFieldParser.primaryToken(rpmRaw)),
                      let poles = NameplateFieldParser.inferredPoles(rpm: rpm, frequencyHz: hz) {
                UserDefaults.standard.set("\(poles)", forKey: ToolInputStore.key(.motorSpeed, "poles"))
            }

        default:
            break
        }
    }
}

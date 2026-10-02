import Foundation

/// Shared electrical identity across solver, schematic, breadboard, inspector, and instruments.
/// Readings come only from the solved `LabSolution` — never invented.
public enum LabIdentityKind: String, Sendable, CaseIterable {
    case component
    case node
    case net
    case branch
    case quantity
}

public struct LabIdentity: Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: LabIdentityKind
    public var displayName: String
    public var refdes: String?
    public var net: String?
    public var valueText: String?
    public var detail: String?

    public init(
        id: String,
        kind: LabIdentityKind,
        displayName: String,
        refdes: String? = nil,
        net: String? = nil,
        valueText: String? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.refdes = refdes
        self.net = net
        self.valueText = valueText
        self.detail = detail
    }

    public var searchableText: String {
        [displayName, refdes, net, valueText, detail, kind.rawValue]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }
}

public enum LabIdentityBook {
    public static func identities(solution: LabSolution, layout: BreadboardLayout?) -> [LabIdentity] {
        var items: [LabIdentity] = []
        var seenNets = Set<String>()

        for element in solution.elements where element.part != .wire && element.part != .line && element.part != .ground {
            let ref = element.label.isEmpty ? element.id.uppercased() : element.label
            let value = element.detail.isEmpty ? nil : element.detail
            items.append(LabIdentity(
                id: "comp:\(element.id)",
                kind: .component,
                displayName: ref,
                refdes: ref,
                valueText: value,
                detail: element.part.rawValue
            ))
        }

        if let layout {
            for component in layout.components {
                let nets = component.leads.map(\.net).filter { !$0.isEmpty }
                for net in nets { seenNets.insert(net) }
                let name = breadboardName(component)
                if let index = items.firstIndex(where: { $0.id == "comp:\(component.id)" }) {
                    items[index].net = nets.joined(separator: "–")
                } else {
                    items.append(LabIdentity(
                        id: "bb:\(component.id)",
                        kind: .component,
                        displayName: name,
                        refdes: component.id.uppercased(),
                        net: nets.joined(separator: "–"),
                        valueText: breadboardValue(component),
                        detail: "breadboard"
                    ))
                }
            }
            for jumper in layout.jumpers where !jumper.net.isEmpty {
                seenNets.insert(jumper.net)
            }
            for supply in layout.supplies {
                for lead in supply.leads where !lead.net.isEmpty {
                    seenNets.insert(lead.net)
                }
            }
        }

        for node in solution.nodes {
            seenNets.insert(node.name)
            items.append(LabIdentity(
                id: "node:\(node.id)",
                kind: .node,
                displayName: node.name,
                net: node.name,
                valueText: LabKit.si(node.value, unit: node.unit.isEmpty ? "V" : node.unit)
            ))
        }

        for branch in solution.branches {
            items.append(LabIdentity(
                id: "branch:\(branch.id)",
                kind: .branch,
                displayName: branch.name,
                valueText: LabKit.si(branch.value, unit: branch.unit.isEmpty ? "A" : branch.unit)
            ))
        }

        for quantity in solution.quantities {
            items.append(LabIdentity(
                id: "qty:\(quantity.id)",
                kind: .quantity,
                displayName: quantity.name,
                valueText: LabKit.si(quantity.value, unit: quantity.unit)
            ))
        }

        for net in seenNets.sorted() where !items.contains(where: { $0.kind == .net && $0.net == net }) {
            let nodeReading = solution.nodes.first { $0.name == net || $0.id == net }
            items.append(LabIdentity(
                id: "net:\(net)",
                kind: .net,
                displayName: net,
                net: net,
                valueText: nodeReading.map { LabKit.si($0.value, unit: $0.unit.isEmpty ? "V" : $0.unit) }
            ))
        }

        return items
    }

    public static func filter(_ items: [LabIdentity], query: String) -> [LabIdentity] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { $0.searchableText.contains(q) }
    }

    public static func netsTouched(by identity: LabIdentity, layout: BreadboardLayout?) -> Set<String> {
        var nets = Set<String>()
        if let net = identity.net {
            for part in net.split(separator: "–").map(String.init) where !part.isEmpty {
                nets.insert(part)
            }
        }
        guard let layout else { return nets }
        if identity.id.hasPrefix("bb:") || identity.id.hasPrefix("comp:") {
            let key = identity.id.split(separator: ":").last.map(String.init) ?? ""
            if let component = layout.component(key) {
                for lead in component.leads where !lead.net.isEmpty {
                    nets.insert(lead.net)
                }
            }
        }
        return nets
    }

    private static func breadboardName(_ component: BBComponent) -> String {
        switch component.part {
        case .resistor(_, let label, _): return label
        case .ceramic(_, let label), .electrolytic(_, let label): return label
        case .led(let label), .diode(let label): return label
        case .inductor(_, let label): return label
        case .npn(let name), .nmos(let name), .pmos(let name): return name
        case .dip8(let name, _): return name
        case .display(let name, let digit, _, _): return "\(name) digit \(digit)"
        case .source(let label): return label
        }
    }

    private static func breadboardValue(_ component: BBComponent) -> String? {
        switch component.part {
        case .resistor(let ohms, _, _): return LabKit.si(ohms, unit: "Ω")
        case .ceramic(let farads, _), .electrolytic(let farads, _): return LabKit.si(farads, unit: "F")
        case .inductor(let henries, _): return LabKit.si(henries, unit: "H")
        default: return nil
        }
    }
}

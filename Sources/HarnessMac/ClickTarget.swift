import ApplicationServices
import CoreGraphics
import Foundation

/// Checks that a click at a point would land on the element it's meant for, so a press that has to
/// fall back to a click doesn't hit whatever covers that element.
enum ClickTarget {
    /// How the element at a point relates to the element meant to be clicked.
    enum Relation: Equatable {
        /// The element itself, something inside it, or one of its containers.
        case lands
        /// Something else, which a click there would hit instead.
        case covered
    }

    /// How `hit` relates to `target`, given each one's chain of containers, nearest first.
    static func relation<Element: Equatable>(hit: Element, hitAncestors: [Element], target: Element, targetAncestors: [Element]) -> Relation {
        if hit == target || hitAncestors.contains(target) || targetAncestors.contains(hit) { return .lands }
        return .covered
    }

    /// The element of `pid` that covers `target` at `point`, or nil when a click there lands on it or
    /// accessibility can't say what's there.
    static func cover(at point: CGPoint, of target: AXUIElement, pid: pid_t) -> AXUIElement? {
        var found: AXUIElement?
        var owner: pid_t = 0
        guard AXUIElementCopyElementAtPosition(AX.application(pid), Float(point.x), Float(point.y), &found) == .success,
              let hit = found, AXUIElementGetPid(hit, &owner) == .success, owner == pid else { return nil }
        let relation = relation(hit: Wrapped(hit), hitAncestors: ancestors(of: hit).map(Wrapped.init), target: Wrapped(target), targetAncestors: ancestors(of: target).map(Wrapped.init))
        return relation == .covered ? hit : nil
    }

    /// How a covering element is named in messages: its role and label.
    static func describe(_ element: AXUIElement) -> String {
        let role = AX.role(element).replacingOccurrences(of: "AX", with: "").lowercased()
        guard let label = AX.label(element), !label.isEmpty else { return role }
        return "\(role) “\(label.count > 40 ? String(label.prefix(40)) + "…" : label)”"
    }

    private static func ancestors(of element: AXUIElement) -> [AXUIElement] {
        var chain: [AXUIElement] = []
        var current = AX.element(element, "AXParent")
        while let parent = current, chain.count < 60 {
            chain.append(parent)
            if AX.role(parent) == "AXApplication" { break }
            current = AX.element(parent, "AXParent")
        }
        return chain
    }

    private struct Wrapped: Equatable {
        let element: AXUIElement
        init(_ element: AXUIElement) { self.element = element }
        static func == (lhs: Wrapped, rhs: Wrapped) -> Bool { CFEqual(lhs.element, rhs.element) }
    }
}

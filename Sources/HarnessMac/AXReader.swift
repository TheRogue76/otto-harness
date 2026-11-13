import ApplicationServices
import Foundation
import HarnessCore

/// Hashable identity for AX elements: two AXUIElements for the same UI object compare equal.
public struct ElementKey: Hashable, @unchecked Sendable {
    public let element: AXUIElement

    public init(_ element: AXUIElement) {
        self.element = element
    }

    public static func == (lhs: ElementKey, rhs: ElementKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }
}

/// Reads AX subtrees within node, depth and time limits.
public struct AXReader {
    /// What a read does with the rows of a table or outline that are scrolled out of view.
    public enum RowsOutOfView: Sendable {
        /// Reads them in their place, like any other element.
        case read
        /// Reads them after everything else, while the limits allow, so a long table doesn't
        /// leave the rest of the window unread.
        case last
        /// Leaves them out and counts them in `rowsOutOfView`.
        case skip
    }

    public var maxNodes: Int
    public var maxDepth: Int
    public var deadline: Date
    /// Longest value kept, in characters; longer ones are cut and end in "…".
    public var valueLimit: Int
    public var rowsOutOfView: RowsOutOfView

    public init(maxNodes: Int = 4000, maxDepth: Int = 60, timeBudget: TimeInterval = 3, valueLimit: Int = 300, rowsOutOfView: RowsOutOfView = .last) {
        self.maxNodes = maxNodes
        self.maxDepth = maxDepth
        self.deadline = Date().addingTimeInterval(timeBudget)
        self.valueLimit = valueLimit
        self.rowsOutOfView = rowsOutOfView
    }

    private static let attributeNames = [
        "AXRole", "AXSubrole", "AXTitle", "AXDescription", "AXPlaceholderValue", "AXValue",
        "AXIdentifier", "AXEnabled", "AXFocused", "AXSelected", "AXPosition", "AXSize", "AXChildren", "AXURL", "AXIndex",
    ]
    private static let windowButtonAttributes = ["AXCloseButton", "AXMinimizeButton", "AXZoomButton", "AXFullScreenButton"]
    /// Fewest rows a table needs before its rows out of view are read last or left out.
    static let longTable = 40

    /// A table's rows out of view, put off until the rest of the tree is read.
    private struct LaterRows {
        var path: [Int]
        var depth: Int
        var before: [AXUIElement]
        var beforeAt: Int
        var after: [AXUIElement]
        var afterAt: Int
    }

    /// Nodes read so far in one read, and the rows put off for later.
    private final class Budget {
        var nodes = 0
        var later: [LaterRows] = []
    }

    public func read(_ element: AXUIElement) -> RawNode {
        let budget = Budget()
        var root = read(element, depth: 0, path: [], budget: budget)
        for rows in budget.later {
            root.update(at: rows.path) { table in
                let after = readRows(rows.after, depth: rows.depth, budget: budget)
                let before = readRows(rows.before, depth: rows.depth, budget: budget)
                table.children.insert(contentsOf: after, at: min(rows.afterAt, table.children.count))
                table.children.insert(contentsOf: before, at: min(rows.beforeAt, table.children.count))
                table.unread += rows.before.count + rows.after.count - before.count - after.count
            }
        }
        return root
    }

    private func readRows(_ rows: [AXUIElement], depth: Int, budget: Budget) -> [RawNode] {
        var reader = self
        reader.rowsOutOfView = .read
        var read: [RawNode] = []
        for row in rows {
            guard budget.nodes < maxNodes, Date() <= deadline else { break }
            read.append(reader.read(row, depth: depth, path: [], budget: budget))
        }
        return read
    }

    /// The rows of a long table or outline that are out of view; empty for anything else.
    private func rowsOutOfView(of element: AXUIElement, role: String, children: [AXUIElement]) -> Set<ElementKey> {
        guard rowsOutOfView != .read, role == "AXTable" || role == "AXOutline", children.count >= Self.longTable else { return [] }
        let rows = AX.elements(element, "AXRows")
        guard rows.count >= Self.longTable else { return [] }
        let visible = Set(AX.elements(element, "AXVisibleRows").map(ElementKey.init))
        return Set(rows.map(ElementKey.init)).subtracting(visible)
    }

    private func read(_ element: AXUIElement, depth: Int, path: [Int], budget: Budget) -> RawNode {
        budget.nodes += 1
        var values: CFArray?
        AXUIElementCopyMultipleAttributeValues(element, Self.attributeNames as CFArray, AXCopyMultipleAttributeOptions(), &values)
        let list = (values as? [AnyObject]) ?? []
        func at(_ index: Int) -> AnyObject? {
            guard index < list.count else { return nil }
            let value = list[index]
            if CFGetTypeID(value) == AXValueGetTypeID(), AXValueGetType(value as! AXValue) == .axError {
                return nil
            }
            return value
        }

        var node = RawNode(
            key: AnyHashable(ElementKey(element)),
            role: Self.text(at(0)) ?? "AXUnknown",
            subrole: Self.text(at(1)),
            title: Self.text(at(2)),
            details: Self.text(at(3)),
            placeholder: Self.text(at(4)),
            value: Self.valueText(at(5), limit: valueLimit),
            identifier: Self.text(at(6)),
            url: Self.urlText(at(13)),
            enabled: at(7) as? Bool,
            focused: at(8) as? Bool,
            selected: at(9) as? Bool,
            actions: AX.actions(element),
            frame: Self.frame(position: at(10), size: at(11))
        )
        if node.role == "AXRow" { node.index = (at(14) as? NSNumber)?.intValue }

        let children = (at(12) as? [AXUIElement]) ?? []
        guard depth < maxDepth else {
            node.unread = children.count
            return node
        }
        let outOfView = rowsOutOfView(of: element, role: node.role, children: children)
        var later = LaterRows(path: path, depth: depth + 1, before: [], beforeAt: 0, after: [], afterAt: 0)
        var seenVisibleRow = false
        for (index, child) in children.enumerated() {
            if !outOfView.isEmpty {
                if outOfView.contains(ElementKey(child)) {
                    if seenVisibleRow {
                        if later.after.isEmpty { later.afterAt = node.children.count }
                        later.after.append(child)
                    } else {
                        later.before.append(child)
                    }
                    continue
                }
                if !seenVisibleRow, AX.role(child) == "AXRow" {
                    seenVisibleRow = true
                    later.beforeAt = node.children.count
                }
            }
            if budget.nodes >= maxNodes || Date() > deadline {
                let rest = children[index...].filter { !outOfView.contains(ElementKey($0)) }
                let buttons = node.role == "AXWindow" ? Self.windowButtons(of: element, among: rest) : []
                node.children += buttons.map { read($0, depth: depth + 1, path: path + [node.children.count], budget: budget) }
                node.unread = rest.count - buttons.count
                break
            }
            node.children.append(read(child, depth: depth + 1, path: path + [node.children.count], budget: budget))
        }
        if !outOfView.isEmpty {
            if !seenVisibleRow { later.beforeAt = node.children.count }
            if later.after.isEmpty { later.afterAt = node.children.count }
            switch rowsOutOfView {
            case .skip: node.rowsOutOfView = outOfView.count
            case .last: budget.later.append(later)
            case .read: break
            }
        }
        return node
    }

    /// The window's close, minimize, zoom and full screen buttons among `children`, in their order.
    static func windowButtons(of window: AXUIElement, among children: [AXUIElement]) -> [AXUIElement] {
        var values: CFArray?
        AXUIElementCopyMultipleAttributeValues(window, windowButtonAttributes as CFArray, AXCopyMultipleAttributeOptions(), &values)
        let buttons = ((values as? [AnyObject]) ?? []).filter { CFGetTypeID($0) == AXUIElementGetTypeID() }
        return children.filter { child in buttons.contains { CFEqual($0, child) } }
    }

    static func text(_ value: AnyObject?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// An `AXURL` as text: an absolute URL, or nil when there's none.
    static func urlText(_ value: AnyObject?) -> String? {
        switch value {
        case let url as URL: url.absoluteString
        case let string as String: string.isEmpty ? nil : string
        default: nil
        }
    }

    /// An AXValue as display text, capped at `limit` characters.
    static func valueText(_ value: AnyObject?, limit: Int = 300) -> String? {
        let text: String?
        switch value {
        case let string as String: text = string
        case let attributed as NSAttributedString: text = attributed.string
        case let number as NSNumber:
            guard number.doubleValue.isFinite else { return nil }
            text = number.stringValue
        case let url as URL: text = url.absoluteString
        default: text = nil
        }
        guard let text, !text.isEmpty else { return nil }
        return text.count > limit ? String(text.prefix(limit)) + "…" : text
    }

    static func frame(position: AnyObject?, size: AnyObject?) -> CGRect? {
        guard let position, let size,
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        let rect = CGRect(origin: origin, size: extent)
        return rect.isSane ? rect : nil
    }
}

extension RawNode {
    /// The AX element this node was read from; nil for nodes read some other way, and in tests.
    public var element: AXUIElement? { (key?.base as? ElementKey)?.element }
}

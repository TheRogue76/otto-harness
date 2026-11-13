import ApplicationServices
import Foundation
import HarnessCore

/// Finds the table or outline an element is, or holds, and reads its column headers.
enum TableHeaders {
    /// `element` when it's a table or outline, or the one inside it when it's a scroll area
    /// holding one; nil otherwise.
    static func table(at element: AXUIElement) -> AXUIElement? {
        let role = AX.role(element)
        if TableText.tableRoles.contains(role) { return element }
        guard role == "AXScrollArea" else { return nil }
        return AX.children(element).first { TableText.tableRoles.contains(AX.role($0)) }
    }

    /// The table's column headers in order; empty when it shows none.
    static func columns(of table: AXUIElement) -> [String] {
        let titles = AX.elements(table, "AXColumns").map { column -> String in
            let source = AX.element(column, "AXHeader") ?? column
            return AX.string(source, "AXTitle") ?? AX.string(source, "AXDescription") ?? AX.value(source) ?? ""
        }
        return titles.allSatisfy(\.isEmpty) ? [] : titles
    }

    /// Each column's horizontal span on screen, in order.
    static func spans(of table: AXUIElement) -> [ClosedRange<CGFloat>] {
        AX.elements(table, "AXColumns").compactMap { AX.frame($0).map { $0.minX...$0.maxX } }
    }
}

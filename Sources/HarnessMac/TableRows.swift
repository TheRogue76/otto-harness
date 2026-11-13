import ApplicationServices
import Foundation
import HarnessCore

/// A table's rows read a screenful at a time, while they're on screen, since tables don't always
/// give rows out of view all their cells; paging scrolls the table through its scroll bar, since
/// tables refuse to scroll by page or to a row through accessibility.
final class TableRows {
    let table: AXUIElement
    let columns: Int

    init(table: AXUIElement) {
        self.table = table
        columns = AX.elements(table, "AXColumns").count
    }

    /// The rows on screen, each read again up to twice while it lacks some of its cells' text.
    func next() async -> RawNode {
        var read = AX.elements(table, "AXVisibleRows").map(Self.read)
        for _ in 0..<2 where read.contains(where: { !TableText.isComplete($0, columns: columns) }) {
            try? await Task.sleep(for: .milliseconds(200))
            read = read.map { row in
                guard !TableText.isComplete(row, columns: columns), let element = row.element else { return row }
                return Self.read(element)
            }
        }
        return RawNode(role: "AXGroup", children: read)
    }

    /// Every row, a screenful at a time from the top, until `deadline`; the table is scrolled back
    /// to where it was afterwards.
    func all(until deadline: Date) async -> (rows: [RawNode], total: Int) {
        let total = AX.elements(table, "AXRows").count
        let start = position
        await toTop()
        var rows: [Int: RawNode] = [:]
        while true {
            for row in await next().children {
                guard let index = row.index else { continue }
                rows[index] = row
            }
            guard rows.count < total, Date() < deadline, pageDown() else { break }
            _ = await settle()
        }
        if let start, let bar = verticalBar { AX.set(bar, "AXValue", NSNumber(value: start)) }
        return (rows.sorted { $0.key < $1.key }.map(\.value), total)
    }

    /// Scrolls the table up to its first row.
    func toTop() async {
        guard let bar = verticalBar, firstShown > 0, AX.set(bar, "AXValue", NSNumber(value: 0)) == .success else { return }
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// Scrolls a page down; at the end of the table, or when it can't, brings the last row taken
    /// into view, for tables that load more as they scroll.
    func moveOn(from last: RawNode) async -> Bool {
        if pageDown() { return await settle() }
        if let element = last.element { _ = AX.scrollIntoView(element) }
        return await settle()
    }

    /// Moves the scroll bar down by the rows that show, less one; false at the bottom or without a
    /// bar. Tables give their size as the part on screen, so the step comes from row counts.
    func pageDown() -> Bool {
        guard let bar = verticalBar else { return false }
        let total = AX.elements(table, "AXRows").count
        let shown = AX.elements(table, "AXVisibleRows").count
        guard total > shown, shown > 1 else { return false }
        let position = self.position ?? 0
        let target = min(1, position + Double(shown - 1) / Double(total - shown))
        guard target > position + 0.0001 else { return false }
        return AX.set(bar, "AXValue", NSNumber(value: target)) == .success
    }

    private func settle() async -> Bool {
        try? await Task.sleep(for: .milliseconds(300))
        return true
    }

    /// The scroll area the table sits in.
    var scrollArea: AXUIElement? {
        AX.element(table, "AXParent").flatMap { AX.role($0) == "AXScrollArea" ? $0 : nil }
    }

    var verticalBar: AXUIElement? { scrollArea.flatMap { AX.element($0, "AXVerticalScrollBar") } }

    /// The vertical scroll bar's value, from 0 at the top to 1 at the bottom.
    var position: Double? { verticalBar.flatMap { AX.attribute($0, "AXValue") as? Double } }

    /// Position of the first row on screen.
    var firstShown: Int {
        AX.elements(table, "AXVisibleRows").first.flatMap { AX.attribute($0, "AXIndex") as? Int } ?? 0
    }

    static func read(_ row: AXUIElement) -> RawNode {
        AXReader(maxNodes: 400, maxDepth: 12, timeBudget: 1, valueLimit: ReadService.limit, rowsOutOfView: .read).read(row)
    }
}

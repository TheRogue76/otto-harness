#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import HarnessProtocol

/// Tables and outlines as rows of cells: a row's cells, its text on one line, and a table's
/// columns and rows as `read` returns them.
package enum TableText {
    /// Roles of elements whose children are rows of cells.
    package static let tableRoles: Set<String> = ["AXTable", "AXOutline"]

    /// The text of each of `row`'s cells; the row's whole text as one cell when it has none.
    package static func cells(of row: RawNode) -> [String] {
        let cells = row.children.filter { $0.role == "AXCell" }
        guard !cells.isEmpty else { return [oneLine(ReadText.text(of: row))] }
        return cells.map { oneLine(ReadText.text(of: $0)) }
    }

    /// `row`'s cells on one line, separated by " | ".
    package static func text(of row: RawNode) -> String {
        cells(of: row).joined(separator: " | ").trimmingCharacters(in: .whitespaces)
    }

    /// Whether `row` has a cell with text for each of its table's `columns`, or isn't made of cells;
    /// tables sometimes give a row out of view only some of its cells, or cells without their text.
    package static func isComplete(_ row: RawNode, columns: Int) -> Bool {
        let cells = row.children.filter { $0.role == "AXCell" }
        return cells.isEmpty || (cells.count >= columns && !cells.contains { ReadText.text(of: $0).isEmpty })
    }

    /// Whether `node` is a row of cells, in a table, an outline or a web table.
    package static func isRow(_ node: RawNode) -> Bool {
        node.role == "AXRow" && node.children.contains { $0.role == "AXCell" }
    }

    /// The rows inside `table`, in order, without looking inside a row for more.
    package static func rows(in table: RawNode) -> [RawNode] {
        Collector.items(in: table, matching: ElementSelector(role: "row")).filter { $0.role == "AXRow" }
    }

    /// The first table or outline in `node`, itself included; the one with the most rows when there are several.
    package static func table(in node: RawNode) -> RawNode? {
        var found: [RawNode] = []
        func visit(_ node: RawNode, _ depth: Int) {
            if tableRoles.contains(node.role) {
                found.append(node)
                return
            }
            guard depth < 40 else { return }
            node.children.forEach { visit($0, depth + 1) }
        }
        visit(node, 0)
        return found.max { rows(in: $0).count + $0.rowsOutOfView < rows(in: $1).count + $1.rowsOutOfView }
    }

    /// `rows`' columns and cells, for a table holding `total` rows in all. With the columns'
    /// horizontal spans, a row missing some cells gets each cell it has under its own column and
    /// empty text for the others.
    package static func content(of rows: [RawNode], columns: [String], spans: [ClosedRange<CGFloat>] = [], total: Int?) -> ReadMethod.Table {
        let cells = rows.map { row in placed(row, spans: spans) }
        return ReadMethod.Table(columns: columns, rows: cells, first: rows.compactMap(\.index).min(), total: total ?? rows.count)
    }

    /// `row`'s cells, each under the column whose span holds its middle when the row lacks some.
    package static func placed(_ row: RawNode, spans: [ClosedRange<CGFloat>]) -> [String] {
        let cells = row.children.filter { $0.role == "AXCell" }
        guard !spans.isEmpty, !cells.isEmpty, cells.count < spans.count else { return self.cells(of: row) }
        var placed = Array(repeating: "", count: spans.count)
        for cell in cells {
            guard let middle = cell.frame?.midX, let column = spans.firstIndex(where: { $0.contains(middle) }) else { return self.cells(of: row) }
            placed[column] = oneLine(ReadText.text(of: cell))
        }
        return placed
    }

    /// Rows of tables in `node` left out because they're out of view.
    package static func rowsOutOfView(in node: RawNode) -> Int {
        node.rowsOutOfView + node.children.reduce(0) { $0 + rowsOutOfView(in: $1) }
    }

    /// A notice that tables show only their rows on screen, when `node` left any out; nil otherwise.
    package static func rowsOutOfViewNotice(in node: RawNode) -> Notice? {
        let count = rowsOutOfView(in: node)
        guard count > 0 else { return nil }
        return Notice(
            kind: "rowsOutOfView",
            message: "Tables show only their rows on screen; \(count) more are scrolled out of view. `read` on a table gives its columns and every row, and `collect` with item row returns each row once."
        )
    }

    /// What a read of a table left out: rows out of view, or rows not read in time.
    package static func notices(for table: ReadMethod.Table, visibleOnly: Bool, incomplete: Int = 0) -> [Notice] {
        var notices: [Notice] = []
        if incomplete > 0 {
            notices.append(Notice(
                kind: "incompleteRows",
                message: "\(incomplete) rows came back without some of their cells, left empty here."
            ))
        }
        guard table.rows.count < table.total else { return notices }
        let shown = table.rows.count
        if visibleOnly {
            return notices + [Notice(kind: "rowsOutOfView", message: "These are the \(shown) rows on screen of \(table.total); read again without visible for them all, or `collect` with item row.")]
        }
        return notices + [Notice(kind: "truncated", message: "Read \(shown) of \(table.total) rows before the time ran out; `collect` with item row returns them all.")]
    }

    private static func oneLine(_ text: String) -> String {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

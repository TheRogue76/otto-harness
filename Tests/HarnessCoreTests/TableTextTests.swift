#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
@testable import HarnessCore
import HarnessProtocol
import Testing

@Suite struct TableTextTests {
    private func cell(_ text: String, x: CGFloat) -> RawNode {
        RawNode(role: "AXCell", frame: CGRect(x: x, y: 0, width: 90, height: 20), children: text.isEmpty ? [] : [RawNode(role: "AXStaticText", value: text)])
    }

    private func row(_ index: Int, _ cells: [(String, CGFloat)]) -> RawNode {
        RawNode(role: "AXRow", children: cells.map { cell($0.0, x: $0.1) }, index: index)
    }

    @Test func aRowsCellsComeOnOneLine() {
        let keyword = row(0, [("Keyword 1", 0), ("37", 100), ("3", 200)])
        #expect(TableText.cells(of: keyword) == ["Keyword 1", "37", "3"])
        #expect(TableText.text(of: keyword) == "Keyword 1 | 37 | 3")
        let listRow = RawNode(role: "AXRow", children: [RawNode(role: "AXStaticText", value: "Keyword 1"), RawNode(role: "AXStaticText", value: "37")])
        #expect(TableText.cells(of: listRow) == ["Keyword 1 37"])
        #expect(!TableText.isRow(listRow))
        #expect(TableText.isRow(keyword))
    }

    @Test func aRowLackingCellsOrTheirTextIsIncomplete() {
        #expect(TableText.isComplete(row(0, [("a", 0), ("b", 100), ("c", 200)]), columns: 3))
        #expect(!TableText.isComplete(row(0, [("a", 0), ("c", 200)]), columns: 3))
        #expect(!TableText.isComplete(row(0, [("a", 0), ("", 100), ("c", 200)]), columns: 3))
        #expect(TableText.isComplete(RawNode(role: "AXRow", children: [RawNode(role: "AXStaticText", value: "a")]), columns: 1))
    }

    @Test func cellsOfAnIncompleteRowStayUnderTheirColumns() {
        let spans: [ClosedRange<CGFloat>] = [0...99, 100...199, 200...299]
        #expect(TableText.placed(row(30, [("Keyword 31", 0), ("93", 200)]), spans: spans) == ["Keyword 31", "", "93"])
        #expect(TableText.placed(row(31, [("Keyword 32", 0), ("84", 100), ("96", 200)]), spans: spans) == ["Keyword 32", "84", "96"])
        let content = TableText.content(of: [row(30, [("Keyword 31", 0), ("93", 200)])], columns: ["Keyword", "Popularity", "Rank"], spans: spans, total: 200)
        #expect(content == ReadMethod.Table(columns: ["Keyword", "Popularity", "Rank"], rows: [["Keyword 31", "", "93"]], first: 30, total: 200))
    }

    @Test func theTableWithTheMostRowsIsChosen() {
        var small = RawNode(role: "AXTable", identifier: "small", children: [row(0, [("a", 0)])])
        small.rowsOutOfView = 2
        let big = RawNode(role: "AXOutline", identifier: "big", children: (0..<5).map { row($0, [("b", 0)]) })
        let window = RawNode(role: "AXWindow", children: [RawNode(role: "AXScrollArea", children: [small]), RawNode(role: "AXScrollArea", children: [big])])
        #expect(TableText.table(in: window)?.identifier == "big")
        #expect(TableText.rows(in: big).count == 5)
        #expect(TableText.rowsOutOfView(in: window) == 2)
        #expect(TableText.rowsOutOfViewNotice(in: window)?.kind == "rowsOutOfView")
        #expect(TableText.rowsOutOfViewNotice(in: big) == nil)
    }

    @Test func noticesSayWhatAReadLeftOut() {
        let partial = ReadMethod.Table(columns: [], rows: [["a"]], first: 0, total: 3)
        #expect(TableText.notices(for: partial, visibleOnly: true).map(\.kind) == ["rowsOutOfView"])
        #expect(TableText.notices(for: partial, visibleOnly: false, incomplete: 1).map(\.kind) == ["incompleteRows", "truncated"])
        #expect(TableText.notices(for: ReadMethod.Table(columns: [], rows: [["a"]], first: 0, total: 1), visibleOnly: false).isEmpty)
    }

    @Test func rowsAreToldApartByTheirPosition() {
        let collector = Collector(selector: ElementSelector(role: "row"), key: nil, max: 10, until: nil, deadline: .distantFuture, seen: [])
        let first = Collector.describe(row(4, [("Keyword 5", 0), ("", 100)]))
        let again = Collector.describe(row(4, [("Keyword 5", 0), ("85", 100)]))
        #expect(again.text == "Keyword 5 | 85")
        #expect(collector.identity(of: first) == collector.identity(of: again))
        #expect(collector.identity(of: Collector.describe(RawNode(role: "AXGroup", children: [RawNode(role: "AXStaticText", value: "x")]))) == "text x")
    }

    @Test func aNodeDeepInsideCanBeChanged() {
        var tree = RawNode(role: "AXWindow", children: [RawNode(role: "AXGroup", children: [RawNode(role: "AXTable")])])
        tree.update(at: [0, 0]) { $0.children.append(RawNode(role: "AXRow")) }
        tree.update(at: [3]) { $0.role = "AXNothing" }
        #expect(tree.children[0].children[0].children.map(\.role) == ["AXRow"])
        #expect(tree.role == "AXWindow")
    }
}

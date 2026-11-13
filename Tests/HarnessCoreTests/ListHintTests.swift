import HarnessCore
import Testing

@Suite struct ListHintTests {
    @Test func aTableInAScrollingAreaPointsToCollect() {
        let table = RawNode(role: "AXScrollArea", children: [RawNode(role: "AXTable", children: [RawNode(role: "AXRow")]), RawNode(role: "AXScrollBar")])
        let window = RawNode(role: "AXWindow", children: [RawNode(role: "AXGroup", children: [table])])
        #expect(ListHint.notice(for: window)?.kind == "partialList")
    }

    @Test func aListThatDoesntScrollOrAPageGetsNoHint() {
        let still = RawNode(role: "AXScrollArea", children: [RawNode(role: "AXTable")])
        let page = RawNode(role: "AXScrollArea", children: [RawNode(role: "AXWebArea"), RawNode(role: "AXScrollBar")])
        #expect(ListHint.notice(for: still) == nil)
        #expect(ListHint.notice(for: page) == nil)
    }
}

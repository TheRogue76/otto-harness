@testable import HarnessMac
import Testing

@Suite struct ClickTargetTests {
    @Test func aClickLandsOnTheTargetItsInsidesAndItsContainers() {
        #expect(ClickTarget.relation(hit: "button", hitAncestors: ["row", "table", "window"], target: "button", targetAncestors: ["row", "table", "window"]) == .lands)
        #expect(ClickTarget.relation(hit: "label", hitAncestors: ["button", "row", "window"], target: "button", targetAncestors: ["row", "window"]) == .lands)
        #expect(ClickTarget.relation(hit: "row", hitAncestors: ["table", "window"], target: "cell", targetAncestors: ["row", "table", "window"]) == .lands)
    }

    @Test func somethingElseOverTheTargetCoversIt() {
        #expect(ClickTarget.relation(hit: "submit", hitAncestors: ["dialog", "web area", "window"], target: "link", targetAncestors: ["list", "web area", "window"]) == .covered)
    }
}

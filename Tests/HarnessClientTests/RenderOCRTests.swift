import HarnessClient
import HarnessProtocol
import Testing

@Suite struct RenderOCRTests {
    @Test func ocrLinesAreShownWhole() {
        let long = String(repeating: "Configured in the App Store Connect sales report ", count: 4)
        let ocr = UINode(ref: "o1", role: "AXStaticText", subrole: "AXOCRText", label: long, hit: Point(x: 10, y: 20))
        #expect(Render.node(ocr).contains(long.replacingOccurrences(of: "\n", with: " ")))
        let element = UINode(ref: "k1", role: "AXStaticText", label: long)
        #expect(Render.node(element).contains("…"))
    }
}

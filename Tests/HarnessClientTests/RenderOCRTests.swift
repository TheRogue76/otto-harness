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

@Suite struct RenderTableTests {
    private let window = WindowInfo(
        id: 7, app: AppRef(name: "Astro", bundleIdentifier: "com.example.astro", pid: 5), title: "Keywords",
        frame: Rect(x: 0, y: 0, width: 800, height: 600), onScreen: true, minimized: false, focused: true, main: true, subrole: nil, hasSheet: false
    )

    @Test func aTableReadShowsColumnsAndRows() {
        let table = ReadMethod.Table(columns: ["Keyword", "Rank"], rows: [["Keyword 1", "3"], ["Keyword 2", "6"]], first: 0, total: 200)
        let result = ReadMethod.Result(
            app: window.app, window: window, element: UINode(ref: "k5", role: "AXTable"), text: "Keyword 1 | 3\nKeyword 2 | 6", links: [], table: table, notices: []
        )
        let lines = Render.read(result).split(separator: "\n").map(String.init)
        #expect(lines.suffix(4) == ["Columns: Keyword | Rank", "Rows 1–2 of 200:", "Keyword 1 | 3", "Keyword 2 | 6"])
        #expect(!lines.contains("Text:"))
    }

    @Test func collectedRowsComeOnOneLineUnderTheColumns() {
        let result = CollectMethod.Result(
            app: window.app, window: window, items: [CollectMethod.Item(ref: "k9", text: "Keyword 1 | 3", links: [])], stopped: "end",
            columns: ["Keyword", "Rank"], notices: []
        )
        let lines = Render.collect(result).split(separator: "\n").map(String.init)
        #expect(lines.suffix(2) == ["Columns: Keyword | Rank", "1. k9  Keyword 1 | 3"])
    }
}

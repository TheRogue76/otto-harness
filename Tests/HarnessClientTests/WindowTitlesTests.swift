import HarnessClient
import HarnessProtocol
import Testing

@Suite struct WindowTitlesTests {
    private func window(_ id: UInt32, _ title: String) -> WindowInfo {
        WindowInfo(
            id: id, app: AppRef(name: "Google Chrome", bundleIdentifier: nil, pid: 1), title: title,
            frame: Rect(x: 0, y: 0, width: 100, height: 100), onScreen: true, minimized: false, focused: false, main: false,
            subrole: nil, hasSheet: false
        )
    }

    @Test func aTitleNamesTheOneWindowWithIt() throws {
        let windows = [window(10, "Inbox (3) - Gmail - Google Chrome"), window(20, "App Store Connect - Google Chrome")]
        #expect(try WindowTitles.id(of: "app store connect", in: windows, app: "Chrome") == 20)
        #expect(try WindowTitles.id(of: "Inbox", in: windows, app: "Chrome") == 10)
    }

    @Test func anExactTitleWinsOverOthersContainingIt() throws {
        let windows = [window(1, "Notes"), window(2, "Notes — Shared")]
        #expect(try WindowTitles.id(of: "notes", in: windows, app: "Notes") == 1)
    }

    @Test func noneOrSeveralMatchesSayWhichWindowsThereAre() {
        let windows = [window(1, "Draft one"), window(2, "Draft two")]
        #expect(throws: RPCError.self) { try WindowTitles.id(of: "Draft", in: windows, app: "TextEdit") }
        #expect(throws: RPCError.self) { try WindowTitles.id(of: "Report", in: windows, app: "TextEdit") }
    }
}

import Foundation
import HarnessCore
import HarnessProtocol

/// A browser window's tabs and the address of the page showing.
public enum TabsService {
    public static func tabs(_ params: TabsMethod.Params) async throws -> TabsMethod.Result {
        let (app, window) = try await TargetResolver.resolve(params.target)
        _ = try await Snapshotter.prepare(window, app: app)
        var raw = AXReader(maxNodes: 4000, maxDepth: 60, timeBudget: 3).read(window.content)
        var found = ElementSearch.tabs(in: raw)
        for _ in 0..<4 {
            try? await Task.sleep(for: .milliseconds(250))
            let again = AXReader(maxNodes: 4000, maxDepth: 60, timeBudget: 3).read(window.content)
            let settled = ElementSearch.tabs(in: again)
            let same = settled.map(\.label) == found.map(\.label) && settled.map(ElementSearch.isSelected(tab:)) == found.map(ElementSearch.isSelected(tab:))
            raw = again
            found = settled
            if same { break }
        }
        guard !found.isEmpty else {
            throw RPCError(
                code: RPCErrorCode.notFound,
                message: "\(app.name)'s window \(window.info.id) “\(window.info.title)” shows no tabs to accessibility; `find --role tab` searches it too."
            )
        }
        let shaper = TreeShaper(space: window.space, maxNodes: 1, maxDepth: 0, ref: Snapshotter.registrar(for: app))
        let tabs = found.map { tab in
            var node = shaper.makeNode(tab, visible: tab.frame?.visiblePart(in: window.space.frame))
            node.selected = ElementSearch.isSelected(tab: tab)
            node.children = []
            return node
        }
        return TabsMethod.Result(window: window.info, tabs: tabs, url: ElementSearch.page(in: raw)?.url)
    }

    /// Where a browser shows what it just opened: its focused window and the tab showing in it,
    /// waiting briefly for the page to come up; nil when it has no window.
    public static func opened(by app: AppRef) async -> Notice? {
        try? await Task.sleep(for: .milliseconds(600))
        guard let result = try? await tabs(.init(target: Target(app: "\(app.pid)"))) else {
            guard let window = try? WindowService.resolve(Target(app: "\(app.pid)"), app: app) else { return nil }
            return Notice(kind: "opened", message: "Opened in window \(window.info.id) “\(window.info.title)”.")
        }
        let tab = result.tabs.first { $0.selected == true }
        let place = tab.map { ", tab \($0.ref) “\($0.label ?? "")”" } ?? ""
        return Notice(kind: "opened", message: "Opened in window \(result.window.id) “\(result.window.title)”\(place).")
    }
}

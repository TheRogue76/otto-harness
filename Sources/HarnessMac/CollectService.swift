import ApplicationServices
import CoreGraphics
import Foundation
import HarnessCore
import HarnessProtocol

extension CollectService {
    public static func collect(_ params: CollectMethod.Params, context: ActionContext = .unattended) async throws -> CollectMethod.Result {
        try check(params)
        if params.target.androidDevice != nil { return try await AndroidService.collect(params, context: context) }
        let (app, window) = try await TargetResolver.resolve(TargetResolver.target(params.target, holding: params.within))
        try OwnUI.refuse(app)
        try await context.claim(window, app: app)
        let treeNotice = try await Snapshotter.prepare(window, app: app)
        let container = try params.within.map { try Snapshotter.element(for: $0, app: app) } ?? window.content
        AX.setTimeout(container, seconds: window.isSimulator ? 8 : 2)
        let memory = CollectMemory.key(owner: context.owner, place: "\(app.pid)|\(window.info.id)", params: params)
        var collector = try await collector(params, memory: memory)
        collector.patience = window.isSimulator ? 6 : 2
        if !window.isSimulator, params.item.role?.lowercased() == "row", let table = table(in: container) {
            let rows = TableRows(table: table)
            collector.idleLimit = 2
            if params.continue != true { await rows.toTop() }
            let outcome = try await collector.run(read: { await rows.next() }, scroll: { await rows.moveOn(from: $0) }, aborted: context.shouldAbort)
            await CollectMemory.shared.remember(memory, seen: collector.seen)
            let shaper = TreeShaper(space: window.space, maxNodes: 1, maxDepth: 0, ref: Snapshotter.registrar(for: app))
            var result = result(outcome, app: app, window: window.info, ref: shaper.ref, notices: await Notices.collect(for: window.info) + [treeNotice].compactMap { $0 })
            result.columns = TableHeaders.columns(of: table)
            return result
        }
        let outcome = try await collector.run(
            read: { AXReader(maxNodes: 8000, maxDepth: 80, timeBudget: 4, valueLimit: 20_000).read(container) },
            scroll: { last in
                window.isSimulator
                    ? await scrollSimulator(from: last, window: window)
                    : await scrollMac(from: last, container: container, window: window, app: app)
            },
            aborted: context.shouldAbort
        )
        await CollectMemory.shared.remember(memory, seen: collector.seen)
        let shaper = TreeShaper(space: window.space, maxNodes: 1, maxDepth: 0, ref: Snapshotter.registrar(for: app))
        var notices = await Notices.collect(for: window.info) + [treeNotice].compactMap { $0 }
        if !window.isSimulator, ["cell", "text"].contains(params.item.role?.lowercased() ?? ""), table(in: container) != nil {
            notices.append(Notice(
                kind: "tableItems",
                message: "These items are inside a table; `collect` with item row returns each row whole, its cells in order, and scrolls the table itself."
            ))
        }
        return result(outcome, app: app, window: window.info, ref: shaper.ref, notices: notices)
    }

    /// Scrolls a Mac window's list on from its last item: brings the item into view through
    /// accessibility, or, when that moves nothing, a background wheel scroll of most of the list's
    /// height. False when neither could move it.
    static func scrollMac(from last: RawNode, container: AXUIElement, window: WindowService.Window, app: AppRef) async -> Bool {
        if let element = last.element, let before = AX.frame(element), AX.scrollIntoView(element) == .success {
            try? await Task.sleep(for: .milliseconds(500))
            guard let after = AX.frame(element) else { return true }
            if abs(after.minY - before.minY) > 1 { return true }
        }
        guard let area = AX.frame(container)?.intersection(window.space.frame), !area.isNull, area.height > 40 else { return false }
        let center = CGPoint(x: area.midX, y: area.midY)
        guard BackgroundInput.routes(at: center, in: window) else { return false }
        let origin = CGPoint(x: window.space.frame.minX, y: window.space.frame.minY)
        guard await BackgroundClick.scroll(pid: app.pid, window: window.info.id, at: center, windowOrigin: origin, dx: 0, dy: -area.height * 0.8) else {
            return false
        }
        try? await Task.sleep(for: .milliseconds(500))
        return true
    }

    /// The table or outline `container` is or holds, the one with the most rows when there are several.
    static func table(in container: AXUIElement) -> AXUIElement? {
        if let table = TableHeaders.table(at: container) { return table }
        let outline = AXReader(maxNodes: 3000, maxDepth: 40, timeBudget: 2, rowsOutOfView: .skip).read(container)
        return TableText.table(in: outline)?.element
    }

    /// Pages a simulator's list down from its last item.
    static func scrollSimulator(from last: RawNode, window: WindowService.Window) async -> Bool {
        let moved = await SimulatorInput.scrollPages(from: last.element, direction: .down, pages: 1, window: window)
        try? await Task.sleep(for: .milliseconds(600))
        return moved > 0
    }
}

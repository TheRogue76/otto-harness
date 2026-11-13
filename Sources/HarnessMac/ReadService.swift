import ApplicationServices
import CoreGraphics
import Foundation
import HarnessCore
import HarnessProtocol

extension ReadService {
    public static func read(_ params: ReadMethod.Params) async throws -> ReadMethod.Result {
        if params.target.androidDevice != nil { return try await AndroidService.read(params) }
        if params.element?.ocr == true {
            throw RPCError(code: RPCErrorCode.invalidParams, message: "Text found by OCR has no element to read; `find --ocr` lists every line it reads.")
        }
        let (app, window) = try await TargetResolver.resolve(TargetResolver.target(params.target, holding: params.element?.ref))
        let treeNotice = try await Snapshotter.prepare(window, app: app)
        var element = window.content
        var visible: CGRect?
        if let selector = params.element, !selector.isEmpty {
            let resolved = if window.isSimulator, selector.ref == nil {
                try await SimulatorScrolling.reveal(selector, window: window, app: app, deadline: Date().addingTimeInterval(SimulatorScrolling.budget))
            } else {
                try await ElementResolver.resolve(selector, window: window, app: app, allowFocused: false)
            }
            element = resolved.element
            visible = resolved.visible
        }
        if params.page == true {
            guard params.element?.isEmpty ?? true else {
                throw RPCError(code: RPCErrorCode.invalidParams, message: "Read a page or an element, not both; an element's ref already says where to read.")
            }
            let outline = AXReader(maxNodes: 8000, maxDepth: 80, timeBudget: 2).read(window.content)
            guard let page = ElementSearch.page(in: outline), let pageElement = page.element else {
                throw RPCError(code: RPCErrorCode.notFound, message: "\(app.name)'s window \(window.info.id) “\(window.info.title)” has no web page to read; read the window instead.")
            }
            element = pageElement
        }
        AX.setTimeout(element, seconds: window.isSimulator ? 8 : 2)
        let tableElement = TableHeaders.table(at: element)
        let rows: AXReader.RowsOutOfView = params.visible == true || tableElement != nil ? .skip : .last
        let raw = AXReader(maxNodes: 8000, maxDepth: 80, timeBudget: 5, valueLimit: limit, rowsOutOfView: rows).read(element)
        var shaper = TreeShaper(space: window.space, maxNodes: 1, maxDepth: 0, ref: Snapshotter.registrar(for: app))
        shaper.links = true
        var notices = await Notices.collect(for: window.info) + [treeNotice].compactMap { $0 }
        var table: ReadMethod.Table?
        if let tableElement {
            let pager = TableRows(table: tableElement)
            let read = params.visible == true
                ? (rows: await pager.next().children, total: AX.elements(tableElement, "AXRows").count)
                : await pager.all(until: Date().addingTimeInterval(20))
            let spans = TableHeaders.spans(of: tableElement)
            let content = TableText.content(of: read.rows, columns: TableHeaders.columns(of: tableElement), spans: spans, total: read.total)
            table = content
            let incomplete = read.rows.filter { !TableText.isComplete($0, columns: pager.columns) }.count
            notices += TableText.notices(for: content, visibleOnly: params.visible == true, incomplete: incomplete)
        } else {
            notices += [ListHint.notice(for: raw), params.visible == true ? TableText.rowsOutOfViewNotice(in: raw) : nil].compactMap { $0 }
        }
        var outcome = result(raw, node: shaper.makeNode(raw, visible: visible), app: app, window: window.info, ref: shaper.ref, notices: notices)
        if let table {
            outcome.table = table
            outcome.text = table.rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")
        }
        return outcome
    }

}

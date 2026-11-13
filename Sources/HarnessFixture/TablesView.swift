import AppKit
import SwiftUI

/// One row of the fixture's tables: a keyword with its numbers.
struct KeywordRow: Identifiable, Hashable {
    let id: Int
    var keyword: String { "Keyword \(id)" }
    var popularity: Int { (id * 37) % 100 }
    var rank: Int { id * 3 }

    static let all = (1...200).map(KeywordRow.init)
}

/// Tables of 200 rows, shown with `--tables`: an AppKit table, a SwiftUI table and a SwiftUI
/// list, for the harness's tests of reading and collecting rows.
struct TablesView: View {
    static var isAsked: Bool { CommandLine.arguments.contains("--tables") }

    /// The one kind of table to show when `--tables` is followed by appkit, table or list; all three otherwise.
    static var only: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "--tables"), index + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[index + 1]
    }

    private func shows(_ kind: String) -> Bool { Self.only.map { $0 == kind || $0.hasPrefix("-") } ?? true }

    var body: some View {
        HStack(spacing: 12) {
            if shows("appkit") {
                titled("AppKit table") {
                    AppKitTable().accessibilityIdentifier("appkit-table")
                }
            }
            if shows("table") {
                titled("SwiftUI table") {
                    Table(KeywordRow.all) {
                        TableColumn("Keyword", value: \.keyword)
                        TableColumn("Popularity") { Text("\($0.popularity)") }
                        TableColumn("Rank") { Text("\($0.rank)") }
                    }
                    .accessibilityIdentifier("swiftui-table")
                }
            }
            if shows("list") {
                titled("SwiftUI list") {
                    List(KeywordRow.all) { row in
                        HStack {
                            Text(row.keyword)
                            Spacer()
                            Text("\(row.popularity)")
                        }
                    }
                    .accessibilityIdentifier("swiftui-list")
                }
            }
        }
        .padding(12)
        .frame(width: 980, height: 420)
    }

    private func titled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            content()
        }
    }
}

/// An NSTableView with a keyword, popularity and rank column, made of view-based cells.
struct AppKitTable: NSViewRepresentable {
    func makeCoordinator() -> Source { Source() }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        for (id, title) in [("keyword", "Keyword"), ("popularity", "Popularity"), ("rank", "Rank")] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = title
            column.width = id == "keyword" ? 120 : 80
            table.addTableColumn(column)
        }
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        return scroll
    }

    func updateNSView(_ view: NSScrollView, context: Context) {}

    /// The AppKit table's rows and cells.
    final class Source: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        func numberOfRows(in tableView: NSTableView) -> Int { KeywordRow.all.count }

        func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
            let item = KeywordRow.all[row]
            let text: String
            switch column?.identifier.rawValue {
            case "keyword": text = item.keyword
            case "popularity": text = "\(item.popularity)"
            default: text = "\(item.rank)"
            }
            let field = NSTextField(labelWithString: text)
            return field
        }
    }
}

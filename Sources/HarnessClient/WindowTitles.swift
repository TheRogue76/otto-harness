import Foundation
import HarnessProtocol

/// A window named by its title where a window ID goes (`-w "Inbox"`, or MCP `window: "Inbox"`), since
/// IDs don't survive an app's restart and saved instructions name windows by what they show.
public enum WindowTitles {
    /// The window of `windows` that `title` means: the one whose title is exactly that, else the one
    /// whose title contains it, ignoring case; an error naming the candidates when none or several do.
    public static func id(of title: String, in windows: [WindowInfo], app: String) throws -> UInt32 {
        let exact = windows.filter { $0.title.caseInsensitiveCompare(title) == .orderedSame }
        if exact.count == 1 { return exact[0].id }
        let containing = exact.isEmpty ? windows.filter { $0.title.range(of: title, options: .caseInsensitive) != nil } : exact
        if containing.count == 1 { return containing[0].id }
        if containing.isEmpty {
            let titles = windows.map { "\($0.id) “\($0.title)”" }.joined(separator: ", ")
            throw RPCError(code: RPCErrorCode.notFound, message: "No window of \(app) has “\(title)” in its title. Its windows: \(titles.isEmpty ? "none" : titles)")
        }
        let titles = containing.map { "\($0.id) “\($0.title)”" }.joined(separator: ", ")
        throw RPCError(code: RPCErrorCode.ambiguous, message: "Several windows of \(app) have “\(title)” in their titles: \(titles). Give more of the title, or a window ID.")
    }

    /// The window ID a `-w` or `window` value means: a number as it is, otherwise the window with
    /// that title, looked up with `windows`.
    public static func resolve(_ value: String, app: String, connection: HarnessConnection) throws -> UInt32 {
        if let id = UInt32(value) { return id }
        let listed = try connection.call(WindowsMethod.self, .init(app: app))
        return try id(of: value, in: listed.windows, app: app)
    }
}

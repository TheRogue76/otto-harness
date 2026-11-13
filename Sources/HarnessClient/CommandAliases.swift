import Foundation
import HarnessProtocol

/// What the command line does with its arguments before parsing them: runs `act` the way the MCP
/// tool of that name is used, and explains commands it doesn't have instead of a parser error.
public enum CommandAliases {
    /// The actions the MCP `act` tool takes, each a command of its own on the command line.
    public static let actActions = ["press", "set-value", "focus", "select", "scroll-to", "increment", "decrement", "type", "key"]

    /// What to do with the arguments.
    public enum Outcome: Equatable {
        /// Parse and run these arguments.
        case run([String])
        /// Print this message and exit without running anything.
        case explain(String)
    }

    /// Rewrites `act <action> …` and `act <ref> <action> …` to the action's own command, and explains
    /// `act` alone and commands that don't exist, given the names of the commands there are.
    public static func resolve(_ arguments: [String], commands: [String]) -> Outcome {
        guard let first = arguments.first, !first.hasPrefix("-") else { return .run(arguments) }
        let rest = Array(arguments.dropFirst())
        if first == "act" {
            if let action = rest.first.flatMap(action(named:)) { return .run([action] + rest.dropFirst()) }
            if rest.count > 1, let action = action(named: rest[1]) { return .run([action, rest[0]] + rest.dropFirst(2)) }
            return .explain(actExplanation)
        }
        if first == "help", rest.first == "act" { return .explain(actExplanation) }
        if first == "help" || commands.contains(first) { return .run(arguments) }
        var message = "There's no command “\(first)”."
        if let near = nearest(to: first, in: commands) { message += " Did you mean `\(HarnessProduct.commandName) \(near)`?" }
        return .explain(message + " Run `\(HarnessProduct.commandName) --help` for the list.")
    }

    static var actExplanation: String {
        let list = actActions.dropLast().joined(separator: ", ") + " and " + (actActions.last ?? "")
        return "`act` is the MCP tool's name; on the command line each action is a command of its own: \(list), as in `\(HarnessProduct.commandName) press k12 -a App` (`\(HarnessProduct.commandName) act press k12 -a App` works too)."
    }

    static func action(named name: String) -> String? {
        let normalized = name.replacingOccurrences(of: "_", with: "-").lowercased()
        return actActions.contains(normalized) ? normalized : nil
    }

    /// The command closest to `word`, when it's close enough to be what was meant.
    static func nearest(to word: String, in commands: [String]) -> String? {
        let scored = commands.map { ($0, distance(word.lowercased(), $0)) }.min { $0.1 < $1.1 }
        guard let (command, score) = scored else { return nil }
        return score <= max(1, command.count / 3) || command.hasPrefix(word.lowercased()) ? command : nil
    }

    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        var previous = Array(0...b.count)
        for (i, x) in a.enumerated() {
            var current = [i + 1]
            for (j, y) in b.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (x == y ? 0 : 1)))
            }
            previous = current
        }
        return previous[b.count]
    }
}

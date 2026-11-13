import HarnessClient
import Testing

@Suite struct CommandAliasesTests {
    let commands = ["press", "set-value", "select", "type", "key", "snapshot", "find", "click", "windows"]

    @Test func actRunsTheActionsOwnCommand() {
        #expect(CommandAliases.resolve(["act", "press", "g247", "-a", "Astro"], commands: commands) == .run(["press", "g247", "-a", "Astro"]))
        #expect(CommandAliases.resolve(["act", "g247", "press", "-a", "Astro"], commands: commands) == .run(["press", "g247", "-a", "Astro"]))
        #expect(CommandAliases.resolve(["act", "set_value", "k3", "--value", "Ada"], commands: commands) == .run(["set-value", "k3", "--value", "Ada"]))
    }

    @Test func actAloneOrItsHelpExplainsTheCommands() {
        for arguments in [["act"], ["act", "--app", "Astro"], ["act", "-h"], ["help", "act"]] {
            guard case .explain(let message) = CommandAliases.resolve(arguments, commands: commands) else {
                Issue.record("\(arguments) should be explained")
                continue
            }
            #expect(message.contains("press") && message.contains("select"))
        }
    }

    @Test func unknownCommandsSuggestTheNearestOne() {
        guard case .explain(let message) = CommandAliases.resolve(["snapshto", "-a", "Notes"], commands: commands) else {
            Issue.record("should be explained")
            return
        }
        #expect(message.contains("snapshot"))
        guard case .explain(let unrelated) = CommandAliases.resolve(["zoom"], commands: commands) else {
            Issue.record("should be explained")
            return
        }
        #expect(!unrelated.contains("Did you mean"))
    }

    @Test func knownCommandsOptionsAndHelpRunAsTheyAre() {
        #expect(CommandAliases.resolve(["press", "k1"], commands: commands) == .run(["press", "k1"]))
        #expect(CommandAliases.resolve(["--version"], commands: commands) == .run(["--version"]))
        #expect(CommandAliases.resolve(["help", "press"], commands: commands) == .run(["help", "press"]))
        #expect(CommandAliases.resolve([], commands: commands) == .run([]))
    }
}

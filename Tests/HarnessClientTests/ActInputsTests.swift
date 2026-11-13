@testable import HarnessClient
import HarnessProtocol
import Testing

@Suite struct ActInputsTests {
    @Test func typeWithOnlyTextTypesThatText() {
        let (element, value) = MCPServer.actInputs(action: .type, selector: ElementSelector(text: "Hello"), value: nil)
        #expect(element == nil)
        #expect(value == "Hello")
    }

    @Test func textStaysASelectorWhenThereIsAValueOrAnotherSelector() {
        let field = ElementSelector(text: "Name")
        #expect(MCPServer.actInputs(action: .type, selector: field, value: "Ada") == (field, "Ada"))
        let byRole = ElementSelector(text: "Name", role: "textfield")
        #expect(MCPServer.actInputs(action: .type, selector: byRole, value: nil) == (byRole, nil))
        #expect(MCPServer.actInputs(action: .press, selector: field, value: nil) == (field, nil))
    }
}

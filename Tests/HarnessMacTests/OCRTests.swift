import CoreGraphics
import Testing
@testable import HarnessMac

struct OCRTests {
    @Test func linesReadTopToBottomThenLeftToRight() {
        let lines: [(box: CGRect, text: String)] = [
            (CGRect(x: 0.6, y: 0.80, width: 0.2, height: 0.04), "Sign in"),
            (CGRect(x: 0.1, y: 0.10, width: 0.3, height: 0.04), "Footer"),
            (CGRect(x: 0.1, y: 0.81, width: 0.3, height: 0.04), "Example"),
            (CGRect(x: 0.1, y: 0.50, width: 0.8, height: 0.05), "Access Temporarily Blocked"),
        ]
        #expect(OCRService.inReadingOrder(lines) == ["Example", "Sign in", "Access Temporarily Blocked", "Footer"])
        #expect(OCRService.inReadingOrder([]) == [])
    }

    @Test func aMissingOrEmptyBoxFallsBackToTheLinesBox() {
        let line = CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.05)
        #expect(OCRService.usableBox(nil, line: line) == line)
        #expect(OCRService.usableBox(.zero, line: line) == line)
        let part = CGRect(x: 0.3, y: 0.5, width: 0.2, height: 0.05)
        #expect(OCRService.usableBox(part, line: line) == part)
        #expect(OCRService.windowRect(line, size: CGSize(width: 1000, height: 800)).minX == 100)
    }
}

import Carbon
import Testing
@testable import Trimmy

@MainActor
@Suite
struct KeySenderTests {
    private let sender = KeySender()

    @Test
    func mapsUppercaseLetterWithShift() {
        let info = self.sender.keyInfo(for: "A")
        #expect(info?.code == CGKeyCode(kVK_ANSI_A))
        #expect(info?.flags.contains(.maskShift) == true)
    }

    @Test
    func mapsLowercaseLetterWithoutShift() {
        let info = self.sender.keyInfo(for: "z")
        #expect(info?.code == CGKeyCode(kVK_ANSI_Z))
        #expect(info?.flags.isEmpty == true)
    }

    @Test
    func mapsShiftedSymbol() {
        let info = self.sender.keyInfo(for: "@")
        #expect(info?.code == CGKeyCode(kVK_ANSI_2))
        #expect(info?.flags.contains(.maskShift) == true)
    }

    @Test
    func mapsNewlineToReturn() {
        let info = self.sender.keyInfo(for: "\n")
        #expect(info?.code == CGKeyCode(kVK_Return))
    }

    @Test
    func returnsNilForUnsupportedCharacter() {
        let info = self.sender.keyInfo(for: "é")
        #expect(info == nil)
    }
}

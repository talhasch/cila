import XCTest
@testable import Cila

final class PromptTests: XCTestCase {
    func testOriginalToneKeepsToneAndHasNoTranslation() {
        let prompt = Prompt.system(for: ImproveOptions(targetLanguage: nil, tone: .original))
        XCTAssertTrue(prompt.contains("Preserve its meaning and tone."))
        XCTAssertFalse(prompt.contains("translate"))
        XCTAssertFalse(prompt.contains("requested tone"))
    }

    func testToneReplacesPreserveToneInstruction() {
        let prompt = Prompt.system(for: ImproveOptions(targetLanguage: nil, tone: .veryFormal))
        XCTAssertTrue(prompt.contains("Preserve its meaning."))
        XCTAssertFalse(prompt.contains("and tone"))
        XCTAssertTrue(prompt.contains("already matches the requested tone"))
        XCTAssertTrue(prompt.contains(Tone.veryFormal.instruction!))
    }

    func testTargetLanguageAddsTranslation() {
        let prompt = Prompt.system(for: ImproveOptions(targetLanguage: "German", tone: .casual))
        XCTAssertTrue(prompt.contains("translate the text into German"))
        XCTAssertTrue(prompt.contains(Tone.casual.instruction!))
    }
}

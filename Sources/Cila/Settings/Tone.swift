/// The register the improved (and possibly translated) text should be written in.
enum Tone: String, CaseIterable, Identifiable {
    case original, veryFormal, formal, casual, veryCasual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: "Original Tone"
        case .veryFormal: "Very Formal"
        case .formal: "Formal"
        case .casual: "Casual"
        case .veryCasual: "Very Casual"
        }
    }

    /// Prompt instruction; nil keeps the text's own tone.
    var instruction: String? {
        switch self {
        case .original:
            nil
        case .veryFormal:
            """
            Write it in a very formal, polite and respectful tone, suitable for official or \
            business correspondence. Where the language distinguishes formal and informal \
            address (e.g. Turkish "siz", German "Sie", French "vous"), use the formal form.
            """
        case .formal:
            """
            Write it in a polite, professional tone. Where the language distinguishes formal \
            and informal address, prefer the formal form.
            """
        case .casual:
            """
            Write it in a friendly, relaxed and natural tone, like talking to a colleague you \
            know well. Where the language distinguishes formal and informal address \
            (e.g. Turkish "sen", German "du"), use the informal form.
            """
        case .veryCasual:
            """
            Write it in a very casual, warm and familiar tone, like texting a close friend, \
            using natural everyday expressions while keeping it clear. Use the informal form \
            of address.
            """
        }
    }
}

/// Per-request choices; start from the Settings defaults and can be changed
/// in the panel or composer.
struct ImproveOptions: Equatable {
    var targetLanguage: String?
    var tone: Tone
}

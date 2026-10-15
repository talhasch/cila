import XCTest
@testable import Cila

/// Copies that should open the panel vs. be ignored.
final class TextFilterTests: XCTestCase {
    private func assertOffered(_ samples: [String], file: StaticString = #filePath, line: UInt = #line) {
        for text in samples where TextFilter.shouldIgnore(text) {
            XCTFail("Should be offered: \(text.debugDescription)", file: file, line: line)
        }
    }

    private func assertIgnored(_ samples: [String], file: StaticString = #filePath, line: UInt = #line) {
        for text in samples where !TextFilter.shouldIgnore(text) {
            XCTFail("Should be ignored: \(text.debugDescription)", file: file, line: line)
        }
    }

    func testProseIsOffered() {
        assertOffered([
            "I think we should meet tomorrow at 5pm to discuss the plan.",
            "Merhaba, yarın toplantıya katılamıyorum çünkü hastayım. Kusura bakmayın.",
            "bu cumle biraz hatali yazilmis olabilir ama anlasiliyor sanirim",
            "Hey team, quick update: the release is delayed by two days because QA found 3 blocking bugs. Sorry!",
            "Ich habe gestern das Buch gelesen, aber ich verstehe das Ende nicht ganz.",
            "Bonjour, je voudrais réserver une table pour deux personnes ce soir.",
            "Thanks for the feedback 🙏 I'll fix it asap and send a new version tonight",
            "Can you check https://example.com/docs before the call? I added a few notes there.",
            "- Fix the login bug\n- Update the docs for the new API\n- Send the invoice to the client",
            "Dear Mr. Smith,\n\nThank you for your email. Unfortunately we cannot accept returns after 30 days.\n\nBest regards,\nAnna",
            "Toplantı 14:30'da başlayacak, lütfen 10 dakika önce orada olun ve sunumu getirin.",
            "we need to fix this asap the app crashes when i click the button twice",
            "Our revenue grew 12% in Q3, driven mostly by the new subscription plan.",
            "Sipariş numaranız 48213 olup kargoya verilmiştir, 2-3 gün içinde elinize ulaşır.",
            "The function returns null when the user isn't logged in, so we should handle that case.",
            "The meeting is at 10:30 (room 4) — please bring your laptop and notes.",
            "We need to fix this ASAP: the app crashes when I click the button twice.",
            "Public speaking is hard for many people, especially at first.",
            "Import duties were raised for many goods last year by the government.",
            "Select the file and press the button for (at least) three seconds.",
            "If (and only if) you agree, we can sign the contract next week.",
            "Let me know if you need anything else from me today, thanks!",
        ])
    }

    func testShortCasualProseIsOffered() {
        assertOffered([
            "Can you send it today please?",
            "yarın görüşürüz o zaman tamam mı",
            "ok sounds good to me then",
            "Danke, das klingt gut für mich.",
            "Bu PR'ı review edebilir misin, deadline yarın",
            "pls fix asap its broken again",
            "Let's ship it on Monday morning",
            "Selamlar, dosyayı ekte gönderiyorum.",
            "hocam bu akşam müsait misiniz acaba",
        ])
    }

    func testIdentifiersAndValuesAreIgnored() {
        assertIgnored([
            "hello",
            "https://www.example.com/some/long/path?query=1&other=two",
            "talha.bugra.bulut@example.com",
            "/Users/work/Documents/My Project Files/report-final.pdf",
            "+90 (532) 123 45 67  -  1,234,567.89",
            "example.com",
            "3f2b9c1e-8a4d-4b7e-9f1a-2c3d4e5f6a7b 7c9c4441-ff2d-4868-9a52-4905c5ea44ab",
            "SGVsbG8gV29ybGQhIFRoaXMgaXMgYSBiYXNlNjQgZW5jb2RlZCBzdHJpbmcgZm9yIHRlc3Rpbmcu",
            "Product ID: XK-2291-B  Serial: 00A7F3C9  Batch: 2024/11",
        ])
    }

    func testCodeIsIgnored() {
        assertIgnored([
            "let x = foo(bar); if (x > 3) { return x; }",
            "func improve(text: String) -> String {\n    return text.trimmed\n}",
            "{\"name\": \"cila\", \"version\": 1, \"enabled\": true}",
            "git commit -m \"fix the panel position bug\"",
            "import SwiftUI\nimport AppKit\n\nstruct Foo: View {}",
            "def add(a, b):\n    return a + b\n\nprint(add(1, 2))",
            "SELECT name, email FROM users WHERE active = 1 ORDER BY name",
            "select id, name from users where active = true order by created_at desc",
            "class Foo: Bar {\n    var x = 1\n}",
            "server:\n  port: 8080\n  host: localhost\ndatabase:\n  url: postgres://localhost/db",
            "export OPENAI_API_KEY=sk-xxx\nexport PATH=$PATH:/usr/local/bin",
            ".panel { display: flex; padding: 14px; border-radius: 12px; }",
            "<div class=\"container\"><p>Hello world</p></div>",
            "\\begin{equation} E = mc^2 \\end{equation}",
            "brew install --cask visual-studio-code && brew upgrade",
        ])
    }

    func testToolOutputIsIgnored() {
        assertIgnored([
            "2026-10-15 14:03:22.114 Cila[81818:1234567] Error: connection refused (code=61)",
            "at com.example.app.MainActivity.onCreate(MainActivity.java:42)\nat android.app.Activity.performCreate(Activity.java:7136)",
            "On branch main\nChanges not staged for commit:\n  modified:   Sources/Cila/AppDelegate.swift\n  modified:   build.sh",
            "drwxr-xr-x   3 work  staff    96 Oct 15 13:42 .\n-rw-r--r--   1 work  staff  3629 Oct 15 13:43 SPEC.md",
            "Traceback (most recent call last):\n  File \"main.py\", line 3, in <module>\n    foo()\nNameError: name 'foo' is not defined",
            "error[E0382]: borrow of moved value: `x`\n --> src/main.rs:4:20",
            "a3f5c9e 2026-10-14 fix panel position\nb81d2aa 2026-10-13 add composer window",
        ])
    }

    func testTablesListsAndLabelsAreIgnored() {
        assertIgnored([
            "name,email,age\nAlice,alice@example.com,30\nBob,bob@example.com,25",
            "Name\tEmail\tAge\nAlice\talice@example.com\t30\nBob\tbob@example.com\t25",
            "| Name | Price | Stock |\n|------|-------|-------|\n| Apple | 1.20 | 50 |",
            "Alice Johnson\nBob Smith\nCarol White\nDavid Brown\nEve Black",
            "File  Edit  View  History  Bookmarks  Window  Help",
            "Downloads  Documents  Desktop  Pictures  Music  Movies  Library  Applications",
            "Quarterly Revenue Report 2024 Final Version",
            "1. Settings\n2. Profile\n3. Logout\n4. Help",
        ])
    }

    func testVeryShortTextIsIgnored() {
        assertIgnored(["Thanks a lot!", "ok, tamam o zaman", "Sounds good to me"])
        assertOffered(["Can you send it today please?"])
    }
}

import XCTest
@testable import LifeNotch

final class BrowserTests: XCTestCase {
    func testFullAddressIsKept() {
        let url = BrowserURLResolver.resolve("https://www.khanacademy.org/math", engine: .google)
        XCTAssertEqual(url?.absoluteString, "https://www.khanacademy.org/math")
    }

    func testBareDomainGetsHTTPS() {
        XCTAssertEqual(BrowserURLResolver.resolve("khanacademy.org", engine: .google)?.absoluteString,
                       "https://khanacademy.org")
        XCTAssertEqual(BrowserURLResolver.resolve("bbc.co.uk/sport", engine: .google)?.absoluteString,
                       "https://bbc.co.uk/sport")
    }

    func testPlainWordsBecomeASearch() {
        let url = BrowserURLResolver.resolve("how do volcanoes form", engine: .duckDuckGo)
        XCTAssertEqual(url?.host, "duckduckgo.com")
        XCTAssertTrue(url?.absoluteString.contains("q=how") ?? false)
    }

    func testEachEngineUsesItsOwnHost() {
        XCTAssertEqual(SearchEngine.google.searchURL(for: "x")?.host, "www.google.com")
        XCTAssertEqual(SearchEngine.bing.searchURL(for: "x")?.host, "www.bing.com")
        XCTAssertEqual(SearchEngine.brave.searchURL(for: "x")?.host, "search.brave.com")
    }

    func testScriptSchemeIsNeverOpenedFromTheAddressBar() {
        let url = BrowserURLResolver.resolve("javascript:alert(1)", engine: .google)
        XCTAssertEqual(url?.host, "www.google.com")   // treated as a search, not run
    }

    func testEmptyInputGivesNothing() {
        XCTAssertNil(BrowserURLResolver.resolve("   ", engine: .google))
    }

    func testSafetyChecks() {
        XCTAssertTrue(URLSafety.assess(URL(string: "https://example.com/setup.dmg")!).isDownload)
        XCTAssertFalse(URLSafety.assess(URL(string: "https://example.com/page.html")!).isDownload)
        XCTAssertFalse(URLSafety.assess(URL(string: "http://192.168.1.5/")!).warnings.isEmpty)
        XCTAssertFalse(URLSafety.assess(URL(string: "https://xn--pple-43d.com/")!).warnings.isEmpty)
        XCTAssertFalse(URLSafety.assess(URL(string: "https://google.com@evil.example/")!).warnings.isEmpty)
        XCTAssertTrue(URLSafety.assess(URL(string: "http://example.com/")!).notSecure)
        XCTAssertTrue(URLSafety.assess(URL(string: "https://example.com/")!).warnings.isEmpty)
    }
}

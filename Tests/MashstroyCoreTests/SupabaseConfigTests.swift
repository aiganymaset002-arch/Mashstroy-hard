import XCTest
@testable import MashstroyCore

final class SupabaseConfigTests: XCTestCase {
    func testMissingOrPlaceholderValuesMeanSimulator() {
        XCTAssertNil(SupabaseConfig.load(environment: [:], infoDictionary: nil))
        XCTAssertNil(SupabaseConfig.load(environment: [
            SupabaseConfig.urlKey: "https://YOUR_PROJECT_REF.supabase.co",
            SupabaseConfig.anonKeyKey: "YOUR_ANON_KEY"
        ], infoDictionary: nil))
        XCTAssertNil(SupabaseConfig.load(environment: [:], infoDictionary: [
            SupabaseConfig.urlKey: "$(MASHSTROY_SUPABASE_URL)",
            SupabaseConfig.anonKeyKey: "$(MASHSTROY_SUPABASE_ANON_KEY)"
        ]))
        XCTAssertNil(SupabaseConfig(url: "http://insecure.example.com", anonKey: "key"))
    }

    func testEnvironmentWinsOverInfoPlist() throws {
        let config = try XCTUnwrap(SupabaseConfig.load(
            environment: [SupabaseConfig.urlKey: "https://abc.supabase.co", SupabaseConfig.anonKeyKey: " env-key "],
            infoDictionary: [SupabaseConfig.urlKey: "https://other.supabase.co", SupabaseConfig.anonKeyKey: "plist-key"]))
        XCTAssertEqual(config.url.host, "abc.supabase.co")
        XCTAssertEqual(config.anonKey, "env-key")
    }
}

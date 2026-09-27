import XCTest
@testable import MashstroyCore

final class SupabaseConfigTests: XCTestCase {
    func testMissingOrPlaceholderValuesMeanSimulator() {
        XCTAssertNil(SupabaseConfig.load(environment: [:], infoDictionary: nil))
        XCTAssertNil(SupabaseConfig.load(environment: [
            SupabaseConfig.urlKey: "https://qpiweupinpkfmiitrbut.supabase.co",
            SupabaseConfig.publishableKeyKey: "sb_publishable_YOUR_KEY"
        ], infoDictionary: nil))
        XCTAssertNil(SupabaseConfig.load(environment: [:], infoDictionary: [
            SupabaseConfig.urlKey: "https://qpiweupinpkfmiitrbut.supabase.co",
            SupabaseConfig.publishableKeyKey: "$(MASHSTROY_SUPABASE_PUBLISHABLE_KEY)"
        ]))
        XCTAssertNil(SupabaseConfig.load(environment: [:], infoDictionary: [
            SupabaseConfig.urlKey: "https://qpiweupinpkfmiitrbut.supabase.co",
            SupabaseConfig.publishableKeyKey: ""
        ]))
        XCTAssertNil(SupabaseConfig(url: "http://insecure.example.com", anonKey: "key"))
    }

    func testSecretKeyIsRejected() {
        XCTAssertNil(SupabaseConfig(url: "https://qpiweupinpkfmiitrbut.supabase.co", anonKey: "sb_secret_abc"))
    }

    func testPublishableKeyFromInfoPlist() throws {
        let config = try XCTUnwrap(SupabaseConfig.load(environment: [:], infoDictionary: [
            SupabaseConfig.urlKey: "https://qpiweupinpkfmiitrbut.supabase.co",
            SupabaseConfig.publishableKeyKey: "sb_publishable_test"
        ]))
        XCTAssertEqual(config.url.host, "qpiweupinpkfmiitrbut.supabase.co")
        XCTAssertEqual(config.anonKey, "sb_publishable_test")
    }

    func testLegacyAnonKeyStillWorks() throws {
        let config = try XCTUnwrap(SupabaseConfig.load(environment: [:], infoDictionary: [
            SupabaseConfig.urlKey: "https://abc.supabase.co",
            SupabaseConfig.anonKeyKey: "legacy-anon"
        ]))
        XCTAssertEqual(config.anonKey, "legacy-anon")
    }

    func testEnvironmentWinsOverInfoPlist() throws {
        let config = try XCTUnwrap(SupabaseConfig.load(
            environment: [SupabaseConfig.urlKey: "https://abc.supabase.co", SupabaseConfig.publishableKeyKey: " env-key "],
            infoDictionary: [SupabaseConfig.urlKey: "https://other.supabase.co", SupabaseConfig.publishableKeyKey: "plist-key"]))
        XCTAssertEqual(config.url.host, "abc.supabase.co")
        XCTAssertEqual(config.anonKey, "env-key")
    }
}

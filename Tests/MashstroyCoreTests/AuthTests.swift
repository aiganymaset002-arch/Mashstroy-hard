import XCTest
@testable import MashstroyCore

final class AuthTests: XCTestCase {
    func testDemoSignIn() async throws {
        let auth = DemoAuthService()
        let user = try await auth.signIn(email: "engineer@mashstroy.kz", password: "secret1", role: .engineer)
        XCTAssertEqual(user.name, "engineer")
        XCTAssertTrue(user.can(.controlMachine))
    }

    func testInvalidCredentials() async {
        let auth = DemoAuthService()
        do {
            _ = try await auth.signIn(email: "no-at-sign", password: "secret1", role: .viewer)
            XCTFail("expected invalidEmail")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidEmail)
        }
        do {
            _ = try await auth.signIn(email: "a@b.kz", password: "123", role: .viewer)
            XCTFail("expected weakPassword")
        } catch {
            XCTAssertEqual(error as? AuthError, .weakPassword)
        }
    }

    func testRolePermissions() {
        XCTAssertEqual(UserRole.owner.permissions, Set(Permission.allCases))
        XCTAssertFalse(UserRole.viewer.permissions.contains(.controlMachine))
        XCTAssertFalse(UserRole.viewer.permissions.contains(.emergencyStop))
        XCTAssertTrue(UserRole.technician.permissions.contains(.manageFaults))
        XCTAssertFalse(UserRole.technician.permissions.contains(.controlMachine))
        XCTAssertFalse(UserRole.client.permissions.contains(.viewHardware))
    }

    func testModuleRegistry() {
        XCTAssertEqual(ModuleRegistry.descriptor(for: .smartConveyor).availability, .active)
        XCTAssertEqual(ModuleRegistry.all.count, ModuleKind.allCases.count)
    }
}

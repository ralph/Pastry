import Foundation

/// Whether this process is running a test bundle rather than a real launch.
///
/// Unit tests are hosted by the app, so the app delegate runs during every
/// test. Side effects such as timers, status items and global hotkeys are
/// skipped when this reports `true`.
enum AppEnvironment {
    static var isRunningTests: Bool {
        isRunningTests(
            environment: ProcessInfo.processInfo.environment,
            hasXCTestClass: NSClassFromString("XCTestCase") != nil
        )
    }

    static func isRunningTests(
        environment: [String: String],
        hasXCTestClass: Bool
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil || hasXCTestClass
    }
}

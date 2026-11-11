import Foundation

/// Whether this process is running a test bundle rather than a real launch.
///
/// The unit tests are hosted by the app, so launching them launches Pastry and
/// runs its delegate. Side effects — the status item now, a pasteboard timer
/// and a global hotkey later — are skipped when this reports `true`.
///
/// `XCTestConfigurationFilePath` is set on the host process by `xcodebuild
/// test`, for Swift Testing as well as XCTest, and is the only signal used. A
/// false positive would leave the shipping app running but completely inert,
/// so one narrow check is worth more than several broad ones.
enum AppEnvironment {
    static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

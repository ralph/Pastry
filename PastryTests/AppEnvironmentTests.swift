import Testing
@testable import Pastry

@Suite("AppEnvironment")
struct AppEnvironmentTests {
    /// The guard's whole premise is that this signal is present in a hosted
    /// test run. If it ever stops being set, this is what catches it — before
    /// the app starts skipping its own setup in production.
    @Test("detects that this very process is a test run")
    func liveProcessIsATestRun() {
        #expect(AppEnvironment.isRunningTests)
    }
}

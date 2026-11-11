import Testing
@testable import Pastry

@Suite("AppEnvironment")
struct AppEnvironmentTests {
    @Test("detects a test run from the XCTest configuration variable")
    func detectsFromEnvironment() {
        let environment = ["XCTestConfigurationFilePath": "/tmp/whatever.xctestconfiguration"]
        #expect(AppEnvironment.isRunningTests(environment: environment, hasXCTestClass: false))
    }

    @Test("detects a test run from the presence of the XCTest runtime")
    func detectsFromRuntime() {
        #expect(AppEnvironment.isRunningTests(environment: [:], hasXCTestClass: true))
    }

    @Test("reports a normal launch when neither signal is present")
    func detectsNormalLaunch() {
        #expect(!AppEnvironment.isRunningTests(environment: [:], hasXCTestClass: false))
    }

    @Test("reports a test run for the live process, since this is one")
    func liveProcessIsATestRun() {
        #expect(AppEnvironment.isRunningTests)
    }
}

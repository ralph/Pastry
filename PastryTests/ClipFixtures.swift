import Foundation
@testable import Pastry

extension Clip {
    /// One builder for every suite, so a new `Clip` field is one edit.
    static func fixture(
        _ text: String,
        app: String? = "Safari",
        bundleURL: URL? = nil,
        at seconds: TimeInterval = 0
    ) -> Clip {
        Clip(
            text: text,
            appName: app,
            appBundleURL: bundleURL,
            date: Date(timeIntervalSince1970: seconds)
        )
    }
}

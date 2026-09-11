import MiseCore
import Testing

// Proves the app-hosted test bundle links MiseCore; feature-flow tests live in the package.
@Test func appTestBundleLinksMiseCore() {
    #expect(Version.major(of: "1.2.3") == 1)
}

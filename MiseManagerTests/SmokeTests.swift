import MiseCore
import Testing

// Proves the app-hosted test bundle links MiseCore. Feature-flow tests (Phase 2) replace this.
@Test func appTestBundleLinksMiseCore() {
    #expect(Version.major(of: "1.2.3") == 1)
}

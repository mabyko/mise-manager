import Foundation
import Testing
@testable import MiseCore

// Mirrors src/mainview/core/settings.test.ts (UserDefaults cannot fail synchronously, so the save-error case is gone).
@MainActor struct SettingsTests {
    @Test func settingsSurviveReloadAndInvalidSavedValuesFallBackToSafeDefaults() {
        let defaults = UserDefaults(suiteName: "mise-manager.tests.settings.\(UUID().uuidString)")!
        #expect(Settings(defaults: defaults).showMenuBarIcon)

        let settings = Settings(defaults: defaults)
        settings.theme = .dark
        settings.checkIntervalHours = 6
        settings.checkOnStartup = false
        settings.showMenuBarIcon = false
        let reloaded = Settings(defaults: defaults)
        #expect(!reloaded.showMenuBarIcon)
        #expect(reloaded.theme == .dark)
        #expect(reloaded.checkIntervalHours == 6)
        #expect(!reloaded.checkOnStartup)
        #expect(!reloaded.switchGlobalAfterUpdate)
        settings.showMenuBarIcon = true
        #expect(Settings(defaults: defaults).showMenuBarIcon)

        defaults.set("false", forKey: "mise-manager.showMenuBarIcon")
        defaults.set(-1, forKey: "mise-manager.checkIntervalHours")
        defaults.set("true", forKey: "mise-manager.switchGlobalAfterUpdate")
        defaults.set("unknown", forKey: "mise-manager.theme")
        let invalid = Settings(defaults: defaults)
        #expect(invalid.showMenuBarIcon)
        #expect(invalid.checkIntervalHours == 0)
        #expect(!invalid.switchGlobalAfterUpdate)
        #expect(invalid.theme == .system)
    }
}

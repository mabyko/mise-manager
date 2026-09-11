import Foundation
import Observation

public enum Theme: String, Sendable, CaseIterable { case system, light, dark }

/// The six user settings, persisted in UserDefaults under `mise-manager.*`. Invalid stored values fall back to defaults.
@MainActor @Observable public final class Settings {
    public static let intervalChoices = [0, 1, 6, 24]
    @ObservationIgnored private let defaults: UserDefaults

    public var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: Self.key("showMenuBarIcon")) } }
    public var checkOnStartup: Bool { didSet { defaults.set(checkOnStartup, forKey: Self.key("checkOnStartup")) } }
    public var checkIntervalHours: Int { didSet { defaults.set(checkIntervalHours, forKey: Self.key("checkIntervalHours")) } }
    public var theme: Theme { didSet { defaults.set(theme.rawValue, forKey: Self.key("theme")) } }
    public var showPrereleases: Bool { didSet { defaults.set(showPrereleases, forKey: Self.key("showPrereleases")) } }
    public var switchGlobalAfterUpdate: Bool { didSet { defaults.set(switchGlobalAfterUpdate, forKey: Self.key("switchGlobalAfterUpdate")) } }

    static func key(_ name: String) -> String { "mise-manager.\(name)" }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showMenuBarIcon = defaults.object(forKey: Self.key("showMenuBarIcon")) as? Bool ?? true
        checkOnStartup = defaults.object(forKey: Self.key("checkOnStartup")) as? Bool ?? true
        let interval = defaults.object(forKey: Self.key("checkIntervalHours")) as? Int ?? 0
        checkIntervalHours = Self.intervalChoices.contains(interval) ? interval : 0
        theme = (defaults.string(forKey: Self.key("theme")).flatMap(Theme.init(rawValue:))) ?? .system
        showPrereleases = defaults.object(forKey: Self.key("showPrereleases")) as? Bool ?? false
        switchGlobalAfterUpdate = defaults.object(forKey: Self.key("switchGlobalAfterUpdate")) as? Bool ?? false
    }
}

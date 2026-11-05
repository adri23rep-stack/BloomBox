// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack.
// GameBox-specific translation lookup for runtime/dynamic strings.
// Literal SwiftUI labels also resolve through Resources/en.lproj/Localizable.strings.
import Foundation

enum BloomBoxGameBoxL10n {
    /// Uses the language selected in BloomBox Experiments, or the device
    /// language if System is selected. Spanish is the source/fallback language.
    static func t(_ source: String) -> String {
        let preference = LiveContainerPreferencesAdapter.defaults.string(forKey: "BloomBoxPreferredLanguage") ?? "system"
        let language = preference == "system" ?
            (Locale.preferredLanguages.first ?? Locale.current.identifier) : preference

        guard language.lowercased().hasPrefix("en"),
              let directory = Bundle.main.path(forResource: "en", ofType: "lproj"),
              let english = Bundle(path: directory) else {
            return source
        }
        return english.localizedString(forKey: source, value: source, table: "Localizable")
    }
}

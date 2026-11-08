// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack.
// Runtime localization for values assembled outside SwiftUI's literal
// LocalizedStringKey path (saved library categories, shortcuts, status labels).
import Foundation

enum BloomBoxL10n {
    private static let englishBundle: Bundle? = {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }()

    static var isEnglish: Bool {
        let preference = LiveContainerPreferencesAdapter.defaults.string(
            forKey: "BloomBoxPreferredLanguage") ?? "system"
        let language = preference == "system"
            ? (Locale.preferredLanguages.first ?? "en")
            : preference
        return language.lowercased().hasPrefix("en")
    }

    /// Translate a display label without changing its persisted identifier.
    /// Unknown strings are preserved (user-created folder names, app titles).
    static func t(_ source: String) -> String {
        guard isEnglish, let englishBundle else { return source }
        return englishBundle.localizedString(
            forKey: source, value: source, table: "Localizable")
    }
}

/// Historical name kept for GameBox so existing UI and plugin bridges work.
enum BloomBoxGameBoxL10n {
    static func t(_ source: String) -> String {
        BloomBoxL10n.t(source)
    }
}

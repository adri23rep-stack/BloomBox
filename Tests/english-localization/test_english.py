#!/usr/bin/env python3
"""Presentation readiness: English UI localization and catalog schema contracts."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
strings_file = root / "Resources/en.lproj/Localizable.strings"
text = strings_file.read_text(encoding="utf-8")
rows = re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$', text, re.M)
keys = [key for key, _ in rows]
assert len(keys) >= 730, f"English translations regressed: {len(keys)}"
assert len(keys) == len(set(keys)), "Duplicate keys in English localization"
for key, value in rows:
    assert key and value.strip(), f"Missing English value for {key!r}"
    assert not re.search(r"(?<!\\)\"", key), f"Unescaped quotation: {key!r}"

# Don't let new Spanish-only on-screen literals silently enter primary areas.
sources = [
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxModulesAndJIT.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxRemoteStores.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxNewsPage.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxProfileScreens.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxWizardWelcome.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxWizardHighlights.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxWizardThemeChoice.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxWidgetGallery.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxWidgetViews.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxExpiryReminderSettings.swift",
    "LiveContainerSwiftUI/Views/BloomBoxRAMPlusView.swift",
    "LiveContainerSwiftUI/Views/BloomBoxThemeStore.swift",
    "LiveContainerSwiftUI/Views/AppList/AppSettings/BloomBoxBackupView.swift",
]
ui_pattern = re.compile(
    r'(?:Text|Label|Button|Toggle|Section|Picker|TextField|ProgressView|'
    r'NavigationLink|GroupBox|SecureField|\.alert|\.confirmationDialog|'
    r'\.navigationTitle|\.accessibilityLabel|\.help)'
    r'\(\s*"((?:[^"\\]|\\.){2,280})"'
)
spanish = re.compile(
    r'[áéíóúñÁÉÍÓÚÑ¿¡]|'
    r'\b(?:de|del|la|las|los|para|por|sin|con|una|uno|este|esta|'
    r'es|no|más|menos|solo|si|desde|hasta|hacia|ahora|antes|después|'
    r'aquí|tu|tus|al|que|se|estos|crear|añadir|abrir|guardar|'
    r'seleccionar|buscar|cambiar|eliminar|quitar|instalar|comprobar|'
    r'ver|actualizar|tamaño|fondo|fotos|reloj|pagina|página|'
    r'aplicación|aplicaciones|perfiles|perfil|ajustes)\b',
    re.I
)
key_set = set(keys)
untranslated = []
for source in sources:
    body = (root / source).read_text(encoding="utf-8")
    # Interpolated SwiftUI strings are audited separately in code: their
    # generated localization keys contain placeholders, not literal \(name).
    for match in ui_pattern.finditer(body):
        phrase = match.group(1)
        if r"\(" in phrase:
            continue
        if spanish.search(phrase) and phrase not in key_set:
            untranslated.append((source, phrase))
assert not untranslated, "Spanish-only primary UI literals:\n" + "\n".join(
    f"  {path}: {phrase}" for path, phrase in untranslated
)

stores = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxRemoteStores.swift").read_text()
for token in [
    'let descriptionEn: String?',
    'let notesEn: String?',
    'func localizedDescription(english: Bool)',
    'func localizedNotes(english: Bool)',
    'Text(item.localizedDescription(english: englishUI))',
    'Text(match.entry.localizedDescription(english: englishUI))',
    'Text(entry.localizedDescription(english: englishUI))',
    'Text(LocalizedStringKey(item.categoryTitle))',
    'BloomBoxPreferredLanguage',
]:
    assert token in stores, f"Catalog English display path missing: {token}"
app = (root / "LiveContainerSwiftUI/App/LiveContainerSwiftUIApp.swift").read_text()
assert 'case "en": return Locale(identifier: "en")' in app
assert 'case "es": return Locale(identifier: "es_MX")' in app
print(f"English localization: {len(keys)} unique strings, {len(sources)} UI screens, both stores OK.")

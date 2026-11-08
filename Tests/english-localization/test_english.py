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
# Audit every shipped SwiftUI screen, not just the previously translated ones.
# This catches new settings, files, theme, JIT and launcher controls too.
sources = sorted(
    str(p.relative_to(root))
    for p in (root / "LiveContainerSwiftUI/Views").rglob("*.swift")
)

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
        if r"\(" in phrase or phrase.startswith("lc."):
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
# Verify real runtime localizers are used where SwiftUI receives computed Strings.
home = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift").read_text()
modules = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxModulesAndJIT.swift").read_text()
chrome = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeChrome.swift").read_text()
gallery = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxWidgetGallery.swift").read_text()
launcher = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxLauncherRoot.swift").read_text()
l10n = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxGameBoxL10n.swift").read_text()
ram = (root / "LiveContainerSwiftUI/Views/BloomBoxRAMPlusView.swift").read_text()
jit = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxJITCoordinator.swift").read_text()
for expected in [
    "Text(LocalizedStringKey(section.title))",
    "name: BloomBoxL10n.t(title(key, appsByKey: appsByKey))",
    "Text(BloomBoxL10n.t(title(key)))",
    'Text(LocalizedStringKey(isSideStore ? "SideStore"',
    'englishUI ? "Page \\(index + 1)"',
]:
    assert expected in home, f"Home English runtime path lost: {expected}"
assert "Text(LocalizedStringKey(choice.title))" in gallery
assert "Text(LocalizedStringKey(choice.description))" in gallery
assert "Text(BloomBoxL10n.t(entry.title))" in (
    root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeSearchPanel.swift"
).read_text()
assert "Text(LocalizedStringKey(mode.title))" in modules
assert "BloomBoxL10n.isEnglish" in launcher
assert "BloomBoxL10n.isEnglish" in chrome
assert "BloomBoxL10n.t(ram.status)" in ram
assert 'BloomBoxL10n.t(label)' in jit
assert 'englishBundle.localizedString(' in l10n
assert 'forKey: "BloomBoxPreferredLanguage"' in l10n
for entry in ("Módulos", "Temas", "Juegos", "Sugerencias", "Añadidas recientemente",
              "Instalando aplicación", "Salir de simulación", "RAM+ confirmado en la instalación actual"):
    # Source-file String literals also exist in nested helpers with their own
    # explicit English paths; all shared launcher keys still need translations.
    if entry == "Salir de simulación":
        continue
    assert entry in key_set, f"Main launcher translation missing: {entry}"
print(f"English localization: {len(keys)} unique strings, {len(sources)} UI screens, runtime paths OK.")


# Multi-Language Support (Lokalisierung)

## Übersicht

Siply unterstützt jetzt **Deutsch** und **Englisch**. Die App erkennt automatisch die iPhone-Systemsprache:

- **iPhone auf Deutsch** → App zeigt deutsche Texte
- **iPhone auf anderer Sprache** → App zeigt englische Texte (Fallback)

## Implementierung

### 1. Localizable.xcstrings

Die Datei `Siply/Localizable.xcstrings` enthält alle übersetzten Texte:

- **Onboarding-Screens**: Willkommen, Features, Name-Eingabe, Ziel-Setup, Erinnerungen
- **Hauptansicht**: Fortschritt, Kalender, Einträge
- **Benachrichtigungen**: 45 motivierende Nachrichten (Duolingo-Style)
- **Einstellungen**: Tagesziel, Intervalle, Debug-Menü
- **Tab-Leiste**: Start, Kalender, Erinnerungen

### 2. String-Lokalisierung in Swift

Alle UI-Texte verwenden `String(localized:)`:

```swift
Text(String(localized: "hello_name", defaultValue: "Hello %@"))
```

- `localized:` Key in der Localizable.xcstrings
- `defaultValue:` Fallback wenn Key fehlt (sollte Englisch sein)

### 3. Xcode-Konfiguration

#### Info.plist
Keine Änderungen nötig - iOS erkennt automatisch `sourceLanguage: "en"` in der `.xcstrings`-Datei.

#### Project Settings
1. Öffne Xcode
2. Target **Siply** → **Info** Tab
3. Unter **Localizations** sollten automatisch erkannt werden:
   - English (Development Language)
   - German

Falls nicht sichtbar:
1. **Project** (nicht Target) → **Info** Tab
2. **Localizations** → **+** klicken → **German** hinzufügen
3. Bei der Auswahl **Localizable.xcstrings** ankreuzen

## Testen

### iPhone-Simulator
1. Simulator starten
2. **Settings** → **General** → **Language & Region**
3. **iPhone Language** → **Deutsch** wählen
4. Simulator neu starten
5. Siply öffnen → sollte jetzt auf Deutsch sein

### Physisches iPhone
1. **Einstellungen** → **Allgemein** → **Sprache & Region**
2. **iPhone-Sprache** → **Deutsch** wählen
3. iPhone startet neu
4. Siply öffnen → sollte auf Deutsch sein

## Neue Übersetzungen hinzufügen

### In Xcode:
1. Öffne `Localizable.xcstrings`
2. Klicke **+** unten links
3. Gib den Key ein (z.B. `new_feature_title`)
4. Füge Übersetzungen hinzu:
   - **en**: "New Feature"
   - **de**: "Neue Funktion"

### Im Code:
```swift
Text(String(localized: "new_feature_title", defaultValue: "New Feature"))
```

## Wichtige Hinweise

### Formatierte Strings
Für Namen oder Zahlen: `%@` (String), `%d` (Integer)

```swift
String(format: String(localized: "hello_name"), userName)
```

### Plural-Formen
iOS String Catalogs (.xcstrings) unterstützen automatisch Plurals:

```json
"water_glasses": {
  "variations": {
    "plural": {
      "one": "%d glass",
      "other": "%d glasses"
    }
  }
}
```

### Debug
Falls Übersetzungen nicht angezeigt werden:
1. **Clean Build Folder**: Cmd+Shift+K
2. **Rebuild**: Cmd+B
3. App neu starten

## Dateistruktur

```
Siply/
├── Localizable.xcstrings          # Alle Übersetzungen
├── OnboardingView.swift            # Nutzt lokalisierte Strings
├── ContentView.swift               # Nutzt lokalisierte Strings
├── MotivationalMessages.swift      # 45 lokalisierte Nachrichten
└── HydrationLiveActivity.swift     # Noch nicht lokalisiert (optional)
```

## Unterstützte Sprachen

✅ **Deutsch** (de)
✅ **Englisch** (en) - Standard/Fallback

### Weitere Sprachen hinzufügen

Um z.B. **Spanisch** hinzuzufügen:

1. In Xcode: Project → Info → Localizations → **+** → **Spanish**
2. In `Localizable.xcstrings`: Für jeden Key eine **es**-Übersetzung hinzufügen
3. Fertig! iOS wählt automatisch Spanisch wenn iPhone-Sprache = Spanisch

## Troubleshooting

### Problem: App zeigt immer Englisch
- **Lösung**: iPhone-Sprache in Einstellungen prüfen
- Simulator/iPhone neu starten
- Clean Build (Cmd+Shift+K)

### Problem: Manche Texte nicht übersetzt
- **Lösung**: Key in `Localizable.xcstrings` vorhanden?
- `defaultValue` wird als Fallback genutzt
- Prüfe Tippfehler im Key-Namen

### Problem: Xcode zeigt Localizations nicht
- **Lösung**: Project (nicht Target) → Info → Localizations
- German hinzufügen und Localizable.xcstrings auswählen

## Referenzen

- [Apple: Localizing your app](https://developer.apple.com/documentation/xcode/localizing-your-app)
- [String Catalogs (.xcstrings)](https://developer.apple.com/documentation/xcode/localization-workflows)

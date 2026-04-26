---
name: Echte Umlaute verwenden
description: In allen Texten, Konfigs und UIs echte Umlaute (ä/ö/ü/ß) nutzen statt ae/oe/ue/ss
type: feedback
originSessionId: e12897cd-28ba-42a7-80c9-b6ec46384f39
---
In sämtlichen Ausgaben, Dateien, Konfigurationen und insbesondere in UI-Texten/Config-UIs immer echte deutsche Umlaute verwenden: ä, ö, ü, Ä, Ö, Ü, ß — nicht die Ersatzschreibweise ae, oe, ue, ss.

**Why:** Nutzer bevorzugt korrekte deutsche Orthographie. Ersatzschreibung wirkt unprofessionell und ist in UIs besonders störend.

**How to apply:** Gilt für Code-Kommentare, Strings, Labels, Konfigurationswerte, Commit-Messages, Dokumentation und Chat-Antworten auf Deutsch. Besonders aufpassen bei Config-UIs (z. B. Labels, Tooltips, Fehlermeldungen). Nur dort ae/oe/ue erlauben, wo technische Zwänge es erfordern (z. B. ASCII-only Bezeichner, Slugs, Dateinamen ohne UTF-8-Support).

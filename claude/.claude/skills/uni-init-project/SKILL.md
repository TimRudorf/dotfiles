---
name: uni-init-project
description: This skill should be used when the user asks to "initialize a uni project",
  "set up a learning project", "init Lernprojekt", "download Moodle materials",
  "Moodle-Kurs herunterladen", or uses /uni-init-project. It downloads course materials
  from Moodle (optional), creates a standardized folder structure, sorts files,
  normalizes filenames, and generates a CLAUDE.md.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
argument-hint: "[Moodle-Kurs-URL]"
disable-model-invocation: true
---

# Uni-Lernprojekt initialisieren

Initialisiert ein Uni-Lernprojekt mit standardisierter Ordnerstruktur. Optional Moodle-Kurs-URL als Argument — dann werden Kursmaterialien automatisch heruntergeladen und Kursinfos aus der Moodle API bezogen.

## Schritt 0: Moodle-Token validieren (nur Modus A)

Nur ausführen wenn `$ARGUMENTS` eine URL enthält (beginnt mit `https://`).

Prüfe ob `~/.config/moodle-dl/token.json` existiert (Format: `{"domain": "...", "token": "..."}`).

Falls vorhanden → Token lesen, weiter mit Schritt 1.

Falls nicht vorhanden → Token via Playwright-SSO einrichten:

1. User via `AskUserQuestion` informieren:
   - Frage: "Für den Moodle-Download wird einmalig ein API-Token benötigt. Ein Browser-Fenster wird geöffnet, in dem du dich über SSO anmeldest."
   - Optionen: "Browser öffnen" / "Abbrechen"
2. Bei "Abbrechen" → Skill abbrechen.
3. Bei "Browser öffnen":
   a. Domain aus URL extrahieren (z.B. `moodle.tu-darmstadt.de`)
   b. `playwright-cli open https://{domain}/login/index.php --browser=chrome --headed` — öffnet sichtbaren Browser
   c. User via `AskUserQuestion` fragen: "Bitte im Browser-Fenster einloggen. Fertig?" → "Ja, eingeloggt" / "Abbrechen"
   d. Token über Moodle Mobile-API extrahieren:
      ```bash
      playwright-cli run-code "async page => {
        const response = await page.request.fetch('https://{domain}/admin/tool/mobile/launch.php?service=moodle_mobile_app&passport=12345&urlscheme=moodlemobile', { maxRedirects: 0 });
        return { status: response.status(), headers: response.headers() };
      }"
      ```
   e. Aus dem `location`-Header den Token extrahieren: `moodlemobile://token={base64}` → Base64-dekodieren → Format: `{hash}:::{token}` → den Teil nach `:::` ist der wstoken
   f. Token validieren: `curl -s "https://{domain}/webservice/rest/server.php?wstoken={token}&wsfunction=core_webservice_get_site_info&moodlewsrestformat=json"` — prüfen dass `username` in Response vorhanden
   g. `mkdir -p ~/.config/moodle-dl` und Token speichern: `{"domain": "{domain}", "token": "{token}"}`
   h. `playwright-cli close`

Bei Fehlern (kein Location-Header, Dekodierung fehlgeschlagen, Token-Validierung schlägt fehl) → klare Fehlermeldung und Skill abbrechen.

## Schritt 1: Argument prüfen & Informationen sammeln

### Argument-Erkennung

- Falls `$ARGUMENTS` eine URL enthält (beginnt mit `https://`) → **Modus A** (Moodle-Download)
- Sonst → **Modus B** (manuell)

### Modus A: Moodle-URL gegeben

**1a) Kursinfo abrufen:**

1. Domain und Kurs-ID aus URL extrahieren (z.B. `https://moodle.tu-darmstadt.de/course/view.php?id=12345` → domain=`moodle.tu-darmstadt.de`, id=`12345`)
2. Token aus `~/.config/moodle-dl/token.json` lesen
3. Kursname via Moodle API abrufen:
   ```
   curl -s "https://{domain}/webservice/rest/server.php?wstoken={token}&wsfunction=core_course_get_courses_by_field&field=id&value={id}&moodlewsrestformat=json"
   ```
4. Kursnamen aus Response extrahieren (`.courses[0].fullname`)
5. User via `AskUserQuestion` fragen:
   - Kursname bestätigen/anpassen
   - Abschluss (Master/Bachelor)
   - Semester (z.B. WiSe 25/26, SoSe 26)

**1c) Materialien herunterladen:**

1. Kursinhalte via Moodle API abrufen:
   ```
   curl -s "https://{domain}/webservice/rest/server.php?wstoken={token}&wsfunction=core_course_get_contents&courseid={id}&moodlewsrestformat=json"
   ```
2. Alle Einträge mit `type: "file"` aus der Response sammeln
3. Jede Datei flach ins aktuelle Verzeichnis herunterladen:
   ```
   # Token korrekt anhängen: fileurl enthält oft bereits ?forcedownload=1
   if '?' in fileurl:
       url = f"{fileurl}&token={token}"
   else:
       url = f"{fileurl}?token={token}"
   curl -L --fail -o "{filename}" "{url}"
   ```
4. **Duplikat-Handling**:
   - **Gleicher Dateiname, gleiche URL** → Überspringen
   - **Gleicher Dateiname, verschiedene URLs** (kumulative Dokumente) → Nur die **neueste Version** herunterladen (höchste pluginfile-ID in der URL). Moodle-Sektions- und Modulnamen nutzen um den Kontext zu verstehen (z.B. "Exercise 9" → letzte kumulative Version).
   - Kumulative Dokumente beim Rename als `{Typ}-Sammlung.pdf` benennen (z.B. `Übung-Sammlung.pdf`).
5. **Download-Verifikation**: Nach dem Download prüfen ob Dateien > 1 KB sind. Dateien ≤ 1 KB als fehlerhaft melden und löschen. Falls > 10% der Downloads fehlschlagen → Abbruch mit Fehlermeldung.
6. Download-Zusammenfassung anzeigen (Anzahl heruntergeladener Dateien, übersprungene Duplikate, fehlerhafte Dateien)

Bei API-Fehlern (HTTP-Fehler, leere Response, `exception` in JSON) → klare Fehlermeldung und Skill abbrechen.

### Modus B: Ohne Moodle-URL

Frage den Benutzer (sofern nicht bereits bekannt):
- **Fachname** (z.B. "Systemdynamik und Regelungstechnik 3")
- **Abschluss** (z.B. Master, Bachelor)
- **Semester** (z.B. WiSe 25/26, SoSe 26)

## Schritt 2: Ordnerstruktur erstellen

Erstelle folgende Verzeichnisstruktur im aktuellen Projektordner:

```
docs/
├── Vorlesung/              # Vorlesungsfolien/-skripte
├── Übungen/
│   ├── Aufgaben/           # Übungsblätter
│   ├── Lösungen/           # Musterlösungen
│   └── Weiteres/           # Kontrollfragen, Vorrechenübungen
├── Probeklausur/
│   ├── Aufgaben/           # Klausuraufgaben
│   └── Lösungen/           # Klausurlösungen
└── Zusatz/                 # Ergänzungsmaterial (Literatur, Formelsammlungen, etc.)
```

## Schritt 3: Vorhandene Dateien einordnen

1. Scanne das gesamte Projektverzeichnis nach vorhandenen Dateien (PDFs und andere Dokumente).
2. Ordne die Dateien anhand ihres Namens in die passenden Ordner ein. Sichere Schlüsselwörter (ohne Rückfrage zuordnen):

   | Schlüsselwort im Dateinamen | Zielordner |
   |------------------------------|------------|
   | "Lösung", "Loesung", "Musterlösung" | `docs/Übungen/Lösungen/` |
   | "Aufgabe", "Übung", "Blatt" | `docs/Übungen/Aufgaben/` |
   | "Kontrollfragen" | `docs/Übungen/Weiteres/` |
   | "Klausur", "Exam", "Prüfung" + "Lösung" | `docs/Probeklausur/Lösungen/` |
   | "Klausur", "Exam", "Prüfung" (ohne "Lösung") | `docs/Probeklausur/Aufgaben/` |
   | "Skript", "Vorlesung" | `docs/Vorlesung/` |

3. **Unbekannte Dateien gruppieren und klassifizieren**: Für alle Dateien die keinem Schlüsselwort entsprechen:
   a. Nach gemeinsamen Präfixen/Mustern gruppieren (z.B. `STV01..STV12`, `UE01..UE12`, `STUE02..STUE11`)
   b. Für jede Gruppe den wahrscheinlichen Typ ableiten — dabei alle verfügbaren Hinweise nutzen:
      - Durchnummerierte Dateien mit ähnlichem Aufbau → vermutlich zusammengehörig
      - Kontext aus Moodle-Sektionsnamen nutzen (falls Modus A), z.B. Sektion "Einführung und Grundlagen" → Vorlesungsmaterial
      - **Fachkontext des Moduls** berücksichtigen (Fachname, typische Abkürzungen im Fachgebiet)
   c. **Stichprobenartig in Dateien reinschauen** bevor nachgefragt wird:
      - Pro unklarer Gruppe 1–2 repräsentative Dateien öffnen (erste Seite des PDFs lesen)
      - Anhand des Inhalts den Typ bestimmen: Vorlesungsfolien, Aufgabenblatt, Formelsammlung, etc.
      - Wenn der Inhalt die Zuordnung eindeutig klärt → direkt zuordnen, **keine Rückfrage nötig**
   d. **Nur bei verbleibender Unsicherheit** (Inhalt nicht eindeutig oder Gruppe zu heterogen) per `AskUserQuestion` den User fragen, z.B.:
      > Ich habe folgende Dateigruppen erkannt:
      > - `STV01.pdf` bis `STV12-*.pdf` (24 Dateien) → **Skript** (Vorlesungsfolien, per Stichprobe bestätigt)
      > - `MTVO4+05.pdf` etc. (6 Dateien) → unklar: Ergänzungs-Vorlesungen eines anderen Fachs? **Skript** oder **Sonstiges**?
      > Stimmt die Zuordnung?
      Optionen: "Ja, zuordnen" / "Anpassen" (User kann korrigieren)

4. **Einzeldateien ohne erkennbares Muster**: Ebenfalls kurz den Inhalt prüfen (erste Seite lesen), um im Kontext des Moduls die richtige Kategorie zu bestimmen. Falls unklar → `docs/Zusatz/`

5. Nach der Zuordnung kurz auf offensichtliche Fehlzuordnungen prüfen (z.B. Werbung/Info-Dateien die fälschlich als Aufgaben erkannt wurden).

## Schritt 4: Universelles Dateinamen-Schema anwenden

Alle Dateien nach dem universellen Schema `{Typ}-{NN}[-{Variante}].pdf` umbenennen.

### Naming-Tabelle

| Typ | Zielordner | Bedeutung | Beispiel |
|-----|------------|-----------|----------|
| `Vorlesung` | `docs/Vorlesung/` | Folien (clean) | `Vorlesung-01.pdf` |
| `Vorlesung` | `docs/Vorlesung/` | Mit Notizen | `Vorlesung-01-Notizen.pdf` |
| `Übung` | `docs/Übungen/Aufgaben/` | Übungsblatt | `Übung-01.pdf` |
| `Lösung` | `docs/Übungen/Lösungen/` | Musterlösung | `Lösung-01.pdf` |
| `Vorrechnung` | `docs/Übungen/Weiteres/` | Vorrechenübung | `Vorrechnung-02.pdf` |
| `Kontrollfragen` | `docs/Übungen/Weiteres/` | Selbsttest | `Kontrollfragen-01.pdf` |
| `Klausur` | `docs/Probeklausur/Aufgaben/` | Klausuraufgaben | `Klausur-Probe.pdf` |
| `Klausur` | `docs/Probeklausur/Lösungen/` | Klausurlösung | `Klausur-Probe-Lösung.pdf` |
| `Zusatz` | `docs/Zusatz/` | Ergänzung | `Zusatz-Literaturliste.pdf` |
| `Hilfsblatt` | `docs/Zusatz/` | Formelsammlung | `Hilfsblatt-01.pdf` |

### Sonderfälle

- Einzelnes Skript (kein Multi-PDF-Kurs): `Vorlesung-Skript.pdf`
- Ergänzungs-Vorlesung aus anderem Fach: `Zusatz-{Fach}-VO-{NN}.pdf`
- Alte Klausuren mit Semesterangabe: `Klausur-WiSe2324.pdf` / `Klausur-WiSe2324-Lösung.pdf`

### Vorgehen

1. Rename-Plan als Tabelle erstellen (alter Name → neuer Name)
2. Den Rename-Plan dem User zur Bestätigung zeigen via `AskUserQuestion`
3. Nach Bestätigung alle Dateien mit direkten `mv`-Befehlen umbenennen. **Keine Shell-Globs** mit `ls` verwenden — `ls` kann durch Aliase (eza) formatierte Ausgabe liefern. Stattdessen explizite Dateinamen oder `"$BASE/datei.pdf"` verwenden.

## Schritt 5: CLAUDE.md mit Themenindex erstellen

Erstelle eine `CLAUDE.md` im Projektstamm nach folgendem Template:

```markdown
# CLAUDE.md

## Kurs

**{Kursname}** | {Abschluss} | {Semester}

## Dateitypen

| Pfadmuster | Beschreibung |
|---|---|
| `docs/Vorlesung/Vorlesung-NN.pdf` | Vorlesungsfolien zu Einheit NN |
| `docs/Vorlesung/Vorlesung-NN-Notizen.pdf` | Folien mit handschriftlichen Notizen |
| `docs/Übungen/Aufgaben/Übung-NN.pdf` | Übungsblatt NN |
| `docs/Übungen/Lösungen/Lösung-NN.pdf` | Musterlösung zu Übung NN |
| `docs/Übungen/Weiteres/Vorrechnung-NN.pdf` | Vorrechenübung zu Einheit NN |
| `docs/Übungen/Weiteres/Kontrollfragen-NN.pdf` | Kontrollfragen zu Vorlesung NN |
| `docs/Probeklausur/Aufgaben/Klausur-*.pdf` | Klausuraufgaben |
| `docs/Probeklausur/Lösungen/Klausur-*-Lösung.pdf` | Klausurlösungen |
| `docs/Zusatz/*.pdf` | Ergänzendes Material |

## Themenindex

| # | Thema | Vorlesung | Übung | Stichworte |
|---|-------|-----------|-------|------------|
| 01 | {Thema} | Vorlesung-01 | Übung-01 | {Keyword1, Keyword2, ...} |
| 02 | {Thema} | Vorlesung-02 | Übung-02, Vorrechnung-02 | {Keywords} |
| ... | ... | ... | ... | ... |

## Zusatzmaterial

| Datei | Beschreibung |
|---|---|
| `Zusatz-{Name}.pdf` | {Kurzbeschreibung} |

## Hinweise

- Alle Inhalte als PDF. Zum Lesen: `poppler` (`brew install poppler`).
- Primäre Quelle: `docs/Vorlesung/`.
- Nummern-Korrespondenz: Vorlesung-NN ↔ Übung-NN ↔ Lösung-NN ↔ Kontrollfragen-NN.
```

### Themenindex generieren

1. Erste Seite jeder `Vorlesung-NN.pdf` lesen → Thema + Stichworte extrahieren
2. Bei Kursen mit einem einzelnen Skript → Kapitelüberschriften aus dem Inhaltsverzeichnis nutzen
3. Zugehörige Übungen/Vorrechenübungen/Kontrollfragen anhand der Nummern-Korrespondenz zuordnen
4. Nur die tatsächlich vorhandenen Pfadmuster in die Dateitypen-Tabelle aufnehmen (leere Ordner weglassen)

## Schritt 6: Zusammenfassung anzeigen

Zeige dem Benutzer:
- Welche Ordner erstellt wurden
- Welche Dateien wohin verschoben wurden
- Welche Dateien umbenannt wurden (alter Name → neuer Name), oder dass keine Umbenennung nötig war
- Dass die CLAUDE.md erstellt wurde

## Regeln

- **Sprache**: Deutsch mit echten Umlauten (ä, ö, ü, ß)
- **Ordnerstruktur** ist fix (`docs/Vorlesung`, `docs/Übungen/Aufgaben`, `docs/Probeklausur/Aufgaben`, `docs/Zusatz` etc.) — keine abweichenden Pfade
- **Versteckte Dateien**, `.DS_Store` und `CLAUDE.md` ignorieren
- **`mkdir -p`** für Ordnererstellung verwenden
- Bei **Unsicherheit bei Dateizuordnung**: User fragen
- **CLAUDE.md immer zuletzt** erstellen (nach Umbenennung, damit der Tree aktuell ist)
- **Token** zentral in `~/.config/moodle-dl/token.json` speichern und wiederverwenden
- **Downloads** mit `curl -L --fail` ausführen
- Bei **API-Fehlern** → klare Fehlermeldung und Abbruch
- **Duplikate** (gleicher Dateiname) beim Download überspringen
- **Python-Pakete** mit `pip3` oder `python3 -m pip` installieren (nicht `pip`)
- **Absolute Pfade**: Immer `$BASE`-Variable statt `cd` verwenden. `cd` scheitert bei Pfaden mit Umlauten (zoxide-Interferenz). Pattern: `BASE=".../Projektname"` definieren und alle Pfade als `"$BASE/docs/..."` referenzieren.

---

## Skill-Optimierung

Nach Abschluss dieses Skills kurz bewerten, ob Optimierungsbedarf besteht:

- **Empfehlung "ja"**: Fehler aufgetreten, Workarounds nötig, Befehle wiederholt, User-Korrekturen
- **Empfehlung "nein"**: Reibungsloser Lauf wie dokumentiert

Per `AskUserQuestion` fragen:

> Skill abgeschlossen. Soll die Skill-Dokumentation optimiert werden?
> Empfehlung: {ja — [kurzer Grund] | nein — Lauf war reibungslos}

Optionen: **"Ja, optimieren"**, **"Nein"**

Bei "Ja": `skill-optimize` mit Skill-Name `uni-init-project` ausführen.

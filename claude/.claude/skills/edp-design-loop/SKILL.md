---
name: edp-design-loop
description: >-
  Diesen Skill verwenden, wenn der User eine UI-/Design-Änderung an einem EDP-Web-Projekt (meist edpweb) in einer autonomen Ralph-Loop umsetzen lassen will. Die Schleife ändert Code → deployed oder kompiliert auf die Dev-VM → prüft das Ergebnis per Browser-Login + Screenshot → iteriert selbstständig, bis das Modell mit dem Ergebnis zufrieden ist oder der Hard-Cap erreicht ist. Trigger-Keywords: "design loop", "ralph loop", "iteriere bis es passt", "design-loop", "/edp-design-loop".
argument-hint: "[projekt] design-ziel"
---

# EDP Design-Loop (Ralph-Loop)

Autonome Iterations-Schleife für UI-/Design-Änderungen an EDP-Web-Projekten. Ändert Code, deployed/kompiliert via `edp-develop`, verifiziert das Ergebnis per `playwright-cli` und iteriert eigenständig.

## Voraussetzungen

- Env: `EDP_VM_HOST`, `EDP_PROJECT_ROOT`
- Tools: `ssh`, `playwright-cli`, `edp`, `git`
- Projekt: `$EDP_PROJECT_ROOT/<projekt>` (Git-Repo, sauber, Feature-Branch)

Voraussetzungen gemäß `requirement-checker` Skill validieren. Bei Fehlschlag abbrechen.

## Schritt 1: Aufgabe parsen und Repo-State prüfen

Aus `$ARGUMENTS`:

- Erstes Wort = Projektname (Default: `edpweb`, wenn das erste Wort kein Verzeichnis unter `$EDP_PROJECT_ROOT` ist oder gar nichts übergeben wurde).
- Rest = Freitext-Designziel (muss nicht leer sein — sonst User fragen).

Ins Projektverzeichnis wechseln und prüfen:

```bash
cd "$EDP_PROJECT_ROOT/<projekt>"
git status --porcelain            # muss leer sein
git rev-parse --abbrev-ref HEAD   # darf nicht "main" sein
```

- Arbeitsbereich dirty → User informieren und abbrechen.
- Branch = `main` → User informieren und abbrechen (oder nach Schritt 4 des Kommunikationswegs einen neuen Feature-Branch vorschlagen).

## Schritt 2: Playwright-Config sicherstellen

edpweb nutzt ein selbst signiertes Zertifikat. Ohne Ignorieren schlägt jede Navigation fehl (`ERR_CERT_AUTHORITY_INVALID`).

Falls `.playwright/cli.config.json` im Projektverzeichnis noch nicht existiert, anlegen:

```bash
mkdir -p .playwright
cat > .playwright/cli.config.json <<'EOF'
{
  "browser": {
    "contextOptions": {
      "ignoreHTTPSErrors": true
    }
  }
}
EOF
```

## Schritt 3: Baseline-Login + Screenshot

Arbeitsverzeichnis bleibt im Projekt-Root — `playwright-cli` erlaubt Datei-Zugriff **nur** innerhalb des Projekt-Roots und dessen `.playwright-cli/` Unterordners. Pfade wie `/tmp/...` schlagen mit `outside allowed roots` fehl.

```bash
playwright-cli -s=edpdesign open --browser=chromium \
  --config=.playwright/cli.config.json \
  "https://${EDP_VM_HOST:-172.16.0.2}/"
playwright-cli -s=edpdesign snapshot
```

Aus dem Snapshot die `refs` für Benutzername-Textbox, Passwort-Textbox, Funktion-Combobox und Anmelden-Button übernehmen, dann einloggen:

```bash
playwright-cli -s=edpdesign fill   <benutzer-ref> "${EDP_DESIGN_USER:-demo}"
playwright-cli -s=edpdesign fill   <passwort-ref> "${EDP_DESIGN_PASS:-demo}"
playwright-cli -s=edpdesign select <funktion-ref> "${EDP_DESIGN_FUNKTION:-EL}"
playwright-cli -s=edpdesign click  <anmelden-ref>
playwright-cli -s=edpdesign snapshot --filename=baseline.yml
playwright-cli -s=edpdesign screenshot --filename=baseline.png
```

Verifikation: Nach Login ist oben rechts ein Button mit dem Muster `"<user> (<funktion>)"` sichtbar (z.B. `"demo (EL)"`) und die Startseite mit Kacheln (Einsätze, Disposition, etc.) wird angezeigt. Falls nicht → Login ist fehlgeschlagen, User informieren und abbrechen.

## Schritt 4: Ralph-Loop (max 5 Runden)

Pro Runde `N = 1..5`:

**4a — Analyse.** Aktuellen Snapshot + Designziel gegenüberstellen. Entscheiden, welche Dateien zu ändern sind:

| Bereich        | Typische Pfade               |
| -------------- | ---------------------------- |
| HTML-Templates | `templates/**/*.html`        |
| SCSS / CSS     | `development/scss/**/*.scss` |
| JS             | `public/js/**/*.js`          |
| Delphi Backend | `*.pas`, `*.dproj`, `*.dfm`  |

**4b — Edit + WIP-Commit.**

```bash
# Änderungen mit Edit/Write umsetzen
git commit -am "wip: design-loop round N"
```

**4c — Transport wählen.** Anhand der geänderten Dateitypen:

```bash
# Nur templates/ | public/ | development/scss/ → deploy (schnell, kein Service-Bounce)
edp <projekt> deploy

# .pas, .dproj, .dfm mit dabei → compile (pusht Branch, MSBuild, Service-Restart)
edp <projekt> compile
```

**4d — Re-Check im Browser.** Gleiche Session weiterverwenden. Cache-Buster anhängen, weil edpweb statische Assets aggressiv cached:

```bash
TS=$(date +%s)
playwright-cli -s=edpdesign goto "https://${EDP_VM_HOST:-172.16.0.2}/<relevante-seite>?v=$TS"
playwright-cli -s=edpdesign snapshot --filename=round-N.yml
playwright-cli -s=edpdesign screenshot --filename=round-N.png
```

**4e — Urteil.** Screenshot und DOM-Snapshot gegen das Designziel prüfen. Drei Kategorien:

- **Fertig** — Ziel erreicht → Loop verlassen, weiter zu Schritt 5.
- **Nächster Schritt klar** — kurz notieren, was noch fehlt, und Runde `N+1` starten.
- **Festgefahren** — Zwei Runden in Folge ohne sichtbare Verbesserung **oder** Hard-Cap von 5 Runden erreicht → Loop abbrechen und in Schritt 5 User fragen.

## Schritt 5: Ergebnis präsentieren

Dem User zeigen:

- Baseline-Screenshot (`baseline.png`) und finalen Screenshot (`round-<N>.png`) nebeneinander.
- Liste der geänderten Dateien (`git diff --stat main...HEAD`).
- Liste der WIP-Commits (`git log --oneline main..HEAD`).
- Kurze textuelle Bewertung: was wurde erreicht, was blieb offen.

Dann eine Entscheidung einholen:

Optionen:

- **Passt — WIP-Commits squashen** (Hinweis: User führt `git rebase -i` selbst aus; Skill committet nicht automatisch).
- **Weiter iterieren** (neues Ziel oder Feinjustierung als Freitext; optional Runden-Limit erhöhen).
- **Verwerfen** (`git reset --hard <startpunkt>` — nur nach expliziter Bestätigung).

## Schritt 6: Cleanup

```bash
playwright-cli -s=edpdesign close
```

Screenshots und Snapshots bleiben unter `.playwright-cli/` im Projekt liegen (für spätere Referenz). Kein Auto-Delete.

## Regeln

- **Nie auf `main` committen.** Vor Schritt 1 prüfen und ggf. abbrechen.
- **Nur WIP-Commits.** Squash/Amend bleibt User-Hoheit.
- **Keine manuellen `git push`.** Implizite Pushes durch `edp compile` auf dem Feature-Branch sind OK.
- **Hard-Cap 5 Runden.** Danach fragt der Skill den User, ob weiter iteriert werden soll.
- **2× keine Verbesserung** → abbrechen und User fragen.
- **Nur relative Pfade** für `screenshot`, `state-save`, `snapshot --filename=...` (absoluter Pfad außerhalb des Projekt-Roots wird von `playwright-cli` blockiert).
- **Transport-Ökonomie**: Template-/SCSS-/JS-only → `deploy` (Sekunden). `.pas`/`.dproj`/`.dfm` → `compile` (Minuten).
- **Deutsche User-Kommunikation** mit echten Umlauten, kein AI-Hinweis.

Abschließend `skill-optimize` mit `edp-design-loop` aufrufen.

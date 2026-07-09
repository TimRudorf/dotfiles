---
name: edp-design-loop
description: >-
  Diesen Skill verwenden, wenn der User eine UI-/Design-Änderung an einem EDP-Web-Projekt (meist edpweb) in einer autonomen Ralph-Loop umsetzen lassen will. Die Schleife ändert Code → deployed oder kompiliert auf die Dev-VM → prüft das Ergebnis per Browser-Login + Screenshot → iteriert selbstständig, bis das Modell mit dem Ergebnis zufrieden ist oder der Hard-Cap erreicht ist. Trigger-Keywords: "design loop", "ralph loop", "iteriere bis es passt", "design-loop", "/edp-design-loop".
argument-hint: "[projekt] design-ziel"
---

# EDP Design-Loop (Ralph-Loop)

Autonome Iterations-Schleife für UI-/Design-Änderungen an EDP-Web-Projekten. Ändert Code, kompiliert via `edp-ctrl dev compile`, verifiziert das Ergebnis per `playwright-cli` und iteriert eigenständig.

## Voraussetzungen

- Env: `EDP_VM_HOST`, `EDP_PROJECT_ROOT` (exportiert in Tims `~/.zshrc` — in non-interactive bash leer; bei `requirement-checker`-Lauf ggf. mit `zsh -i -c 'echo $VAR'` gegenchecken oder Fallback `eifert-dev`/`172.16.0.2` für `EDP_VM_HOST` nutzen)
- Tools: `ssh`, `playwright-cli`, `edp-ctrl`, `git`
- Projekt: `$EDP_PROJECT_ROOT/<projekt>` (Git-Repo, sauber oder mit ungestagten Änderungen — siehe Schritt 1)

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

- **macOS-Junk vorab filtern:** Wenn `.DS_Store` (oder `Thumbs.db`) im untracked-Status steht, **nicht** mit `git add -A` mitcommitten. Vor dem WIP-Commit `rm -f .DS_Store` (das File ist nirgends gewollt) — falls es schon getrackt war, separat mit `git rm --cached` und `.gitignore`-Eintrag bereinigen.
- Arbeitsbereich dirty (nach Junk-Filter) → drei Optionen anbieten (Default 1, wenn die Änderungen offenbar zum Designziel gehören):
  1. **WIP-Commit jetzt** auf aktuellem Branch — Änderungen gezielt staging mit `git add <pfade>` oder `git add -A -- ':!*.DS_Store'`, dann `git commit -m "wip: design-loop start"`.
  2. **Stash + restore am Ende** (`git stash push -m "design-loop"`).
  3. **Abbrechen** und User die Änderungen vorher klären lassen.
- Branch = `main` → User informieren und abbrechen (oder nach Schritt 4 des Kommunikationswegs einen neuen Feature-Branch vorschlagen).

## Schritt 2: Playwright-Config + VM-IP auflösen

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

`playwright-cli` macht eigene DNS-Resolution — SSH-Aliase aus `~/.ssh/config` werden **nicht** aufgelöst. `EDP_VM_HOST` kann ein Alias (`vm-eifert-develop`) oder eine IP sein. Einmal vorab die IP ermitteln:

```bash
VM_IP=$(ssh -G "${EDP_VM_HOST:-vm-eifert-develop}" 2>/dev/null | awk '/^hostname /{print $2}')
VM_IP="${VM_IP:-172.16.0.2}"
```

`$VM_IP` wird in allen Playwright-URLs unten verwendet.

## Schritt 3: Baseline-Login + Screenshot

Arbeitsverzeichnis bleibt im Projekt-Root — `playwright-cli` erlaubt Datei-Zugriff **nur** innerhalb des Projekt-Roots und dessen `.playwright-cli/` Unterordners. Pfade wie `/tmp/...` schlagen mit `outside allowed roots` fehl.

```bash
playwright-cli -s=edpdesign open --browser=chromium \
  --config=.playwright/cli.config.json \
  "https://$VM_IP/"
playwright-cli -s=edpdesign snapshot
```

Aus dem Snapshot die `refs` für Benutzername-Textbox, Passwort-Textbox, Funktion-Combobox und Anmelden-Button übernehmen, dann einloggen:

```bash
playwright-cli -s=edpdesign fill   <benutzer-ref> "${EDP_DESIGN_USER:-demo}"
playwright-cli -s=edpdesign fill   <passwort-ref> "${EDP_DESIGN_PASS:-demo}"
playwright-cli -s=edpdesign select <funktion-ref> "${EDP_DESIGN_FUNKTION:-EL}"
playwright-cli -s=edpdesign click  <anmelden-ref>
playwright-cli -s=edpdesign snapshot   --filename=.playwright-cli/baseline.yml
playwright-cli -s=edpdesign screenshot --filename=.playwright-cli/baseline.png
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

**4c — Deploy via `edp-ctrl dev compile`.** Das ist der einzige Transport (Git-Push + SCSS-Build + MSBuild + Service-Restart; bei Template-/SCSS-/JS-only-Änderungen bleibt MSBuild effektiv ein No-Op). Details siehe `/edp-develop`.

```bash
edp-ctrl dev compile <projekt>
```

**Hinweis:** `edp-ctrl dev compile` startet den Delphi-Service neu — die Browser-Session geht dabei verloren. In 4d steht ggf. wieder der Login-Screen an. Dann vor dem Re-Check einmal per `snapshot` die neuen refs holen und identisch zu Schritt 3 einloggen, bevor mit der Cache-Buster-URL die Zielseite aufgerufen wird.

**4d — Re-Check im Browser.**

Vor dem Re-Check entscheiden, ob Browser-Session neu gestartet werden muss:

- **Reine JS/CSS/Template-Änderungen ohne Pascal-Diff** → Browser-Session **immer neu starten**. Der `?v={VERSION}`-Cache-Buster der `<script>`/`<link>`-Tags ist Delphi-exe-versionsgebunden und ändert sich bei reinen Frontend-Edits **nicht** — eine URL-Cache-Buster-Query (`?v=$TS`) hilft nur für die HTML-Seite selbst, nicht für die referenzierten Assets. Ohne Restart sieht der nächste Screenshot zwangsläufig den alten Stand und die Runde ist verschwendet.
- **Pascal-Änderung mit dabei** → `edp-ctrl dev compile` bumpt die Version, `<script>`-Tags bekommen neue URLs, normaler Reload reicht. Direkt mit `goto` fortfahren.

Browser-Restart-Pattern (bei reinen Frontend-Edits vor dem Re-Check ausführen):

```bash
playwright-cli -s=edpdesign close
playwright-cli -s=edpdesign open --browser=chromium \
  --config=.playwright/cli.config.json "https://$VM_IP/"
# danach erneut einloggen (Schritt 3) und zur Zielseite navigieren
```

Re-Check:

```bash
TS=$(date +%s)
playwright-cli -s=edpdesign goto "https://$VM_IP/<relevante-seite>?v=$TS"
playwright-cli -s=edpdesign snapshot   --filename=.playwright-cli/round-$N.yml
playwright-cli -s=edpdesign screenshot --filename=.playwright-cli/round-$N.png
```

**Server-Side-Verifikation (optional, bei Verdacht).** Wenn das neue Verhalten trotz Restart ausbleibt, prüfen ob die Datei überhaupt auf der VM angekommen ist:

```bash
playwright-cli -s=edpdesign eval "async () => {
  const r = await fetch('/public/js/<pfad>/<datei>.js?v=' + Date.now(), { cache: 'no-store' });
  return (await r.text()).includes('<marker-aus-deiner-änderung>');
}"
```

**4e — Urteil.** Screenshot und DOM-Snapshot gegen das Designziel prüfen. Drei Kategorien:

- **Fertig** — Ziel erreicht → Loop verlassen, weiter zu Schritt 5.
- **Nächster Schritt klar** — kurz notieren, was noch fehlt, und Runde `N+1` starten.
- **Festgefahren** — Zwei Runden in Folge ohne sichtbare Verbesserung **oder** Hard-Cap von 5 Runden erreicht → Loop abbrechen und in Schritt 5 User fragen.

## Verifikations-Helfer

Zusätzlich zu `snapshot` und `screenshot` nützlich, wenn Screenshots nicht reichen:

- **Backend/API direkt testen** via `playwright-cli eval` (nicht `evaluate`!) — nutzt die laufende Browser-Session inkl. Cookies, liefert den echten Backend-Response.

  Der Return-Wert steht im Output-Block unter `### Result`. Für kompakte Ausgabe `| grep -A2 'Result'` anhängen — sonst geht der Wert zwischen Code-Echo, Page-URL und Snapshot-Pfad unter:

  ```bash
  playwright-cli -s=edpdesign eval "async () => {
    const r = await fetch('/action/...', { method: 'POST', credentials: 'same-origin',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: new URLSearchParams({...}) });
    return JSON.stringify({ status: r.status, text: (await r.text()).slice(0, 500) });
  }" | grep -A2 'Result'
  ```

  Unverzichtbar, wenn ein UI-Klick keinen sichtbaren Effekt zeigt und man wissen muss, ob der Fehler im Backend, in der Auth oder in der UI-Aktualisierung liegt.

- **DOM-/CSS-Diagnose** via `eval` — wenn ein Element laut Snapshot existiert aber nicht sichtbar ist (Dropdown öffnet sich nicht, Tooltip clipped, z-index-Konflikt), die Render-Kette prüfen statt zu raten:

  ```bash
  playwright-cli -s=edpdesign eval "() => { const el = document.querySelector('<selector>'); let n = el; const chain = []; while (n && n !== document.body) { const cs = getComputedStyle(n); chain.push({ class: n.className, overflow: cs.overflow, position: cs.position, zIndex: cs.zIndex }); n = n.parentElement; } const r = el?.getBoundingClientRect(); return JSON.stringify({ rect: r, chain }); }" | grep -A2 'Result'
  ```

  Typische Fundstellen: `overflow:hidden` auf einem Vorfahren clippt absolute-positionierte Children (Fix oft `popperConfig.strategy:'fixed'` für Bootstrap-Dropdowns), niedriger z-index, transform-Kontext der position-fixed unbeabsichtigt einschränkt.

- **Browser-Errors auslesen** — Playwright schreibt Browser-Konsolen-Events in `.playwright-cli/console-*.log`. Die neueste Datei (per Dateiname-Timestamp erkennbar) enthält den aktuellen Request-Lauf.

## Schritt 5: Ergebnis präsentieren

Dem User zeigen:

- Baseline-Screenshot (`.playwright-cli/baseline.png`) und finalen Screenshot (`.playwright-cli/round-<N>.png`) nebeneinander.
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
- **Keine manuellen `git push`.** Implizite Pushes durch `edp-ctrl dev compile` auf dem Feature-Branch sind OK.
- **Hard-Cap 5 Runden.** Danach fragt der Skill den User, ob weiter iteriert werden soll.
- **2× keine Verbesserung** → abbrechen und User fragen.
- **Screenshots + Snapshots immer nach `.playwright-cli/`** — dieser Ordner ist projektweit gitignored. Nackte Dateinamen (z.B. `--filename=baseline.png`) landen im Projekt-Root und verschmutzen das Working Tree, was den nächsten `edp-ctrl dev compile` blockiert. Absolute Pfade außerhalb des Projekt-Roots werden von `playwright-cli` mit `outside allowed roots` verweigert.
- **Für Inputs `fill` benutzen, nicht `type`** — `type` schreibt Zeichen ohne input-Event auszulösen, Live-Such-Handler und Formulare reagieren nicht. `fill` ist der verlässliche Weg.
- **`eval` statt `evaluate`** — der playwright-cli-Subcommand heißt `eval`; `evaluate` wirft einen Help-Screen-Error.
- **Deutsche User-Kommunikation** mit echten Umlauten, kein AI-Hinweis.

Abschließend `skill-optimize` mit `edp-design-loop` aufrufen.

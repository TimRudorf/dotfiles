---
name: regel-create
description: Legt aus einer formlosen Beschreibung eine neue Verhaltens- oder Arbeitsregel an — am richtigen Ort, mit der richtigen Reichweite (alle Hosts, ein Host, oder nur diese Maschine) und so gebunden, dass sie nur dort auftaucht, wo sie gilt. Nutzen, wenn Tim eine Regel formuliert, festhalten oder ändern will. Trigger - "merk dir als Regel", "ab jetzt soll immer", "das soll generell gelten", "leg dafür eine Regel an", "neue Regel", "Regel ändern", "/regel-create".
argument-hint: [beschreibung der regel]
---

# Regel anlegen

Eine Regel sagt, **wie gearbeitet wird**. Sie ist eine Markdown-Datei unter
`~/.claude/rules/`; Claude Code findet sie dort rekursiv und löst Symlinks auf.

Zwei Achsen entscheiden über den Ort — sie sind unabhängig voneinander:

- **Reichweite:** auf welchen Rechnern gilt sie?
- **Sichtbarkeit:** wann wird sie geladen?

## Die drei Ablageorte

| Reichweite | Pfad | versioniert |
|---|---|---|
| **geteilt** — alle Hosts (Default) | `~/dotfiles/claude/rules/<thema>.md` | ja |
| **host** — nur einer | `~/dotfiles/claude/hosts/<host>/rules/<thema>.md` | ja |
| **lokal** — nur diese Maschine | `~/.claude/rules/local/<thema>.md` | **nein, nie** |

Hosts sind `mac`, `container`, `poseidon`; der aktuelle steht in `$JARVIS_HOST`.
Alle drei Orte sind über `~/.claude/rules/{shared,host,local}` erreichbar.

Schreibe immer über den literalen `$HOME/.claude/...`-Pfad oder über
`~/dotfiles/claude/rules/...`. Pfade, die eine `.claude/`-Komponente **in der
Mitte** haben (etwa `~/dotfiles/claude/.claude/...`), gelten als sensitiv und
werden auch im Bypass-Modus blockiert.

## Schritt 1: Ist es überhaupt eine Regel?

Bevor irgendetwas geschrieben wird — drei Dinge werden leicht verwechselt:

| Es sagt … | Dann ist es | und gehört |
|---|---|---|
| *wie* gearbeitet werden soll | eine **Regel** | hierher |
| *wie etwas funktioniert* / was der Fall ist | **Wissen** | ins Vault (`memory/`, `notes/`) |
| *eine Schrittfolge auf ein Stichwort hin* | ein **Skill** | `skill-create` |

Passt es nicht eindeutig in eine Zeile: fragen, nicht raten. Eine Regel, die
eigentlich Wissen ist, wird nie gelesen; ein Skill, der als Regel abgelegt
wurde, läuft nie los.

## Schritt 2: Reichweite bestimmen

In dieser Reihenfolge prüfen — die erste zutreffende gewinnt:

1. **Lokal**, wenn die Regel diese Maschine nicht verlassen soll: Zugangsdaten,
   private Pfade, alles Persönliche, das nicht in ein Git-Repo gehört.
2. **Host**, wenn sie auf einem anderen Rechner **falsch** wäre — ein Pfad, den
   es dort nicht gibt, ein Werkzeug, das nur hier installiert ist, ein Zugang,
   der nur von hier funktioniert.
3. **Geteilt** — alles andere, und das ist der Normalfall.

Der Unterschied zwischen 2 und 3 ist scharf: Eine Regel, die anderswo bloß
*nicht greift*, ist geteilt. Nur was anderswo **in die Irre führen würde**,
gehört ins Host-Verzeichnis. Im Zweifel geteilt — das ist der Ort, an dem sie
gefunden wird.

## Schritt 3: Sichtbarkeit bestimmen

Das `paths:`-Frontmatter bindet die Regel an Dateien. Sie wird nur geladen,
wenn eine passende Datei im Spiel ist:

```yaml
---
paths:
  - "**/*.ts"
  - "**/edpweb/**/*.scss"
---
```

**Ohne `paths:` wird die Regel in jedem Turn geladen** — auf jedem Host, in
jedem Projekt, unabhängig vom Thema. Das ist teuer und stumpft ab. Also:

- Lässt der Geltungsbereich sich an Dateien festmachen → **immer `paths:`**.
  Glob so eng wie möglich, aber nicht enger als die Regel gilt.
- Lässt er sich das nicht (Kommunikation, Umgang, Sicherheit) → ohne `paths:`,
  dann aber **auf wenige Zeilen** eindampfen.

Merksatz: Ein Glob beschreibt einen *Ort*, kein Thema. „Gilt für TypeScript"
ist ein Glob. „Gilt bei Kundenkontakt" ist keiner — das wird sonst eine
Dauerregel oder besser ein Skill.

Mehrere Regeln dürfen dieselbe Datei treffen; das ist kein Konflikt, solange
sie thematisch verschieden sind.

## Schritt 4: Kollision prüfen

Vor dem Anlegen nachsehen, ob das Thema schon irgendwo liegt:

```bash
ls ~/.claude/rules/shared/ ~/.claude/rules/host/ ~/.claude/rules/local/
grep -Ril "<stichwort>" ~/.claude/rules/ ~/.claude/CLAUDE.md
```

`grep` braucht hier das **große `-R`**: `shared` und `host` sind Symlinks, und
mit kleinem `-r` steigt grep beim Rekursieren nicht in sie hinein. Die Prüfung
meldet dann stumm »nichts gefunden« — und die Dublette, die dieser Schritt
verhindern soll, entsteht genau daraus. Dieselbe Falle wie `find` ohne `-L`
in Schritt 6.

Gibt es bereits eine Regel zum Thema, wird sie **ergänzt statt dupliziert** —
zwei Regeln zur selben Sache widersprechen sich früher oder später, und dann
gilt keine. Widerspricht die neue Regel einer bestehenden: das ansprechen,
nicht still überschreiben.

## Schritt 5: Regel schreiben

Dateiname ist das Thema in kebab-case (`code-kommentare.md`), nicht eine
Nummer. Deutsch, echte Umlaute.

Aufbau, kurz gehalten:

1. **Frontmatter** mit `paths:` — oder gar keins.
2. **Überschrift** = das Thema.
3. **Was gilt** — im Indikativ, nicht als Bitte.
4. **Warum** — eine Regel mit Begründung wird auch im Grenzfall richtig
   angewandt; eine ohne wird beim ersten Sonderfall umgangen.
5. **Woran ein Verstoß erkennbar ist** — ein Gebot ohne Erkennungsmerkmal ist
   Deko. Wo möglich ein knappes Positiv-/Negativ-Beispiel.
6. **Wo die Grenze liegt** — was die Regel ausdrücklich *nicht* verlangt.
   Ohne das wächst sie sich im Zweifel zum Maximalanspruch aus.

Nicht hineinschreiben: den Anlass ihrer Entstehung, die Sitzung, das Datum.
Eine Regel gilt zeitlos oder gar nicht — die Historie steht in Git.

## Schritt 6: Verifizieren

Vier Prüfungen, jede mit Kriterium:

```bash
find -L ~/.claude/rules/ -name '<thema>.md'          # taucht sie auf?
head -8 "$(find -L ~/.claude/rules/ -name '<thema>.md')"   # Frontmatter ab Zeile 1, Globs in ""
grep -c $'\ufffd' <datei>                             # muss 0 sein (kaputte Umlaute)
```

Zwei Fallen stecken in diesen drei Zeilen: `find` **braucht `-L`**, weil
`shared` und `host` Symlinks sind und `find` sonst stumm nichts meldet — Claude
Code selbst löst sie auf. Und `$'\ufffd'` hat **einen** Backslash; mit zweien
sucht `grep` nach dem Text statt nach dem Zeichen und meldet immer 0.
Ein leeres Ergebnis ist hier also erst ein Befund, wenn der Befehl stimmt.

Die vierte ist die wichtigste und wird gern vergessen: **greift der Glob
überhaupt?** Ein Muster, auf das keine reale Datei passt, ergibt eine Regel,
die nie geladen wird und trotzdem gepflegt aussieht. Gegenprobe in einem echten
Repo, in dem sie gelten soll:

```bash
git -C <repo> ls-files | grep -E '<endung>$' | head
```

Kein Treffer → Glob korrigieren, nicht die Regel abhaken.

## Schritt 7: Ausrollen

- **Lokal:** nichts zu tun. Tim darauf hinweisen, dass diese Regel nirgends
  gesichert ist und beim Neuaufsetzen des Rechners verschwindet.
- **Geteilt oder Host:** in `~/dotfiles` committen. Subject
  `rules: <thema>`, eine Body-Zeile zum Zweck.

```bash
git -C ~/dotfiles add claude/rules/<thema>.md
git -C ~/dotfiles commit -F - <<'MSG'
rules: <thema>

<eine Zeile zum Zweck>
MSG
```

Die **Leerzeile** nach dem Subject ist Pflicht: ohne sie liest Git die ganze
Botschaft als eine Subject-Zeile, und `git log --oneline` wird unlesbar.

Der **Push braucht Tims Freigabe** — das Repo hängt auf `main` und die Regel
gilt danach auf allen Rechnern. Nie ungefragt pushen.

Auf den anderen Hosts wird sie mit `git pull` wirksam. `jarvis-link-rules.sh`
ist nur nötig, wenn ein **neues** Host-Verzeichnis entstanden ist — bei
bestehenden zeigt der Symlink bereits aufs Verzeichnis.

## Wann nachgefragt wird

Lieber einmal fragen als am falschen Ort ablegen. Per `AskUserQuestion`, mit
den in Frage kommenden Optionen als Auswahl:

- Die Beschreibung lässt offen, **ob** es Regel, Wissen oder Skill ist.
- Die Reichweite geht aus ihr nicht hervor und es gibt einen Grund gegen
  „geteilt" — etwa ein Pfad oder Werkzeug, das nicht überall existiert.
- Die Globs müssten geraten werden: Welche Sprachen, welche Repos?
- Eine bestehende Regel **widerspricht** der neuen.
- Eine bestehende Regel überschneidet sich und es gibt keinen sauberen Schnitt.
  Den gibt es oft: ein `CLAUDE.md`-Bullet trägt den **Grundsatz** und gilt auch
  dort, wo keine Datei im Spiel ist (Issues, PR-Bodies, Berichte); die
  `paths`-Regel trägt das **Handwerk** für die Dateien. Das ist keine
  Dopplung — dann nicht fragen, sondern die Aufteilung benennen und bauen.
- Die Regel hätte spürbare Reichweite ohne `paths:` — dann vorher zeigen, was
  sie in jedem Turn kosten würde, und nach einer engeren Bindung fragen.

**Nicht** gefragt wird, wenn Tim Ort, Host oder Dateitypen schon selbst genannt
hat, oder wenn die Beschreibung eine Sprache eindeutig benennt.

## Schritt 8: Ergebnis zeigen

Die fertige Regel im Volltext zeigen, dazu in einer Zeile: Ablageort,
Reichweite, wann sie geladen wird — und was noch offen ist (Push-Freigabe).

Abschließend `skill-optimize` mit `regel-create` aufrufen.

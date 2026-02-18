---
name: skill-optimize
description: Analysiert den letzten Skill-Lauf und optimiert die SKILL.md. Wird nach Skill-Ausführungen aufgerufen um Fehler, Workarounds und Verbesserungspotenzial zu erkennen.
user-invocable: false
argument-hint: [skill-name]
---

# Skill-Optimierung

Analysiert die aktuelle Konversation nach einem Skill-Lauf und schlägt konkrete Verbesserungen an der SKILL.md vor.

## Parameter

`$ARGUMENTS` = Skill-Name (z.B. `zammad-read`). Der Pfad wird automatisch abgeleitet:
- User-Scope: `~/.claude/skills/{name}/SKILL.md`
- Projekt-Scope: `.claude/skills/{name}/SKILL.md`

Falls der Skill unter keinem der beiden Pfade gefunden wird: User nach dem Pfad fragen.

## Workflow

### Schritt 1: Konversation analysieren

Den bisherigen Konversationsverlauf nach folgenden Kategorien durchsuchen:

- **Fehlschläge**: Exit-Codes != 0, HTTP-Fehler (4xx, 5xx), wiederholte Befehlsausführungen
- **Workarounds**: User-Korrekturen, manuelle Eingriffe, Abweichungen vom dokumentierten Ablauf
- **Verbesserungspotenzial**: Redundante Schritte, fehlende Fehlerbehandlung, unklare Anweisungen die zu Fehlinterpretationen führten

**Falls nichts gefunden** → Dem User mitteilen: "Keine Optimierungen nötig — der Lauf war reibungslos." und Skill beenden.

### Schritt 2: Aktuelle SKILL.md lesen

Die vollständige Datei einlesen und den Aufbau verstehen:
- Frontmatter (falls vorhanden)
- Abschnittsstruktur und Nummerierung
- Codeblock-Format und Sprache
- Konventionen (deutsche/englische Sprache, Formatierung)

### Schritt 3: Best Practices abgleichen

Lies `~/.claude/skills/.shared/skill-best-practices.md` und prüfe die SKILL.md zusätzlich auf strukturelle Verbesserungen:
- Description-Qualität (Trigger-Keywords, dritte Person, Spezifität)
- Frontmatter-Korrektheit (Bindestriche, nicht Unterstriche)
- Token-Effizienz (Dateigröße, Progressive Disclosure)
- Invocation-Steuerung (disable-model-invocation bei Side-Effects?)

**Nur Verbesserungen vorschlagen die durch den Lauf oder offensichtliche Mängel motiviert sind** — keine spekulativen Optimierungen.

### Schritt 4: Doku recherchieren (bei Bedarf)

**Nur falls** die Analyse auf externe Ursachen hinweist (API-Änderungen, veraltete Syntax, falsche Endpoints):

- Context7 für aktuelle API-Dokumentation konsultieren
- CLI-Hilfe (`--help`) prüfen

Diesen Schritt **überspringen**, wenn die Probleme rein intern sind.

### Schritt 5: Änderungsvorschlag erstellen

Für jede gefundene Verbesserung:

- **Abschnitt** identifizieren (z.B. "Schritt 3: Signatur laden")
- **Vorher**: Relevanter Ausschnitt aus der aktuellen SKILL.md
- **Nachher**: Konkreter Vorschlag mit den Änderungen
- **Begründung**: Welches Problem aus dem Lauf wird damit behoben

Optional: Neue Abschnitte oder Regeln vorschlagen, falls ein ganzer Aspekt fehlt.

### Schritt 6: Testen & bestätigen

**Shell-Befehle testen** (wo möglich):
- Lesende Befehle (API-Abfragen, `--help`, `--version`) direkt ausführen
- Schreibende Befehle nur mit `echo` oder `--dry-run` testen

**Vorschlag präsentieren** per `AskUserQuestion`:

```
Skill-Optimierung: {skill-name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{Für jede Änderung:}

### {Abschnitt}
**Problem**: {Was im Lauf schiefging}
**Änderung**: {Kurzbeschreibung}

Vorher:
> {relevanter Ausschnitt}

Nachher:
> {neuer Text}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Optionen: **"Anwenden"**, **"Anpassen"**, **"Überspringen"**

- **Anwenden** → weiter zu Schritt 7
- **Anpassen** → User nach gewünschten Änderungen fragen, Vorschlag überarbeiten, erneut präsentieren
- **Überspringen** → Skill beenden ohne Änderungen

### Schritt 7: SKILL.md aktualisieren

Die gesamte SKILL.md mit den bestätigten Änderungen schreiben. Danach Kontroll-Lesen der Datei durchführen und dem User bestätigen:

- Welche Abschnitte geändert wurden
- Dass die Datei erfolgreich geschrieben wurde

## Regeln

- **Nur konkrete Probleme** aus dem tatsächlichen Lauf beheben — keine spekulativen oder präventiven Änderungen
- **Bestehende Konventionen beibehalten**: Schritt-Nummerierung, Codeblock-Format, Sprache (deutsch/englisch), Markdown-Struktur
- **Keine rekursive Selbst-Optimierung**: Dieser Skill (skill-optimize) hat keinen Skill-Optimierung-Footer
- **Keine strukturellen Umbauten** ohne konkreten Anlass — wenn der Aufbau funktioniert, bleibt er bestehen
- **Skill-Optimierung-Footer nicht verändern** — der Footer-Abschnitt am Ende anderer Skills wird nicht modifiziert

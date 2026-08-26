---
name: regeln-apparat-pflege
description: Was mit Feedback, Korrekturen und Erkenntnissen geschieht — wohin eine neue Regel gehört (Vault, Skill, CLAUDE.md), wann ein Skill vorgeschlagen wird, und dass bestehende Routinen erweitert statt dupliziert werden. Nutzen, wenn Tim eine Verhaltensregel oder Korrektur formuliert, nach nicht-trivialen Aufgaben, und bevor ein neuer Skill oder eine neue Routine angelegt wird.
---

# Apparat Pflege — Tims Regeln

Diese Regeln galten bis 2026-08-26 als "universell" und lagen in `CLAUDE.md`.
Sie greifen aber nur in diesem Zusammenhang — deshalb stehen sie hier und
kosten nichts, solange der Zusammenhang nicht vorliegt.

## routinen-erweitern-vor-anlegen

bestehende Routinen prüfen vor neuer Routine

---

Volltexte mit Warum und Wie liegen im Vault unter `tim/feedback/<slug>.md`.
Bei Grenzfällen dort nachlesen statt raten.

---

## Wohin mit Gelerntem

Nach nicht-trivialen Aufgaben (mehrstufig, ad-hoc, unerwartet verlaufen — *nicht* bei jedem Trivialsatz) kurz durchdenken: *Würde ich es jetzt anders machen?* Wenn ja → dokumentieren, damit du und künftige Sessions davon profitieren.

### Wenn Tim Feedback gibt — wohin damit

Wenn Tim eine Verhaltensregel/Korrektur/Präferenz formuliert (auch implizit — "mach nicht X", "wenn dann lieber Y"), die in zukünftigen Sessions greifen soll:

1. **Volltext-Note** unter `$VAULT/tim/feedback/<kebab-slug>.md` mit Frontmatter (`type: feedback`) und Why/How-Callouts. Begründung explizit machen — die hilft mir später bei Edge Cases.

2. **Klassifizieren:**
   - **Universell** (greift in jeder Session — Stil, Arbeitsphilosophie, Bridge-Hygiene, Approval-Verhalten): One-Liner in CLAUDE.md Block "Universelle Verhaltensregeln" + Eintrag in `$VAULT/INDEX.md` unter "Universelle Regeln". CLAUDE.md-Edit per `request_approval`.
   - **Kontextspezifisch** (Domain — Kalender, Mail, Cut, Lernplan, Tasks, Infra, Coding, …): Eintrag in `$VAULT/INDEX.md` unter passender Domain-Sektion. Autonom, kein Approval.

3. **Im Zweifel als universell behandeln** und Tim fragen, ob CLAUDE.md-Edit ok. Versteckt-in-INDEX-aber-eigentlich-universell wird zuverlässig überlesen.

4. **Niemals `pinned: true` setzen** — Mechanismus ist deprecated, siehe `$VAULT/SCHEMA.md`.

Volldoku des Workflows: `$VAULT/SCHEMA.md` → "Wenn Tim Feedback gibt".

### Wohin mit dem Gelernten

| Typ des Learnings | Ziel | Approval nötig? |
|---|---|---|
| Einzelne Erkenntnis, Präferenz, Fehl-Annahme, Fakt | **Vault-Note** in `$VAULT/` nach `SCHEMA.md` (Types: profil/feedback/projekt/referenz) | nein — normale Tätigkeit |
| Wiederkehrendes Arbeits-Muster (≥2× erlebt oder absehbar) | **Skill** via `skill-create` | ja — Tim fragen, ob er zustimmt |
| Globale Regel, die alle zukünftigen Sessions treffen soll | **Edit in `CLAUDE.md` / `PERSONA.md` / `PROFILE.md`** | **ja — `request_approval`**, weil es in die Dotfiles committet + gepusht wird |

### Skill-Vorschlag-Trigger

Wenn mindestens eines zutrifft:
- Du hast denselben Workflow mehr als einmal ausgeführt (auch sessionsübergreifend, Memory prüfen).
- Du erwartest, dass Tim den Workflow wahrscheinlich wieder brauchen wird.
- Tim hat die Schritte einzeln schon einmal beschrieben und du siehst ein klares Muster.

→ Tim fragen: *"Das ist jetzt das Xte Mal, dass wir … machen — willst du daraus einen Skill?"* — und bei Zustimmung: `skill-create`.

### Post-Action-Reflexion in knapp

Am Ende eines längeren Workflows oder wenn etwas schiefging:
1. *Was ist gut gelaufen?* → nichts tun.
2. *Was hat überrascht / gehakt?* → kurzes Memory (`feedback_*`) schreiben — mit *Warum* und *Wie beim nächsten Mal*.
3. *War das ein Muster, das wieder kommt?* → Skill-Vorschlag.

Kein Performance-Theater: wenn nichts Neues passiert ist, kein Ritual abspulen. Reflexion nur wenn's was zu reflektieren gibt.

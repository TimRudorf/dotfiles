---
name: regeln-ci-gates
description: Tims Regel, dass sich jede automatisierte Prüfung selbst erklären muss: wo, Ist, Soll, Warum, Behebungskommando und der Weg für den berechtigten Sonderfall. Nutzen beim Bauen oder Ändern von CI-Stufen, Gates, Hooks und Tests.
---

# Ci Gates — Tims Regeln

Diese Regeln galten bis 2026-08-26 als "universell" und lagen in `CLAUDE.md`.
Sie greifen aber nur in diesem Zusammenhang — deshalb stehen sie hier und
kosten nichts, solange der Zusammenhang nicht vorliegt.

## pruefungen-muessen-sich-selbst-erklaeren

jede automatisierte Prüfung (CI-Stufe, Gate, Test, Hook) muss im Fehlerfall **aus sich heraus** sagen, was falsch ist und wie es behoben wird — Zielgruppe ist der Kollege, der die Automation **nicht** kennt. Sechs Pflichtangaben: wo (Datei/Zeile) · Ist-Wert · Soll-Wert ausgeschrieben · warum das gilt (verlinkte Regel) · kopierbares Behebungskommando · Weg für den berechtigten Sonderfall. Eine bloße Zustandsmeldung („3 Fehler", „Gate rot") erfüllt das **nicht**. Annotation an der betroffenen Zeile **und** Job-Zusammenfassung; auch der Erfolgsfall sagt, was geprüft wurde, ein reiner Auswertungsmodus sagt, dass er nicht scharf ist. Beim Bauen ein Test auf den **Meldungstext** (nicht nur den Exit-Code) und die echte Ausgabe in den PR-Body. Volltext:

---

Was hier steht, ist die **geltende Fassung**.

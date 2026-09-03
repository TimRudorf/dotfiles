# Issue-Workflow — gemeinsamer Ablauf-Core

Host-agnostischer Ablauf vom Issue bis zum mergebaren PR. Wird von `edp-issue`
(GHE/Arbeit) und `gh-issue` (github.com/privat) gelesen — **nie direkt aufrufen**.

> **Der Core hält den Ablauf, das Profil hält die Fakten.** Jede Stelle, an der
> sich die Welten unterscheiden, ist unten als Hook `«NAME»` markiert. Der
> aufrufende Skill füllt in seiner `## Profil`-Sektion **jeden** Hook. Fehlt
> einer: nicht raten, sondern abbrechen.

| Hook | Was das Profil festlegt |
|---|---|
| `«HOST»` | Git-Host, `gh -R`-Muster, Host-Eigenheiten |
| `«TICKET»` | vorgelagertes Ticket-System (oder „keins") |
| `«CHECKOUT»` | wo das Repo lokal liegt / wie es beschafft wird |
| `«STATUS-SIGNAL»` | wie „in Arbeit" am Issue signalisiert wird |
| `«BRANCH»` | Branch-Modell und Basis-Branch |
| `«ENCODING»` | Datei-Encoding-Regime |
| `«TESTS»` | Test-Framework + Kommando je Sprache |
| `«VERIFY»` | wo und womit end-to-end verifiziert wird |
| `«PR»` | PR-Erstellung, Labels, Body-Konventionen |
| `«ABSCHLUSS»` | Merge-Policy + Definition of Done |
| `«TABUS»` | harte profil-spezifische Verbote |

## Grundhaltung

- **Autonom bis zum Abschluss.** Nur unterbrechen, wenn ein echter Blocker eine
  Entscheidung braucht oder ein Repro-Schritt nur manuell geht.
- **Qualität vor Tempo.** Erst melden, wenn verifiziert.
- **Nichts annehmen, alles verifizieren** — Repro, Ursache und Wirkung des Fixes.
- Es gelten zusätzlich die universellen Regeln aus `CLAUDE.md`, allen voran
  `urteil-braucht-vollstaendige-messung`, `kopfzahlen-aus-detailliste-nachrechnen`,
  `korrektur-erreicht-alle-traeger`, `tests-dynamisch-erweitern`, `schreib-verify`
  und `programmier-grundsaetze`. Sie werden hier **nicht** wiederholt.

## Schritt 1: Issue + Kontext erfassen

Repo und Nummer aus `$ARGUMENTS` ableiten (URL, `<repo>#<nr>` oder Nummer +
aktuelles Repo) gemäß `«HOST»`. Sobald beides feststeht: `«STATUS-SIGNAL»` setzen.

Allen Verlinkungen folgen, bis der Sachverhalt vollständig ist: Sub-Issues,
verlinkte PRs, externe URLs, Tickets gemäß `«TICKET»`.

🔴 **Ein Issue-Body ist eine Messung von seinem Erstellungstag, kein Ist-Zustand.**
Jede behauptete Fundstelle, jede Zahl, jede Ursache und jeden Referenzwert gegen
den heutigen Stand nachmessen — auch die Vorgaben, die der Melder schon fertig
mitgeliefert hat. Hat sich der Referenzwert bewegt, ist die **ganze** Erhebung zu
wiederholen, nicht nur die Liste abzugleichen. Ergebnis als Kommentar ans Issue,
Kriterium für Kriterium mit Beleg — das ist zugleich das Gerüst des PR-Bodys.

🔴 **Vor jeder Messung durchspielen, wie ein echter TREFFER aussähe.** Eine Sonde,
die bei einem Treffer gar nicht anschlagen könnte, liefert kein „unbedenklich",
sondern gar kein Ergebnis — in Form eines Satzes, der wie eines klingt.

## Schritt 2: Klassifizieren

Bug → Schritt 3. Feature → Schritt 4. Im Zweifel wie einen Bug behandeln.

## Schritt 3 (Bug): Reproduzieren, dann Ursache finden

1. **Repro in der Umgebung aus `«VERIFY»`**, nicht daneben.
2. **Den exakt gemeldeten Pfad** nachstellen, jeden einzeln. Gelieferte Logs
   gegen den tatsächlich getesteten Pfad halten.
3. Geht es nicht allein: kein Blindflug — kurz an Tim eskalieren mit präziser
   Bitte. Das dabei gewonnene Wissen sichern, damit es beim nächsten Mal geht.
4. **Root-Cause**: Code-Pfad vom Trigger bis zum Fehlerpunkt rückwärts verfolgen.
   Die im Issue benannte Stelle ist oft die lauteste, nicht die ursächliche — ist
   der Mechanismus geteilt, gehört der Fix an die Wurzel.

## Schritt 4 (Feature): Detailplanung

Anforderung gegen die bestehende Architektur planen: Integrationspunkte,
Datenmodell, Schnittstellen, Rechte, Edge-Cases. Kein Parallelkonzept.

## Schritt 5: Branch, Umsetzung, Tests

- Checkout gemäß `«CHECKOUT»`, Branch gemäß `«BRANCH»`. Nie auf dem Basis-Branch
  committen.
- Encoding strikt nach `«ENCODING»`, echte Umlaute.
- **Rot vor Grün in zwei Commits**: Commit 1 = Tests (hier rot, im Text als solche
  benannt) **plus** die API-Fläche, die sie zum Übersetzen brauchen. Commit 2 =
  das Verhalten. Der rote Lauf ist die Reproduktion und gehört in den PR-Body.
- Ein Lauf ohne Tests ist **weder grün noch rot**: die gefundene Testanzahl je
  Lauf mitlesen und gegen die Erwartung (Baseline + neue Fälle) rechnen.

## Schritt 6: End-to-End verifizieren

Vor jeder Rückmeldung selbst beweisen, dass der Fix trägt — gegen einen real
laufenden Stand gemäß `«VERIFY»`. **CI-grün genügt nicht.**

- Bug: den Repro aus Schritt 3 erneut fahren, Fehler weg, Nachbarn stichprobenartig ok.
- Feature: Akzeptanzkriterien real durchspielen.

Geht die Verifikation technisch nicht: transparent melden, **nicht** mit einer
schwächeren Ersatzprüfung kaschieren.

## Schritt 7: Wissen sichern, Issue aktuell halten

Neu gewonnenes Wissen gehört ins Auto-Memory (kurz) bzw. nach `notes/` (eigenes
Dokument) — **nicht** in den Skill. Der Skill trägt nur, was er zum Arbeiten
braucht. Fehlende Erkenntnisse (Root-Cause, Branch-Entscheidung) am Issue ergänzen.

**Randfunde auskoppeln statt mitfixen**: eigenes Issue mit Messung und
Akzeptanzkriterien. Vorher den Bestand prüfen — offen **und** geschlossen, Titel
**und** Body, und mit einem Kontrollbegriff, von dem feststeht, dass er treffen
muss. Erst den Vorgang anlegen, dann seine Nummer irgendwo nennen; geratene
Nummern sind auch dann falsch, wenn sie zufällig stimmen.

## Schritt 8: Review, dann PR

🔴 **Das Review läuft vor dem PR, nicht danach.** Zwei Gründe: der PR-Body wird
aus dem fertigen Stand geschrieben, statt nachträglich um Review-Runden ergänzt zu
werden, und jede Fix-Runde nach dem Öffnen kostet einen weiteren CI-Durchgang.

1. **Lokales Review** per `/edp-review` auf den fertig verifizierten Stand: Diff
   `origin/<base>...HEAD`, den Commit-SHA (`git rev-parse HEAD`) wörtlich in den
   Auftrag. Vor Schritt 6 hat es keinen Sinn — was nicht verifiziert ist, ändert
   sich noch.

   Funde selbst verifizieren, dabei die Gegenprobe **anders konstruieren** als die
   Messung, die den Fund erzeugt hat. Auch der vorgeschlagene **Fix** ist eine
   Behauptung und wird gemessen. Ändert die Runde das Verhalten, sind die Belege
   aus Schritt 5 und 6 überholt und neu zu messen — Live-Messung und
   Mutationsprobe eingeschlossen; danach erneut reviewen. Erst wenn eine Runde
   nichts mehr ändert, geht der PR auf.
2. **PR** gemäß `«PR»`, ohne Zwischenbestätigung. `Closes #<nr>` je vollständig
   erledigtem Issue in Body **und** Commit-Botschaft; nach jeder Body-Änderung
   `--json closingIssuesReferences` gegenlesen. Teilbezüge nur als `Ref #<nr>`.

   Der Body beschreibt den **Endstand**. Was das Review geprüft und für gut
   befunden hat, gehört als Prüfstand-Angabe hinein — „gegen `<sha>` geprüft,
   Schwerpunkte: …" samt der Punkte **ohne** Befund; das ist die halbe Ersparnis
   für den menschlichen Reviewer. Der Werdegang gehört nicht hinein: keine
   Fundliste, keine „behoben/verworfen"-Chronik, kein Hinweis auf den Prüfer oder
   den eigenen Apparat.
3. **CI beobachten.** Bei Rot erst die Fehlerstelle holen und belegen, dass der
   Pfad nicht aus diesem Diff stammt — „ist bestimmt flaky" ist keine Messung.
   Das Ergebnis gehört in den PR-Body, nicht weggeschwiegen.
4. **Nachrunden ändern den Body, nicht den Kommentarstrang.** Bewegt sich der Diff
   nach dem Öffnen (CI-Rot, Nachforderung, menschliches Review), das Review auf
   das Delta erneut ansetzen — und die betroffene Body-Stelle **ändern** statt
   einen Nachtrag anzuhängen (`texte.md` → *Bearbeiten, nicht anhängen*).
5. **Loop bis mergebar**: `mergeable MERGEABLE` und `mergeStateStatus CLEAN` als
   Mindestzustand. Danach gilt `«ABSCHLUSS»`.
6. **Report** an Tim: Issue, Ursache bzw. Lösung, Fix-Zusammenfassung,
   Verifikations-Beleg, PR-URL + Status. Kompakt, deutsch, echte Umlaute.

Kein Hinweis auf AI in Issue-, PR- oder Review-Text.

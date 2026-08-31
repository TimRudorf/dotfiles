# Branches nach dem Merge

Ist ein Pull Request gemergt, wird sein Quell-Branch **gelöscht** — lokal und
auf `origin`, im selben Zug wie der Merge. Nicht später, nicht bei Gelegenheit.

```bash
git push origin --delete <branch>
git branch -d <branch>
```

**Warum:** Ein gemergter Branch trägt nichts mehr, was nicht in seinem
Ziel-Branch steht. Er bleibt aber in jeder Branch-Liste, in jeder
Vervollständigung und in jeder Übersicht stehen und verdeckt die Branches, an
denen wirklich gearbeitet wird. Viele Repos haben `delete_branch_on_merge`
ausgeschaltet — dann räumt niemand auf, wenn es hier nicht passiert.

## Nie gelöscht werden geschützte Branches

`dev`, `beta`, `release`, `main`, `master` — die Langlauf-Kanäle. Sie sind
Merge-**Ziele**, nie Quellen; ein Löschversuch dort ist ein Denkfehler, kein
Aufräumen.

## Zwei Prüfungen vor jedem Löschen

Der Branch-Name ist **kein** Beleg dafür, dass der Branch gemergt ist:

```bash
git merge-base --is-ancestor origin/<branch> origin/<ziel>   # Exit 0 = enthalten
gh pr list --state open --json headRefName                   # darf ihn nicht nennen
```

Ist er in keinem Ziel enthalten, bleibt er stehen — auch wenn sein PR
geschlossen wurde. Ein geschlossener PR ohne Merge heißt „verworfen", und
verworfene Arbeit ist manchmal die, die man wiederholen will.

Sitzt ein offener PR auf ihm, bleibt er ebenfalls stehen.

**Verstoß erkennbar an** einem `git push origin --delete`, dem keine
Enthaltensein-Prüfung vorausging — oder an einer Branch-Liste, in der Namen
längst gemergter Vorgänge stehen.

## Wo die Grenze liegt

Diese Regel gilt für Branches, die beim eigenen Merge entstanden sind oder
nachweislich gemergt sind. Sie ist **kein** Auftrag, fremde Branch-Bestände
ungefragt durchzuräumen: mehrere gemergte Branches auf einmal zu löschen, ist
eine eigene Entscheidung und wird vorher abgesprochen.

Lokale Worktrees fasst sie nicht an. Der Remote-Branch kann weg, während der
Worktree stehen bleibt — dessen Aufräumen ist eine getrennte Frage.

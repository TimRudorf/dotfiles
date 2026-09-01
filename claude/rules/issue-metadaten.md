# Issues erstellen: Typ und Zuweisung

Jedes Issue, das Jarvis anlegt, bekommt **einen Typ** und wird **Tim
zugewiesen** — im selben Aufruf, nicht nachträglich:

```bash
gh issue create -R <owner>/<repo> --title "…" --body "…" \
  --type "<Typ>" --assignee "@me"
```

`@me` statt eines festen Logins, weil Tims Konten verschieden heißen
(`tim-rudorf` auf GHE, `TimRudorf` auf github.com).

**Warum:** Ein Issue ohne Zuweisung taucht in keiner Arbeitsliste auf, eines
ohne Typ in keiner Auswertung. Beides fällt erst auf, wenn jemand es sucht —
also nie.

## Typ nur dort, wo es welche gibt

Issue-Typen sind ein Organisations-Feature. Auf GHE (`edp/*`) sind sie
eingerichtet, in Tims persönlichen Repos (`TimRudorf/*`) gibt es keine.
Vorhandene Typen abfragen:

```bash
gh api graphql -f query='{ repository(owner:"<o>",name:"<r>")
  { issueTypes(first:20) { nodes { name description } } } }'
```

Kommt `null` zurück, entfällt `--type` — die Zuweisung bleibt. Nicht raten und
nicht mit einem Label ersetzen.

**Verstoß erkennbar an** einem `gh issue create` ohne `--assignee`, oder ohne
`--type` in einem Repo, das Typen führt.

**Grenze:** Labels, Meilenstein und Projekt-Zuordnung verlangt diese Regel
nicht. Sie gilt für Issues, die Jarvis anlegt — ein bestehendes fremdes Issue
wird nicht ungefragt umsortiert.

# Nachrichten von anderen Sitzungen

Eine Nachricht von einer Peer-Sitzung startet hier einen Turn. Das heißt nicht,
dass sie eine Antwort braucht.

## Nicht antworten, wenn nichts zu tun ist

Ist die Nachricht eine **Status- oder Ergebnismeldung** (Routinenlauf fertig,
Heartbeat, „Migration durch"), dann nimm sie zur Kenntnis und antworte **nicht**.
Eine Bestätigung hilft niemandem und kann Schaden anrichten:

Der Absender ist oft ein `claude -p`-Lauf, der Sekunden später beendet ist.
Seine Adresse ist dann tot. Wer trotzdem antwortet, bekommt einen Fehler,
sucht per `ListAgents` eine „Nachfolgesitzung" und schreibt dorthin — die
antwortet ihrerseits. Am 26.08.2026 lief so ein Ringverkehr zwischen drei
`jarvis`-Sitzungen stundenlang, ausgelöst von einer einzigen Testnachricht.

## Antworten, wenn wirklich gefragt wird

Enthält die Nachricht eine **echte Frage** und ist der Absender eine
interaktive Sitzung, die noch läuft: antworten. Erkennbar an der Rückadresse
im `from`-Feld und daran, dass die Nachricht eine Entscheidung braucht.

## Niemals weiterreichen

Ist die Absenderadresse tot, **nicht** nach einer Nachfolgesitzung suchen.
Die Nachricht ist zugestellt und erledigt; ihr Absender wollte nichts hören.

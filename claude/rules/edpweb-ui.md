---
paths:
  - "**/edpweb/**/*.scss"
  - "**/edpweb/**/*.html"
  - "**/edpweb/**/*.js"
---

# edpweb-Oberflächen

Verbindliche Prinzipien bei jeder UI-Arbeit an edpweb:

- **Modal und Draggable ohne Card-Wrapper** — kein Card-in-Card.
- **Ribbon im ELW-Stil**: einzelne Buttons mit `.active`-Mapping,
  `showConfigurator: false`, einzelne Sub-Filter-Buttons mit `relevantViews`
  statt Radio-Gruppen.
- **Keine Auto-Refresh-Intervalle.**
- **Suche** über `EDPHeaderSearch.registerProvider` (Header-Suche statt
  Ribbon-Slot).
- **Anzeigeoptionen-Panel** mit Sections per `data-relevant-views`.

Das ELW-Modul ist die Referenz. Für Gestaltungsfragen darüber hinaus gilt der
Skill `edp-frontend-design` (Fluent 2 als Vorbild).

Volltext: [[tim/feedback/edpweb-ui-design-prinzipien]]

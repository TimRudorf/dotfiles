---
name: Apple-Health-Pipeline für Jarvis
description: Health Auto Export → Webhook → Jarvis-Endpoint, gekauft + zu bauen 2026-04-27
type: project
originSessionId: 6da8ffce-ed73-4d31-92fe-c648997a3234
---
**Entscheidung 2026-04-27:** Tim kauft **Health Auto Export Premium Lifetime ($24.99 einmalig)** — kein Abo, kein laufender Kosten-Druck.

**Why:** Tim nutzt **Apple Health als zentrale Health-Datenbank** (alle Werte fließen dort zusammen). Renpho-Smartwaage syncht über Renpho-App nach Apple Health. Direkt-Zugriff auf HealthKit ist nur nativen iOS-Apps erlaubt — Self-Build (eigene iOS-App) wäre wochenlanger Aufwand + $99/Jahr Apple Developer. Daher die etablierte App "Health Auto Export" als Brücke.

**Architektur (geplant):**
```
Renpho-Waage ──BLE──► Renpho-App ──► Apple Health
                                          │
                                          ▼
                           Health Auto Export (iOS App, Premium-Tier)
                                          │  HTTP POST JSON
                                          ▼
                       Jarvis-Health-Endpoint (Glashütten-VM, Docker)
                                          │
                                          ▼
                           SQLite oder Nextcloud-CSV (Persistenz)
                                          │
                                          ▼
                           Jarvis-Skills lesen daraus (Coach, Wiege-Auswertung, …)
```

**To-dos (Reihenfolge):**
1. Tim kauft AHE Lifetime im App Store ($24.99) ✅ committed
2. Jarvis-Endpoint bauen — Vorschlag: neuer Compose-Stack `jarvis-health/` mit FastAPI-Service
   - POST-Endpoint mit API-Key-Auth (Header `X-API-Key`)
   - Daten in SQLite o. Postgres + ggf. Spiegelung in Nextcloud-CSV
   - Public erreichbar via SWAG-VPS (Subdomain z.B. `health.timrudorf.de`)
3. AHE in iOS konfigurieren: Webhook-URL + API-Key, Auto-Export-Schedule, gewünschte Metriken
4. Erste Wiege-Test Sa 02.05.2026 — verifizieren dass Renpho → Health → Jarvis durchläuft
5. Auswertungs-Skill für wöchentliche Wiege-Reviews bauen (separat)

**How to apply:**
- Bei "wie greife ich auf Tims Health-Daten zu" → Jarvis-Health-Endpoint, nicht direkt Apple/Renpho.
- Pipeline-Daten sind **nicht limitiert auf Gewicht** — AHE kann 150+ Metriken (Schritte, Schlaf, HRV, Workouts, Calories Active, …). Cut-Coach ist erste Anwendung; spätere Skills können davon profitieren.
- Caveat AHE: läuft nur wenn iPhone entsperrt — für wöchentliches Wiegen Sa morgens unkritisch, ggf. relevant wenn man "real-time" denkt.

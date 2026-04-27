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

**Status (2026-04-27):** Endpoint deployed + public erreichbar. Wartet nur noch auf iOS-App-Konfiguration durch Tim.

**To-dos:**
1. ✅ AHE Lifetime im App Store gekauft
2. ✅ Endpoint gebaut: `data-api`-Stack auf Glashütten-VM (`/opt/stacks/data-api/`)
   - generischer Service (nicht jarvis-spezifisch), POST/GET pro Source mit X-API-Key
   - SQLite-Persistenz unter `/opt/data/data-api/state/`
3. ✅ Public-Reverse-Proxy: `https://data.timrudorf.de` via SWAG (Conf in `/opt/swag/config/nginx/proxy-confs/data.subdomain.conf` auf VPS, `client_max_body_size 50m` für Health-Payloads)
4. ⏳ Tim konfiguriert AHE-App im iPhone: URL `https://data.timrudorf.de/v1/sources/health/events`, Header `X-API-Key`, Daily/Hourly-Schedule, mindestens Weight/Body-Fat/Lean-Mass Metriken
5. Erste Wiege-Test Sa 02.05.2026 — verifizieren Renpho → Health → AHE → data-api
6. Auswertungs-Skill für wöchentliche Wiege-Reviews bauen (separat, liest `GET /v1/sources/health/events` von Jarvis aus)

**Endpoint-URL für AHE-App:** `https://data.timrudorf.de/v1/sources/health/events`

**How to apply:**
- Bei "wie greife ich auf Tims Health-Daten zu" → Jarvis-Health-Endpoint, nicht direkt Apple/Renpho.
- Pipeline-Daten sind **nicht limitiert auf Gewicht** — AHE kann 150+ Metriken (Schritte, Schlaf, HRV, Workouts, Calories Active, …). Cut-Coach ist erste Anwendung; spätere Skills können davon profitieren.
- Caveat AHE: läuft nur wenn iPhone entsperrt — für wöchentliches Wiegen Sa morgens unkritisch, ggf. relevant wenn man "real-time" denkt.

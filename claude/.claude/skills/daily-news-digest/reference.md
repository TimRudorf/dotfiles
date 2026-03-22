# Daily News Digest — Referenz

## RSS-Feeds (21 Feeds, 7 Kategorien)

### Nachrichten (Limit: 6)
| Feed | URL | Weight |
|------|-----|--------|
| Sueddeutsche | https://rss.sueddeutsche.de/rss/Alles | 1.0 |
| n-tv | https://www.n-tv.de/politik/rss | 0.75 |
| Tagesschau | https://www.tagesschau.de/xml/rss2 | 1.0 |

### Politik (Limit: 6)
| Feed | URL | Weight |
|------|-----|--------|
| Tagesschau Politik | https://www.tagesschau.de/inland/innenpolitik/index~rss2.xml | 1.0 |
| Stern Politik | https://www.stern.de/feed/standard/politik/ | 0.8 |
| Sueddeutsche Politik | https://rss.sueddeutsche.de/rss/Politik | 1.0 |

### Wirtschaft (Limit: 5)
| Feed | URL | Weight |
|------|-----|--------|
| Handelsblatt | https://www.handelsblatt.com/contentexport/feed/finanzen | 0.9 |
| Manager Magazin | https://www.manager-magazin.de/news/index.rss | 0.9 |
| Die Zeit Wirtschaft | https://newsfeed.zeit.de/wirtschaft/index | 1.0 |

### Technik (Limit: 4)
| Feed | URL | Weight |
|------|-----|--------|
| All-AI | https://www.all-ai.de/component/jmap/sitemap/rss?format=rss | 0.8 |
| Ars Technica | https://feeds.arstechnica.com/arstechnica/index | 0.9 |
| TechCrunch | https://techcrunch.com/feed | 0.9 |
| The Verge | https://www.theverge.com/rss/index.xml | 0.9 |

### Sport (Limit: 3)
| Feed | URL | Weight |
|------|-----|--------|
| Sportbild | https://sportbild.bild.de/feed/sportbild-home.xml | 0.5 |
| Sueddeutsche Sport | https://rss.sueddeutsche.de/rss/Sport | 1.0 |
| Sportschau | https://www.sportschau.de/index~rss2.xml | 0.9 |

### Gesundheit (Limit: 2)
| Feed | URL | Weight |
|------|-----|--------|
| Tagesschau Gesundheit | https://www.tagesschau.de/wissen/gesundheit/index~rss2.xml | 1.0 |
| Bundestag Gesundheit | https://www.bundestag.de/static/appdata/includes/rss/gesundheit.rss | 0.75 |
| Aerztezeitung | https://www.aerztezeitung.de/News.rss | 0.75 |

### Unterhaltung (Limit: 2)
| Feed | URL | Weight |
|------|-----|--------|
| Kino.de | https://www.kino.de/rss/movienews | 0.6 |
| Sneak Kino | https://www.sneak-kino.de/feed/ | 0.6 |

## Scoring-Algorithmus

```
score = recencyScore * sourceWeight * lengthScore * titlePenalty
```

### Recency Score (48h Fenster)
```
recencyScore(pubDate) = max(0, (48 - ageHours) / 48)
Kein pubDate: 0.2
```

### Source Weight
Domain-basiert, siehe Tabelle oben. Default (unbekannt): 0.75

### Length Score
```
lengthScore(charCount) = min(1.5, sqrt(charCount / 2000))
```

### Title Penalty (Anti-Clickbait)
```
0.6 wenn Titel enthaelt: live, ticker, podcast, video, fotostrecke, breaking, kommentar
Sonst: 1.0
```

## Deduplizierung

Vor dem Scoring: Titel-Similarity pruefen (Levenshtein-Ratio > 0.8 = Duplikat).
Bei Duplikaten: Artikel mit hoechstem sourceWeight behalten, Quellen merken.

## FiveFilters

Base-URL: `http://fivefilters-full-text-rss/makefulltextfeed.php`

Parameter:
```
?url=ENCODED_FEED_URL&format=json&max=10&links=footnotes&exc=1&accept=feed
```

Response-Struktur: `rss.channel.item[]` mit `title`, `link`, `description`, `pubDate`

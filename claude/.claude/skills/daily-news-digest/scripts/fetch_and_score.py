#!/usr/bin/env python3
"""
Fetch RSS feeds via FiveFilters, score and deduplicate articles.
Outputs JSON to stdout.
"""
import json
import math
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from html import unescape
import re

FF_BASE = os.environ.get("FIVEFILTERS_URL", "http://fivefilters-full-text-rss/makefulltextfeed.php")

FEEDS = {
    "Nachrichten": {
        "limit": 6,
        "feeds": [
            ("https://rss.sueddeutsche.de/rss/Alles", 1.0),
            ("https://www.n-tv.de/politik/rss", 0.75),
            ("https://www.tagesschau.de/xml/rss2", 1.0),
        ]
    },
    "Politik": {
        "limit": 6,
        "feeds": [
            ("https://www.tagesschau.de/inland/innenpolitik/index~rss2.xml", 1.0),
            ("https://www.stern.de/feed/standard/politik/", 0.8),
            ("https://rss.sueddeutsche.de/rss/Politik", 1.0),
        ]
    },
    "Wirtschaft": {
        "limit": 5,
        "feeds": [
            ("https://www.handelsblatt.com/contentexport/feed/finanzen", 0.9),
            ("https://www.manager-magazin.de/news/index.rss", 0.9),
            ("https://newsfeed.zeit.de/wirtschaft/index", 1.0),
        ]
    },
    "Technik": {
        "limit": 4,
        "feeds": [
            ("https://www.all-ai.de/component/jmap/sitemap/rss?format=rss", 0.8),
            ("https://feeds.arstechnica.com/arstechnica/index", 0.9),
            ("https://techcrunch.com/feed", 0.9),
            ("https://www.theverge.com/rss/index.xml", 0.9),
        ]
    },
    "Sport": {
        "limit": 3,
        "feeds": [
            ("https://sportbild.bild.de/feed/sportbild-home.xml", 0.5),
            ("https://rss.sueddeutsche.de/rss/Sport", 1.0),
            ("https://www.sportschau.de/index~rss2.xml", 0.9),
        ]
    },
    "Gesundheit": {
        "limit": 2,
        "feeds": [
            ("https://www.tagesschau.de/wissen/gesundheit/index~rss2.xml", 1.0),
            ("https://www.bundestag.de/static/appdata/includes/rss/gesundheit.rss", 0.75),
            ("https://www.aerztezeitung.de/News.rss", 0.75),
        ]
    },
    "Unterhaltung": {
        "limit": 2,
        "feeds": [
            ("https://www.kino.de/rss/movienews", 0.6),
            ("https://www.sneak-kino.de/feed/", 0.6),
        ]
    },
}

SOURCE_WEIGHTS = {
    "tagesschau": 1.0, "sueddeutsche": 1.0, "zeit": 1.0, "spiegel": 1.0,
    "handelsblatt": 0.9, "manager-magazin": 0.9, "sportschau": 0.9,
    "arstechnica": 0.9, "techcrunch": 0.9, "theverge": 0.9,
    "stern": 0.8, "all-ai": 0.8,
    "chip": 0.7,
    "kino": 0.6, "sneak": 0.6,
    "sportbild": 0.5,
}

TITLE_PENALTY_WORDS = {"live", "ticker", "podcast", "video", "fotostrecke", "breaking", "kommentar"}


def strip_html(html_text):
    """Remove HTML tags and decode entities."""
    text = re.sub(r'<script[^>]*>.*?</script>', '', html_text, flags=re.S)
    text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.S)
    text = re.sub(r'<[^>]+>', ' ', text)
    text = unescape(text)
    return re.sub(r'\s+', ' ', text).strip()


def get_source_weight(url):
    """Get source weight based on domain."""
    for key, weight in SOURCE_WEIGHTS.items():
        if key in url.lower():
            return weight
    return 0.75


def recency_score(pub_date_str):
    """Score based on article age (48h window)."""
    if not pub_date_str:
        return 0.2
    try:
        from email.utils import parsedate_to_datetime
        pub_date = parsedate_to_datetime(pub_date_str)
        if pub_date.tzinfo is None:
            pub_date = pub_date.replace(tzinfo=timezone.utc)
        age_hours = (datetime.now(timezone.utc) - pub_date).total_seconds() / 3600
        return max(0, (48 - age_hours) / 48)
    except Exception:
        return 0.2


def length_score(char_count):
    """Score based on article length."""
    return min(1.5, math.sqrt(char_count / 2000))


def title_penalty(title):
    """Penalize clickbait-style titles."""
    title_lower = title.lower()
    for word in TITLE_PENALTY_WORDS:
        if word in title_lower:
            return 0.6
    return 1.0


def levenshtein_ratio(s1, s2):
    """Simple Levenshtein similarity ratio."""
    if not s1 or not s2:
        return 0.0
    len1, len2 = len(s1), len(s2)
    if len1 > len2:
        s1, s2 = s2, s1
        len1, len2 = len2, len1
    prev = list(range(len1 + 1))
    for j in range(1, len2 + 1):
        curr = [j] + [0] * len1
        for i in range(1, len1 + 1):
            cost = 0 if s1[i-1] == s2[j-1] else 1
            curr[i] = min(curr[i-1] + 1, prev[i] + 1, prev[i-1] + cost)
        prev = curr
    distance = prev[len1]
    max_len = max(len1, len2)
    return 1.0 - (distance / max_len) if max_len > 0 else 1.0


def fetch_feed(feed_url):
    """Fetch a single feed via FiveFilters, return list of articles."""
    ff_url = f"{FF_BASE}?url={urllib.parse.quote(feed_url)}&format=json&max=10&links=footnotes&exc=1&accept=feed"
    try:
        req = urllib.request.Request(ff_url, headers={"User-Agent": "DailyDigest/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"  WARN: Feed fehlgeschlagen: {feed_url} — {e}", file=sys.stderr)
        return []

    items = data.get("rss", {}).get("channel", {}).get("item", [])
    if isinstance(items, dict):
        items = [items]
    return items


def main():
    now = datetime.now(timezone.utc)
    today = now.strftime("%Y-%m-%d")
    all_articles = []
    total_fetched = 0

    for category, config in FEEDS.items():
        category_articles = []
        for feed_url, default_weight in config["feeds"]:
            print(f"Fetching {category}: {feed_url[:60]}...", file=sys.stderr)
            items = fetch_feed(feed_url)
            total_fetched += len(items)

            for item in items:
                title = item.get("title", "").strip()
                if not title:
                    continue
                description = item.get("description", "")
                text = strip_html(description)[:3000]  # Limit to 3000 chars
                char_count = len(text)
                if char_count < 100:
                    continue

                link = item.get("link", "")
                pub_date = item.get("pubDate", "")
                weight = get_source_weight(link) if link else default_weight

                score = (
                    recency_score(pub_date)
                    * weight
                    * length_score(char_count)
                    * title_penalty(title)
                )

                category_articles.append({
                    "title": title,
                    "source": urllib.parse.urlparse(link).netloc.replace("www.", "") if link else "unbekannt",
                    "category": category,
                    "text": text,
                    "url": link,
                    "pubDate": pub_date,
                    "score": round(score, 4),
                })

        # Sort by score, take top N
        category_articles.sort(key=lambda a: a["score"], reverse=True)
        all_articles.extend(category_articles[:config["limit"]])

    # Deduplicate by title similarity
    dedup_count = 0
    deduplicated = []
    for article in all_articles:
        is_dup = False
        for existing in deduplicated:
            if levenshtein_ratio(article["title"].lower(), existing["title"].lower()) > 0.8:
                is_dup = True
                dedup_count += 1
                # Keep higher-scored version, merge sources
                if article["score"] > existing["score"]:
                    existing["title"] = article["title"]
                    existing["text"] = article["text"]
                    existing["score"] = article["score"]
                if article["source"] not in existing.get("additional_sources", []):
                    existing.setdefault("additional_sources", []).append(article["source"])
                break
        if not is_dup:
            deduplicated.append(article)

    # Sort final list by score
    deduplicated.sort(key=lambda a: a["score"], reverse=True)

    result = {
        "date": today,
        "articles": deduplicated,
        "stats": {
            "fetched": total_fetched,
            "scored": len(all_articles),
            "deduplicated": dedup_count,
            "final": len(deduplicated),
        }
    }

    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()

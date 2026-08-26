---
name: regeln-git-arbeit
description: Tims Git-Regeln: Autor in Arbeits-Repos nie überschreiben, Änderungen selbst committen und pushen, Repos sauber hinterlassen, in privaten Repos den kompletten Roundtrip bis zum Merge selbst fahren. Nutzen bei jedem Commit, Push, Branch oder Repo-Aufräumen.
---

# Git Arbeit — Tims Regeln

Diese Regeln galten bis 2026-08-26 als "universell" und lagen in `CLAUDE.md`.
Sie greifen aber nur in diesem Zusammenhang — deshalb stehen sie hier und
kosten nichts, solange der Zusammenhang nicht vorliegt.

## git-author-arbeit-repos

**niemals** `-c user.name`/`-c user.email` an `git commit` übergeben und **nie** eine Mailadresse aus dem Gedächtnis konstruieren: die Repo-Config ist die Quelle. In EDP-Repos ist der Author `Tim Rudorf <tim.rudorf@einsatzleitsoftware.de>`. Eine falsche Adresse macht den Commit auf GHE **keinem Benutzer zuweisbar** (`.author.login = null`) und ist nach dem Merge in geschützte Branches nicht mehr reparabel. Vor jedem Push: `git config user.email` + `git log -1 --format='%ae'` prüfen. Volltext:

## git-changes-selbst-pushen

jede Repo-Änderung selbst committen+pushen (Vault via Hook, andere Repos manuell), Tim kommt nicht in den Container

## repos-immer-clean

kein unstaged/untracked File darf im `jarvis-wiki`, `dotfiles`, `docker-compose` (Mac + VM-Klon) liegen bleiben. Vault auto-syncs (Edit + Bash via Hooks); für `dotfiles` + `docker-compose` jeden Touch im selben Turn als Branch+PR (private-repos-auto-roundtrip) oder `.gitignore`-Eintrag abschließen. Stop-Hook `jarvis-repo-clean-check.sh` warnt vor Session-Ende falls was übrig. Volltext:

## private-repos-auto-roundtrip

bei Privat-Repos (`TimRudorf/dotfiles`, `TimRudorf/jarvis-wiki`, …) kompletter Roundtrip selbstständig: Branch von `origin/main` → Commit → Push → PR → `gh pr merge --squash --delete-branch` → lokales Cleanup. Kein Approval, kein Tim-Mergen. Globale Identity `Tim Rudorf <tim@rudorf.me>` (Arbeit-Repos via `includeIf` überschrieben). Volltext:

---

Was hier steht, ist die **geltende Fassung**.

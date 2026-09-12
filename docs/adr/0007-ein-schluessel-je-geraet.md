# ADR 0007 — Ein Schlüssel je Gerät

**Datum:** 12.09.2026 · **Status:** angenommen, im Repo umgesetzt; Ausrollen mit `hub-deploy.ps1` durch Bene

## Lage

Seit ADR 0006 liegt der Geräte-Schlüssel auch in einer Cloud-Umgebung (Gerät „wolke“). Bis heute gab
es einen Schlüssel für alle Geräte: ein Leck in der Wolke wäre ein Leck für vishnu-master gewesen, und
ihn neu zu würfeln hätte jedes Gerät angehalten. Madeleines Einwand vom 11.09. (Browser-Schlüssel
trennen) gilt für Geräte genauso, sobald es mehr als eines gibt.

## Entscheidung

`token.php` bekommt eine Liste `geraete` (`name => SHA-256`). Ein Schlüssel daraus ist an seinen Namen
gebunden: `geraet` bei `puls`, `nimm`, `log` und `quelle` bei `stapel`, `spiegel` müssen leer sein oder
zum Schlüssel passen, sonst 403. `hub-deploy.ps1` erzeugt je Gerät aus `JOHN_HUB_GERAETE` einen
Schlüssel (`JOHN_HUB_TOKEN_<NAME>`), setzt den des eigenen Rechners als `JOHN_HUB_TOKEN` und zeigt den
eines fremden Geräts einmal an, damit Bene ihn in dessen Umgebung einträgt. `-GeraetErzeugen <name>`
würfelt einen einzelnen neu, `-NurGeraete` lässt den alten ungebundenen Schlüssel weg.

## Folgen

- Widerruf je Gerät ohne Stillstand der anderen. Ein geleakter Wolken-Schlüssel kann keinen Puls, Stapel
  oder Logeintrag als vishnu-master erzeugen.
- Übergang: der alte Schlüssel (`hash`) bleibt gültig, bis jedes Gerät seinen eigenen hat. Danach
  `hub-deploy.ps1 -NurGeraete`. Das Protokoll (`docs/protokoll.md`) beschreibt beide Zustände.
- `geraet-wolke/rezeption.sh` ändert sich nicht: die Wolke liest weiter `JOHN_HUB_TOKEN`, nur ist es jetzt
  ihr eigener Schlüssel. Ein leeres `geraet` in ihren Anfragen füllt die Rezeption mit dem gebundenen Namen.
- Die Rezeption bleibt dumm: Namen und Hashes, kein Modell, keine Geheimnisse im Klartext (Regel 3).

## Verworfene Möglichkeiten

- **Nur den Wolken-Schlüssel trennen (dritte Klasse).** Löst den Fall heute, nicht das zweite Gerät morgen.
- **Schlüssel im Puls rotieren lassen.** Hübsch, aber ein Zustand mehr, der zwischen Rezeption und Gerät
  passen muss — genau die Halbe-Wahrheit, vor der ADR 0001 warnt.

## Offen

- Gegenprüfung durch Madeleine (wie ADR 0006, `beratung/protokoll.md`).
- `hub-deploy.ps1` wurde ohne PowerShell geschrieben (Cloud-Session ohne `pwsh`). Vor dem ersten Lauf:
  `[Management.Automation.Language.Parser]::ParseFile(...)` laut `CLAUDE.md` Schritt 2.

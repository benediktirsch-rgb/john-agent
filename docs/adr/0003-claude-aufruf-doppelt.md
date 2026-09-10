# ADR 0003 — Der Claude-Aufruf steht zweimal da (bewusste Schuld)

**Datum:** 10.09.2026 · **Status:** angenommen, mit Frist

## Lage

Der Weg zu Claude Code im Kopflos-Modus (Abo statt API) steckt in `john-server.ps1`
(`Find-ClaudeExe`, `Invoke-Prozess`, `Invoke-ClaudeCli`, `Get-Backend`) — in einer Datei von
331 kB, die sich nicht laden lässt, ohne den Server zu starten. `john-board.ps1` kommt an die
Funktionen nur heran, weil es **vom Server** per Dot-Sourcing geladen wird und in ihm läuft.

Der Worker muss aber gerade dann denken können, wenn der Server nicht kann.

## Entscheidung

`geraet/john-auftrag.ps1` bringt seinen eigenen, kompakten Aufruf mit (rund 60 Zeilen: Exe finden,
Prozess starten, `ANTHROPIC_API_KEY` aus der Umgebung nehmen, JSON von stdout lesen, Fehlercodes
`NO_LOGIN`/`NO_CREDIT`/`LIMIT`/`CLI_TIMEOUT` erkennen).

## Warum das hier vertretbar ist

Die Doppelung ist der Preis für Unabhängigkeit — und Unabhängigkeit ist der ganze Zweck des
Workers. Ein gemeinsames Modul hätte den Umbau von `john-server.ps1` bedeutet, mitten in einer
Nacht, in der vier andere Sessions in denselben Dateien arbeiten. Das wäre die schlechtere Wette
gewesen.

## Die Schuld, ausdrücklich

Ändert sich der Aufruf (neue CLI-Flags, anderes Modell, neuer Fehlerfall), muss er an **zwei**
Stellen geändert werden. Vergisst man eine, denkt John an einem Ort noch und am anderen nicht mehr —
und niemand merkt es, weil beide Wege getrennt funktionieren.

**Auflösung:** `john-ki.ps1` (Find-ClaudeExe, Invoke-Prozess, Invoke-ClaudeCli, Get-Backend,
Get-JohnFehler) aus `john-server.ps1` herausziehen, beide Seiten dot-sourcen es. Der richtige
Zeitpunkt ist ein ruhiger Tag ohne parallele Sessions in `flow-compass`, mit einem echten
Vorher/Nachher-Vergleich am laufenden Server. Bis dahin steht in beiden Dateien ein Verweis auf
diese ADR.

## Prüfung, ob die Doppelung auseinandergelaufen ist

`Modell`, `Effort` und die Flag-Liste in `john-auftrag.ps1` gegen `Invoke-ClaudeCli` in
`john-server.ps1` halten. Stand 10.09.2026: `claude-opus-5`, `--effort medium`, `--max-turns 1`,
`--no-session-persistence`, `--strict-mcp-config`, `--setting-sources ""`, `--permission-mode dontAsk`,
`--tools ""`. Werkzeuge (MCP) nutzt der Worker bewusst nicht — ein Takt soll nachdenken, nicht
in Dateien schreiben.

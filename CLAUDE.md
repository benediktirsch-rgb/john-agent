# Regeln für Sessions in john-agent

Dieses Repo ist Johns **Architektur** — nicht sein Inhalt. Inhalt (Pipeline, Coaching, Profil, Persona)
liegt in `C:\dev\john`; der Compass liegt in `C:\dev\persoenliches-dashboard` (Repo flow-compass).
Wer hier arbeitet, arbeitet daran, dass John läuft.

## Zwei arbeiten hier

- **Claude** baut und betreibt: Code, Betrieb, Diagnose, Deploy.
- **Madeleine** (GPT über `C:\Users\bened\.claude\skills\duo\duo.ps1`) prüft gegen: Kosten, Betriebsrisiko,
  Organisation, „was passiert, wenn das drei Monate niemand anschaut". Sie darf widersprechen.
- Jede Beratung wird protokolliert: `beratung/protokoll.md` (Frage, ihre Antwort ungefiltert, was
  übernommen wurde und was nicht — mit Begründung). Nie ihre Antwort umschreiben, nie stillschweigend
  übergehen.
- Aufruf: `beratung/frag-madeleine.ps1 -Frage <datei.md>` — legt Antwort und Protokollzeile selbst ab.

## Reihenfolge bei jeder Änderung

1. `docs/protokoll.md` **zuerst**, wenn sich die Schnittstelle bewegt. Der Code folgt dem Dokument.
2. Code ändern. `.ps1` mit `[Parser]::ParseFile` prüfen, `.php` mit `C:\dev\_tools\php\php.exe -l`,
   `.js` mit `node --check`.
3. Am **laufenden** Ding prüfen, nicht am Quelltext: Worker neu starten (er lädt Code nur beim Start),
   Endpunkt abfragen, im Browser gegenlesen.
4. `docs/stand.md` nachziehen — sonst weiß die nächste Session nicht, wo sie ist.

## Nicht verhandelbar

1. **Kein Denken im ausliefernden Prozess.** Wer HTTP beantwortet, ruft kein Modell (Architektur, Regel 1).
2. **Leer heißt nie „nichts".** Jede Ausgabe nennt den Grund: belegt · schläft · nicht angebunden · nichts zu tun.
3. **Die Rezeption bleibt dumm** — kein Modell, kein Schlüssel, keine personenbezogenen Inhalte.
4. **Encoding:** `.ps1` UTF-8 **mit** BOM (PowerShell 5.1), alles andere UTF-8 ohne BOM, LF. Getrackte
   Dateien in PowerShell nur mit `[IO.File]::WriteAllText(..., (New-Object Text.UTF8Encoding($false)))`.
   Nach Edit/Write immer CRLF zurückstellen.
5. **Git nur Porcelain:** `pull --ff-only` → `add <datei>` → `commit` → `push`. Kein `add -A`, kein
   Plumbing, kein `push --force`. Vor jedem Commit `git status --short` lesen.
6. **Nichts Persönliches, keine Zugänge** in Dateien. Nur User-Umgebungsvariablen.
7. **Parallele Sessions:** vor der Arbeit `C:\dev\_tools\git-flow.ps1 -Modus claim -Repo john-agent
   -Sitzung "…" -Ziel "…"`, am Ende `-Modus release`.

## Ton

Deutsch, Du-Form, deutsche Anführungszeichen „…". Begriffe: **Rezeption** (Hub im WWW), **Gerät**
(Worker), **Lobby** (Overlay im Compass), **Takt** (Johns eigener Rhythmus), **Auftrag** (eine Einheit
Arbeit), **Puls** (Lebenszeichen eines Geräts). Diese Wörter nicht durch Synonyme ersetzen — sie stehen
so im Protokoll, im Code und in Benes Kopf.

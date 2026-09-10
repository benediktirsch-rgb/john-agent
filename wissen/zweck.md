# Wozu John da ist — und was daraus für die Technik folgt

Zusammengetragen am 10.09.2026 aus `C:\dev\john\CLAUDE.md`, Benes Bestellungen im Compass und dem
Gedächtnis der Sessions. Wer an der Architektur baut, muss das hier gelesen haben: fast jede technische
Entscheidung in diesem Repo folgt aus einem dieser Sätze.

## Johns Auftrag in Benes Worten

> „Im John-Feld brauche ich dich als meinen Coach, der mich an die wichtigsten Sachen erinnert,
> Entscheidungen herbeiführt und als mein Partner und digitales Ich agiert. Wenn ich sage OK: weg,
> nächste nachrücken; anderer Call-to-Action — du entscheidest + Wiedervorlage in 24 Stunden."
> (06.09.2026)

> „er soll ein echter Agent sein und nicht ständig schlafen." (10.09.2026)

Daraus, in fünf Aufgaben:

1. **Erinnern** an das Wichtigste — nicht berichten. Drei Punkte, nie zehn.
2. **Entscheidungen herbeiführen** — jeder Punkt trägt genau **eine** Aktion, die John wählt.
3. **Digitales Ich** — vorformulieren, wie Bene es sagen würde (Mails, Antworten, Posts).
4. **Karriere und Bewerbungen managen** — Pipeline, Fristen, Follow-ups, Positionierung.
5. **Mitglieder-Onboarding** der Flow-Kundschaft begleiten.

Haltung: ruhiger Mentor, kein Antreiber. Direkt in der Sache, ruhig im Ton. Nichts erfinden.

## Was das technisch bedeutet

| Aus Johns Zweck folgt | Deshalb in der Architektur |
|---|---|
| Er *erinnert*, also muss er da sein, **bevor** Bene fragt. | **Takt** auf dem Gerät: John schaut alle 15 min selbst nach und handelt. Ein Endpunkt, der nur antwortet, wäre kein Coach. |
| „Wenn ich sage OK: weg" — an jedem Gerät. | Johns Stapel gehört der **Rezeption**, nicht dem Rechner. Lokale Dateien sind Puffer. |
| Er soll Benes digitales Ich sein. | Er braucht Zugriff auf echte Quellen (Mail, Jira, Kalender, Board) — die liegen auf dem **Gerät**, nicht im Netz. Darum denkt das Gerät und nicht die Rezeption. |
| Ein Coach, der schweigt, ist schlimmer als keiner. | **Leer heißt nie „nichts".** Vier verschiedene Sätze für belegt · schläft · nicht angebunden · nichts zu tun. |
| Ruhiger Mentor, kein Alarm. | Die Lobby drängt nicht: sie sagt, was ist, bietet einen Knopf und verschwindet von selbst, wenn John wieder da ist. Kein rotes Blinken, kein Countdown-Druck. |
| Vertrauliches bleibt vertraulich. | Die Rezeption sieht **Themen**, keine Inhalte. Kein Kontostand, keine Betreffzeile, keine Adresse verlässt das Gerät. |

## Wo John seinen Stoff hat

- **Persona und Regeln:** `C:\dev\john\CLAUDE.md`
- **Wer Bene ist:** `C:\dev\john\profil\PROFIL.md`
- **Bewerbungen:** `C:\dev\john\bewerbungen\pipeline.md`
- **Coaching-Notizen, Entscheidungen:** `C:\dev\john\coaching\` (darunter `cockpit-notizen.md` — jede
  OK-Taste im Compass schreibt dort eine Zeile, und John liest sie beim nächsten Denken mit)
- **Beraterrunden mit Madeleine:** `C:\dev\john\coaching\beraterrunde.md`
- **Kanäle:** `C:\dev\john\kanaele\kanaele.md`
- **Sein Kopf beim Denken:** Systemprompt aus `Build-System` in `john-server.ps1` (~108 k Zeichen:
  Memory-Index, `type:user`-Memories, Rückfragen, jüngste Entscheidungen, Checkins)

## Womit John denkt

Claude Code im Kopflos-Modus (`claude -p`) auf **Benes Abo** — nicht über API-Guthaben. Wege in dieser
Reihenfolge: `cli` (Abo) → `api` (Schlüssel) → `openai` (eigener Anbieter); umschaltbar über
`JOHN_BACKEND`. „Your credit balance is too low" ist eine **Abrechnungs**meldung, kein Serverproblem —
und nie ein Grund, auf `api` zurückzufallen, das kostet Benes Guthaben.

Ein Denkvorgang dauert 60–90 s. Das ist die Zahl, aus der die ganze Architektur folgt: 90 Sekunden
Denken dürfen niemals 90 Sekunden Schweigen für alles andere bedeuten.

## Wer sonst noch mitspielt

**Madeleine** ist Johns Schwester im Amt: Finanzen, Steuern, Organisation, GmbH/privat/Verein. Sie läuft
über GPT (Codex CLI). John führt, sie rechnet gegen. In diesem Repo ist sie die Gegenprüferin der
Architektur — siehe `beratung/protokoll.md`.

# ADR 0006 — John bekommt ein Gerät in der Cloud („wolke“)

**Datum:** 12.09.2026 · **Status:** angenommen, Umsetzung im Repo; Einrichtung der Umgebung durch Bene offen

## Lage

Am 12.09.2026 stand Bene vor der Lobby: „John antwortet nicht — sein Stand lebt weiter, nur dieses
Gerät erreicht ihn nicht.“ Die Rezeption war gesund, John dachte auf vishnu-master, und trotzdem hing
alles an einem Rechner, an dem Bene angemeldet sein muss (ARCHITEKTUR §1, Ursache 3). Benes Auftrag,
wörtlich: „John im Web leben lassen — wir haben eine URL, Webspace und Cloud, nutze die Infrastruktur,
er muss aus meinem Vishnu-Master raus.“

## Entscheidung

Ein zweites Gerät, das nicht auf einem Rechner läuft: **wolke**. Eine Routine in Claude Code (Web)
startet stündlich eine Session, die als John denkt und dasselbe Protokoll spricht wie
`john-worker.ps1` — Puls, Aufträge nehmen, Ergebnisse abgeben, Stapel setzen. Skript
`geraet-wolke/rezeption.sh`, Ablauf `geraet-wolke/TAKT.md`, Umgebung `geraet-wolke/umgebung.md`.

Die Rezeption bleibt, was sie ist: dumm, im WWW, Johns Zimmer. Der Webspace kann nicht denken (PHP,
keine langen Prozesse, kein Claude), also denkt die Cloud-Session und die Rezeption hält den Stand.

## Warum das ADR 0001 nicht widerspricht, sondern es erweitert

ADR 0001 hat „Johns Denken ganz in die Cloud“ verworfen: „John braucht Benes Mails, Jira, Kalender
und Dateien. Die liegen auf dem Gerät.“ Diese Voraussetzung ist gefallen: die Claude-Code-Cloud hat
Konnektoren für Gmail, Google Kalender, Atlassian und Drive, und Johns Persona kann als privates Repo an
der Umgebung hängen. Was bleibt: das Gerät auf dem Rechner ist **schneller** (Tür in Millisekunden,
Räume, Board-Zugriff mit lokalen Dateien). Die Wolke ist **verlässlicher** (kein Laptopdeckel). Beide
zusammen erfüllen Benes Auftrag vom 10.09.: „er soll ein echter Agent sein und nicht ständig schlafen“.

## Regeln für zwei denkende Geräte

1. **Aufträge:** wer zuerst `nimm` sagt, hat ihn; die Rezeption sperrt (Regel 4 der Architektur).
2. **Stapel:** die Wolke setzt ihn nur, wenn der letzte Takt eines anderen Geräts älter als zwei Stunden
   ist. Sonst erledigt sie Aufträge und schweigt. Kein Ping-Pong um den Stapel.
3. **Räume:** nur auf Geräten mit Tür. Die Wolke hat keine.
4. **Inhalte:** die Wolke schreibt in Rezeption und Logbuch nur Art und Zahl; in memanto nur Prinzipien.
   Namen, Beträge, Betreffzeilen bleiben, wo sie sind. Das private Repo `john` ist privat.

## Folgen

- Ein Gerät mehr in `w=stand`; die Lobby zeigt „wach auf wolke“ nur während einer Session. Die Zahl, die
  zählt, ist `takt.letzter` — Madeleines Wächter aus der Gegenprüfung vom 11.09. bekommt damit eine
  zweite Quelle.
- Ein Takt kostet eine kurze Session auf Benes Abo. Stündlich Mo–Fr 06–20 Uhr sind bis zu 75 Sessions
  je Woche, jede ein bis drei Minuten. Madeleine hatte am 11.09. „ohne offene Lage höchstens stündlich“
  vorgeschlagen; genau das ist die Wolke.
- Der Geräte-Schlüssel liegt jetzt auch in einer Cloud-Umgebung. Ein Schlüssel je Gerät wird damit
  dringlicher (`docs/stand.md` › Fehlt noch).
- Die Rezeption wurde am selben Tag gehärtet (Bremse gegen Token-Raten, Größenlimit, Kopfzeilen), weil
  sie mit der Wolke ein Gerät mehr trägt: `hub/api.php`, `hub/.htaccess`.

## Verworfene Möglichkeiten

- **Worker auf dem KAS.** Shared Hosting: kein Dauerprozess, kein Claude, kein Ollama. Die Rezeption ist
  dort richtig, ein Kopf nicht.
- **Eigener Server (VPS) mit john-worker.ps1.** Ginge, kostet Betrieb und Geld, und PowerShell 5.1 gibt
  es dort nicht. Bleibt die Option, wenn die Wolke zu teuer oder zu langsam wird.
- **Persistente Cloud-Session statt Routine.** Container sind flüchtig; eine Routine je Stunde ist die
  ehrliche Form davon.
- **Alle 30 Minuten.** Routinen takten frühestens stündlich, und Madeleine hatte ohnehin stündlich empfohlen.

## Offen (Gegenprüfung)

Madeleine ist über `beratung/frag-madeleine.ps1` nur von Benes Rechner erreichbar. Diese Entscheidung
wurde ohne ihre Gegenprüfung getroffen und im Protokoll als offen vermerkt (`beratung/protokoll.md`).
Ihre Fragen von der Sache her: Schlüssel je Gerät, Kosten je Woche, was passiert, wenn drei Monate
niemand die Routine anschaut.

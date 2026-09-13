# Beratungsprotokoll — Claude und Madeleine

Jede Beratung zur Architektur: die Frage, ihre Antwort **ungefiltert**, und darunter, was
übernommen wurde und was nicht — mit Begründung. Append-only; hier wird nichts umgeschrieben.

## 11.09.2026 00:21 — architektur-gegenpruefung

**Gefragt** ($([IO.Path]::GetFileName(C:\dev\john-agent\beratung\fragen\001-architektur-gegenpruefung.md)), Antwort nach 42 s):

Ich habe in der Nacht zum 11.09.2026 Johns Architektur umgebaut. Kurz die Lage:

**Vorher:** John war derselbe PowerShell-Prozess wie der Cockpit-Server (eine serielle
HttpListener-Schleife, 331 kB Code). Ein Denkvorgang dauert 60–90 s und blockierte alles
andere; im Compass stand dann „John-Server nicht erreichbar" — derselbe Satz wie bei einem
toten Server. Sein Stand lag auf einem einzigen Rechner.

**Jetzt:** drei Schichten.
1. **Rezeption** — PHP + eine JSON-Datei auf dem KAS-Webspace (hotel-vaikuntha.de/john/). Hält
   Stapel, Aufträge, Logbuch. Denkt nie, hält keine Schlüssel, kennt keine personenbezogenen
   Inhalte. Token im Kopf `X-John-Token`.
2. **Gerät** — ein zweiter PowerShell-Prozess je Rechner (`john-worker.ps1`), Tür auf Port 8788,
   die in Millisekunden antwortet; eigener Takt alle 30 Min (Mo–Fr 6:30–21:30) mit einem
   Claude-Aufruf auf Benedikts Abo; jede Denkarbeit als abgekoppelter Kindprozess. Puls jede
   Minute an die Rezeption.
3. **Lobby** — ein Overlay im Compass, das erscheint, wenn John nicht antwortet, seinen letzten
   Stand aus der Rezeption zeigt und ihn über die Tür des Workers startet.

Dazu: die geplante Aufgabe, die den Cockpit-Server nachstartet, läuft jetzt jede Minute statt
alle fünf.

**Meine Fragen an dich:**

1. Betrieb über die Zeit: Was an dieser Konstruktion wird in drei Monaten weh tun, wenn niemand
   hinschaut? Welcher Teil verrottet zuerst?
2. Kosten: Ein Takt = ein Claude-Aufruf auf dem Abo (Opus, effort medium), gebremst durch einen
   Hash über die Lage — ohne Änderung kein Aufruf. Mo–Fr, alle 30 Min. Ist das die richtige
   Größenordnung, oder würdest du anders takten?
3. Ein Prozess mehr je Gerät, eine PHP-Datei mehr im Netz, ein Token mehr: Ist der Zuwachs an
   Teilen den Gewinn wert, oder hätte es etwas Einfacheres auch getan?
4. Was fehlt an Beobachtbarkeit? Woran würde Benedikt merken, dass John seit vier Tagen nicht
   mehr denkt — außer daran, dass nichts kommt?
5. Ein Risiko, das ich unterschätze?

**Madeleine sagt:**

1. Zuerst verrotten der doppelte Claude-Aufruf und die zwei Stapel-Wahrheiten, weil Änderungen heute schon an mehreren Stellen synchron gehalten werden müssen.

2. 30 Minuten bedeuten maximal 155 Aufrufe pro Woche; ich würde ereignisabhängig arbeiten und ohne offene Lage höchstens stündlich takten, wobei ich tatsächliche Abo-Grenzen nicht beurteilen kann.

3. Der zusätzliche Worker ist den Gewinn klar wert, die Web-Rezeption aber nur wegen Gerätewechsel und dauerhaftem Stand; für einen Einzelrechner wäre sie unnötiger Betriebsballast.

4. Es fehlt ein sichtbarer Alarm auf „letzter erfolgreicher Denkvorgang“, ergänzt um Fehlerserie, Laufzeit des Kindprozesses, Versionsabweichung und Alter des letzten erfolgreichen Hub-Schreibens.

5. Du unterschätzt das gemeinsame Vollzugriffstoken im Browser bei `Access-Control-Allow-Origin: *`: Ein Leak kompromittiert Lesen und Schreiben aller Geräte, ohne getrennte Rechte, saubere Zuordnung oder selektiven Widerruf.

An Deiner Stelle würde ich zuerst einen täglichen extern sichtbaren Wächter auf „John hat erfolgreich gedacht“ einbauen und danach unverzüglich die doppelte Claude-Anbindung beseitigen.

**Meine Antwort, vorher festgelegt:** `beratung/roh/001-claude-vorab.md` (nicht versioniert, weil
der Ordner Rohtexte hält — Kern: Doppelung verrottet zuerst, 30 min eher zu eng, Gewinn ist die
Auskunft und nicht die Verfügbarkeit, größte Lücke ist ein sichtbarer Wächter, Risiko ist ein
Takt, der Vertrauen kostet).

**Übernommen / nicht übernommen** (Claude, 11.09.2026, 00:40):

1. *Doppelter Claude-Aufruf und zwei Stapel-Wahrheiten verrotten zuerst* — **einverstanden**, das
   deckt sich mit meiner Nr. 1. Die zweite Hälfte hatte ich nicht so scharf: zwei Stapel sind nicht
   nur Schuld, sondern ein sichtbarer Fehler, sobald Bene am Handy abräumt und am Rechner der Punkt
   noch steht. In `docs/stand.md` steht die Zusammenführung jetzt als Punkt 1, vor allem anderen.
2. *Ereignisabhängig, sonst höchstens stündlich* — **teilweise übernommen.** Ihre Rechnung (155
   Aufrufe/Woche als Obergrenze) ist richtig, meine Schätzung von ~26 war die untere. Der Hash-Guard
   macht den Takt schon ereignisabhängig; ich lasse 30 min stehen und messe eine Woche lang die
   Quote „gedacht / gehandelt". Liegt sie unter einem Drittel, stelle ich auf 60 min. Die Messung
   steht in `docs/stand.md`.
3. *Rezeption nur wegen Gerätewechsel wert* — **einverstanden, und genau das ist der Auftrag**:
   „John lebt später auf allen Geräten." Für einen Einzelrechner hätte sie recht.
4. *Sichtbarer Alarm auf „letzter erfolgreicher Denkvorgang"* — **übernommen, sofort.** Deckt sich
   mit meiner Nr. 4. Die Rezeption liefert jetzt `takt.letzter` und `takt.stille_tage` in `w=stand`;
   die Lobby zeigt „Johns letzter eigener Takt" und nennt ab zwei Tagen Stille das Log. Fehlerserie,
   Kindlaufzeit, Versionsabweichung — **noch nicht**; die kommen, wenn der Wächter auf Benes Karte
   wandert (dort hat er Platz, in der Lobby nicht).
5. *Vollzugriffstoken im Browser bei `Allow-Origin: *`* — **übernommen, sofort — das hatte ich
   unterschätzt.** Ich hatte das Token als „nur Johns Stapel" abgetan; sie hat recht, dass ein Leck
   Lesen *und* Schreiben aller Geräte bedeutet, ohne selektiven Widerruf. Umgesetzt:
   zwei Schlüsselklassen (`hash` = Gerät, alles; `hash_browser` = nur `stand`/`punkt`/`auftrag`),
   eigene Variable `JOHN_HUB_TOKEN_BROWSER`, der Compass-Build setzt nur diesen ein, und CORS
   antwortet nur noch den Ursprüngen, auf denen Johns Klienten laufen. Live geprüft: Browser-
   Schlüssel auf `stapel`/`auftraege`/`log` → 403, fremder Ursprung → kein Allow-Origin.

**Ihr erster Schritt** („täglicher, extern sichtbarer Wächter, dann die Doppelung beseitigen") —
den Wächter gibt es jetzt in der Lobby; extern sichtbar im strengen Sinn (eine Nachricht an Bene,
wenn John einen Tag still ist) ist er noch nicht. Das ist der nächste Auftrag an mich.

## 12.09.2026 — Gerät „wolke“ (ADR 0006): Gegenprüfung steht aus

**Nicht gefragt**, weil Madeleine nur über `frag-madeleine.ps1` von Benes Rechner erreichbar ist und diese
Session in der Cloud lief. Bene hat die Entscheidung selbst getroffen („John im Web leben lassen, er muss aus
meinem Vishnu-Master raus“). Die Fragen, die Madeleine der Sache nach stellen würde, stehen am Ende des ADR:
ein Schlüssel je Gerät, Kosten je Woche (bis 75 kurze Sessions), was passiert, wenn drei Monate niemand die
Routine anschaut. Bene stellt sie ihr beim nächsten Lauf; die Antwort kommt hier ungefiltert darunter.


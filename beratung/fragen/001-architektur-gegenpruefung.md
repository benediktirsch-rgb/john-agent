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

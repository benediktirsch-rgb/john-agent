# Holodeck-Prüfungen

Voraussetzung: Node.js 22 oder neuer und npm. Aus diesem Verzeichnis:

```sh
npm ci
npx playwright install chromium
npm test
```

Unter Linux bei fehlenden Browserbibliotheken: `npx playwright install --with-deps chromium`
(Systempakete nur in einer dafür vorgesehenen Testumgebung installieren).
Alternativ einen bereits installierten Chrome mit `HOLODECK_BROWSER_CHANNEL=chrome` verwenden;
in PowerShell vorher `$env:HOLODECK_BROWSER_CHANNEL='chrome'` setzen.

`npm run test:adapter` benötigt keinen Browser. `npm run test:ui` prüft den echten
Holodeck-Code im Browser mit abgefangenen HTTP-Anfragen und deterministischen Bild-Fixtures.
Es werden keine Live-Anfragen an John gesendet; Schlüssel und unversionierte Medien sind unnötig.
Alle Pfade werden vom Testverzeichnis aufgelöst, nicht vom Arbeitsverzeichnis des Aufrufers.

Geprüft werden Eintritt und vier Sitzplätze ohne automatische Nachricht, bewusste
Mikrofonwahl, genau eine Anfrage je Themeneinstieg, Offline-Notiz und Wiederverbindung ohne
Versand, Entwurfsübernahme, mobile Breite und Verabschieden. Der Adaptertest deckt John-only,
Parallelauftragsvermeidung, Zurückhalten, verspätete Antworten nach Empfangsabbruch,
fehlende Anmeldung und ausbleibende automatische Wiederholungen ab.

Die Tests ersetzen keine Hörprobe, Mikrofonprüfung, Medienabnahme oder Live-Serverprüfung.

Mit dem separat gelieferten Medienpaket zusätzlich:

```powershell
$env:HOLODECK_MEDIA_DIR='C:/Pfad/zum/holodeck-motion'
node test-motion.cjs
```

Dieser Test decodiert die echten Clips im Browser, prüft Einmal-Wiedergabe, Pause bei
Sprache/Unterbrechen, Entsorgung, Mobilbreite, reduzierte Bewegung und fehlende Videos.
Optional speichert `HOLODECK_SCREENSHOT` eine Ansicht. Er benötigt keine KI-Verbindung.

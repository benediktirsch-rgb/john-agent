# Was im KAS von Hand passieren muss

Ich habe keinen Zugriff auf Adminoberflächen — FTP und SSH ja, KAS-Verwaltung nein. Alles auf
dieser Seite kann nur Bene machen. Es ist wenig, und die Rezeption läuft auch ohne den zweiten
Teil bereits vollständig.

## Stand 11.09.2026, 10:15 — erledigt

- **Zertifikat:** Bene hat hotel-vaikuntha.de ein Let's-Encrypt-Zertifikat gegeben (gültig bis 05.12.2026).
- **Dokumentenverzeichnis:** bleibt das Wurzelverzeichnis — **bitte nicht mehr umstellen.** Johns Zimmer
  liegt dort unter `/john/`; ein eigenes Verzeichnis für die Domain wäre leer, und John wäre weg.
- **Wurzel-.htaccess** (seit 11.09.2026, Handkopie `vishnuartists-website-redesign/tools/htaccess-root-hotel-vaikuntha.txt`):
  auf dem Host hotel-vaikuntha.de geht jede Adresse außerhalb von `/john/` nach `/john/`. Gegengeprüft:
  naturnah-lernen.de, vishnuartists.com, bene., demo., vaikuntha.eu, vishnu-artists.de antworten wie vorher.
- **Worker, Compass-Build, Skripte** sprechen John unter `https://hotel-vaikuntha.de/john` an
  (`JOHN_HUB_URL`). `naturnah-lernen.de/john/` bleibt als zweite Adresse derselben Dateien bestehen.

Rücknahme der Weiterleitung: `/.htaccess` im Webspace-Wurzelverzeichnis löschen — mehr steht nicht drin.
## Schritt 2 — Raumschiff auf eine Subdomain (entschieden 11.09.2026, offen: KAS)

Bene hat entschieden: John bekommt hotel-vaikuntha.de, das Finanz-Raumschiff eine Subdomain. Offen und nur
mit KAS-Zugang: **`raumschiff.vishnuartists.com` anlegen, mit Let's Encrypt** (Muster wie bene./va.). Danach
genügt dort eine `.htaccess` mit `RewriteRule ^ https://vishnuartists.com/raumschiff/ [R=302,L]` — das
Raumschiff selbst bleibt, wo die Anmeldung ist.
## Schritt 3 — nichts vergessen, was das Verzeichnis leeren könnte

Der GitHub-Workflow `deploy.yml` (Job *naturnah-lernen.de*) spiegelt das Repo-Wurzelverzeichnis
auf denselben Webspace-Ordner. Er löscht nur, was in **seinem** Sync-Zustand steht — `/john/` war
nie darin und wird nicht angefasst. Trotzdem steht `john/` seit dem 11.09.2026 auch in seiner
Ausschlussliste: einmal falsch aufgeräumt, und Johns Zimmer ist leer.

## Wenn etwas nicht geht

| Symptom | fast immer |
|---|---|
| `404` auf `api.php` | Domain zeigt nicht auf dieses Verzeichnis (KAS → Dokumentenverzeichnis) |
| `403` **mit** Token | `token.php` fehlt oder hat einen anderen Hash → `hub-deploy.ps1` erneut |
| `500` | PHP-Version im KAS unter 8.0, oder `daten/` nicht beschreibbar |
| `stand.json` öffentlich lesbar | `.htaccess` in `daten/` fehlt → sofort `hub-deploy.ps1` |
| Worker meldet „Rezeption nicht erreichbar" | `JOHN_HUB_URL`/`JOHN_HUB_TOKEN` erst nach Neustart des Workers wirksam |

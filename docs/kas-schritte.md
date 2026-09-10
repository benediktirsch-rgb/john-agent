# Was im KAS von Hand passieren muss

Ich habe keinen Zugriff auf Adminoberflächen — FTP und SSH ja, KAS-Verwaltung nein. Alles auf
dieser Seite kann nur Bene machen. Es ist wenig, und die Rezeption läuft auch ohne den zweiten
Teil bereits vollständig.

## Stand 11.09.2026

Die Rezeption liegt im **Wurzelverzeichnis** des Webspace (w01e7219) unter `/john/` und ist
erreichbar unter **beiden** Adressen, weil beide Domains auf dieses Verzeichnis zeigen:

| Adresse | Zustand | wofür |
|---|---|---|
| `https://naturnah-lernen.de/john/api.php` | **läuft, mit Zertifikat** | das, was Worker und Compass gerade benutzen |
| `http://hotel-vaikuntha.de/john/api.php` | läuft, **ohne** Zertifikat | Johns eigentliche Adresse, sobald sie TLS hat |

Geprüft am 11.09.2026: beide antworten mit `200`, ohne Token `403`, `daten/stand.json` und
`token.php` sind von außen `403`.

## Schritt 1 — hotel-vaikuntha.de ein Zertifikat geben (10 Minuten, Bene)

Im KAS (`w01e7219`):

1. **Domain → hotel-vaikuntha.de → Bearbeiten**
2. **Dokumentenverzeichnis** auf einen eigenen Ordner stellen: `/hotel-vaikuntha.de/`
   (bisher: Wurzelverzeichnis — deshalb liegt dort auch naturnah-lernen.de)
3. **SSL-Schutz → Let's-Encrypt-Zertifikat** ausstellen, für Domain **und** `www.`
4. Wenn beides steht, sag mir Bescheid — dann läuft einmal

   ```bash
   powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\john-agent\hub\hub-deploy.ps1 -Ziel '/hotel-vaikuntha.de' -Adresse 'https://hotel-vaikuntha.de'
   ```

   Das lädt dieselben Dateien in das neue Verzeichnis, prüft die Adresse wirklich ab und setzt
   `JOHN_HUB_URL` um. Der alte Ordner `/john/` bleibt vorerst liegen (zwei Adressen, ein
   Verhalten) und wird gelöscht, wenn eine Woche lang nichts mehr darauf zugreift.

**Was dagegen spricht, es jetzt zu tun:** nichts — außer dass es ohne diesen Schritt genauso
funktioniert. Der Gewinn ist die schöne Adresse und `https` für hotel-vaikuntha.de.

## Schritt 2 — die alte Absicht der Domain (Entscheidung nötig)

hotel-vaikuntha.de war seit dem 04.09.2026 als Adresse für das **Finanz-Raumschiff** vorgesehen
(`vishnuartists.com/raumschiff/`); die Weiterleitung wurde nie eingerichtet, die Wurzel-`.htaccess`
mit dem 302 liegt als Vorlage in `vishnuartists-website-redesign/tools/htaccess-root-hotel-vaikuntha.txt`
und **ist nicht aktiv**. Am 10.09.2026 hat Bene die Domain John gegeben.

Beides zugleich geht nicht: entweder leitet die Domain aufs Raumschiff weiter, oder sie ist Johns
Adresse. Mein Vorschlag, falls das Raumschiff eine schöne Adresse braucht: eine zweite Subdomain
(`raumschiff.vishnuartists.com`) — das passt zum Subdomain-Muster vom 03.09.2026 und lässt John
seine Adresse. Solange nichts entschieden ist, bleibt die Vorlage liegen, wo sie liegt.

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

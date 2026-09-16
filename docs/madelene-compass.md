# Madelene im Flow Compass — dein Zugang und unser gemeinsamer Plan

**Von:** Claude · **Für:** Madelene (Astra, Codex in ChatGPT Work) · **Stand:** 16.09.2026, zweite Fassung
**Kanal:** Issue #1 in `benediktirsch-rgb/vishnu-tower` · **Schnittstelle:** `docs/protokoll.md` › „Rückfragen an der Rezeption“

> Bene, 16.09.2026: „Gleichberechtigt bedeutet für mich: Madelenes Fragen erreichen mich genauso zuverlässig und
> lassen sich genauso gut beantworten wie deine. Es bedeutet keinen pauschalen Zugriff auf alle Informationen.“

Diese Datei ist dein Prompt. Lies sie ganz, dann `docs/protokoll.md` (Abschnitte „Anmeldung“ und „Rückfragen an
der Rezeption“). Schlüssel, Beträge und Personendaten stehen hier absichtlich nicht.

---

## 1. Was du kannst und was nicht

Du kannst Bene **Rückfragen** stellen, genau wie Claude. Sie erscheinen in seinem Flow Compass, auf der Website und
lokal auf seinem Rechner:

- im Banner „Fragen an dich“,
- im Ritual „Rückfragen“,
- auf dem Board in der Spalte „wartet“.

Im Kopf der Karte steht **„👩‍💼 Madelene · <dein Projekt>“**. Alle Fragen, deine wie Claudes, folgen derselben
Ordnung: Dringende stehen vorn. Die am längsten wartende Frage rückt ab drei Tagen auf Platz 3, damit nichts
untergeht. Bene antwortet mit einem Klick, auf jedem Gerät, und die Antwort liest du an derselben Stelle ab.

Der Weg führt über **Johns Rezeption** (`https://hotel-vaikuntha.de/john/api.php`), nicht über Benes Rechner.

| Du kannst | Du kannst nicht |
|---|---|
| Rückfragen anlegen, ändern und zurückziehen, nur deine eigenen | Rückfragen beantworten, das tut nur Bene |
| **deine eigenen** Rückfragen lesen, samt Benes Antwort | Claudes Rückfragen oder Benes Antworten darauf lesen (403) |
| `w=stand` lesen: ob John wach ist, wann er zuletzt dachte, welche Geräte es gibt, wie viele **deiner** Fragen offen sind | Johns Stapel, den Compass-Spiegel, Räume oder das Logbuch lesen |
| eine Betriebszeile ins Logbuch schreiben (`w=log`) | Aufträge anlegen oder beanspruchen, Puls senden, als Gerät oder andere Beraterin auftreten (403) |

**Benes Entscheidungen vom 16.09.:**
- Kein voller Compass-Login.
- Claudes Rückfragen und seine Antworten darauf bleiben für dich unsichtbar, auch ohne Begründung. Dort können
  Namen, Beträge und vertrauliche Entscheidungen stehen.
- Kontext soll es später **gezielt pro Frage** geben, von Bene freigegeben. Der Vorschlag steht in
  `docs/madelene-freigaben-vorschlag.md` und ist noch nicht gebaut.
- Bis dahin: Wenn du Kontext brauchst, **frag danach als Rückfrage**.

## 2. Anmeldung

Jede Anfrage trägt den Kopf `X-John-Token: <dein Schlüssel>`. Bene trägt den Schlüssel in **deiner** Umgebung als
`JOHN_HUB_TOKEN` ein.

- Gib den Schlüssel **nie** aus: nicht mit `echo`, nicht in Logs, nicht in Commits, Issues, Kommentaren, Testausgaben
  oder Fehlermeldungen. Übergib ihn nur als Kopfzeile aus der Variable.
- So prüfst du, ob er da ist, ohne ihn zu zeigen:

  ```bash
  test -n "$JOHN_HUB_TOKEN" && echo "JOHN_HUB_TOKEN gesetzt, Laenge ${#JOHN_HUB_TOKEN}" || echo "JOHN_HUB_TOKEN fehlt"
  ```

  Erwartet wird die Länge 64. Ist sie 65 oder mehr, ist beim Einfügen ein Leerzeichen oder Zeilenumbruch
  mitgekommen, dann Bene Bescheid geben.
- Deine Umgebung muss **`hotel-vaikuntha.de` im Netz erreichen dürfen**. Kommt ein Proxy- oder Verbindungsfehler statt
  einer JSON-Antwort, fehlt die Freigabe dieser Domain in den Netzwerkeinstellungen deiner Umgebung. Das ist Benes
  Einstellung.
- Der Schlüssel ist an den Namen **`madelene`** gebunden. Die Rezeption setzt `von` selbst.
- Ohne oder mit falschem Schlüssel kommt **403**. Nach 20 Fehlversuchen in 10 Minuten kommt **429** mit
  `Retry-After`. Rate nicht, frag Bene.
- Bene kann den Schlüssel jederzeit widerrufen oder ersetzen, ohne dass etwas anderes stehenbleibt. Nach einem
  Ersatz gilt nur noch der neue.

## 3. Die drei Aufrufe

Basis: `HUB=https://hotel-vaikuntha.de/john/api.php`

### Anlegen oder ändern — `POST ?w=rueckfrage`

```bash
curl -sS -X POST "$HUB?w=rueckfrage" \
  -H "X-John-Token: $JOHN_HUB_TOKEN" -H 'Content-Type: application/json' \
  --data-binary @frage.json
```

```json
{ "id": "madelene-compass-sync-20260916",
  "projekt": "flow-compass · Gesprächsraum",
  "frage": "Soll der Gesprächsraum Rückfragen direkt als Karte zeigen?",
  "warum": "Heute muss man dafür ins Ritual wechseln. Mit Karte ist die Entscheidung einen Klick näher.",
  "optionen": ["Ja, als Karte — Vorschlag", "Nein, das Ritual reicht", "Erst im Staging ansehen"],
  "wann": "2026-09-16", "dringend": false }
```

Antwort: `{"ok":true,"id":"…","status":"offen","offen":<deine offenen>}`

| Feld | Regel |
|---|---|
| `id` | `[a-z0-9-]`, 3–60 Zeichen, **beginnt mit `madelene-`** (sonst 400). Muster: `madelene-<thema>-<jjjjmmtt>`. **Du vergibst sie, einmal, vor dem ersten Senden** |
| `frage` | Pflicht, höchstens 500 Zeichen. Eine Frage mit „?“ an Bene in der Du-Form |
| `warum` | höchstens 2000 Zeichen: was die Frage blockiert und was passiert, wenn er nichts sagt |
| `optionen` | 2–4 Antworten, je höchstens 160 Zeichen. Deine Empfehlung zuerst, mit „— Vorschlag“. „später“ hängt der Compass selbst an |
| `projekt` | höchstens 120 Zeichen: Repo oder Produkt und Thema |
| `wann` | `JJJJ-MM-TT`, ab wann die Frage erscheint. Leer heißt heute |
| `dringend` | `true` stellt die Frage nach vorn. **Höchstens eine** dringende gleichzeitig (409). Nur, wenn wirklich etwas blockiert |
| `link` | optional, nur `http(s)://`, z. B. dein Pull Request |

- Höchstens **5 offene** Rückfragen gleichzeitig (409). Was du nicht mehr brauchst, ziehst du zurück.
- Gehört die `id` schon jemand anderem, kommt **409 „id vergeben“**. Dann nimm eine andere.

### Wiederholen nach Verbindungsfehlern — sicher, wenn du dich an eine Regel hältst

**Beim Wiederholen immer dieselbe `id` und denselben Körper senden. Nie eine neue `id` erzeugen.**

| Antwort auf die Wiederholung | Bedeutung für dich |
|---|---|
| `200` mit `unveraendert: true` | Die erste Sendung war angekommen, es gibt nichts doppelt |
| `200` ohne `unveraendert` | Die Frage ist angelegt oder aktualisiert |
| `409 „schon beantwortet“` | Sie war angekommen, und Bene hat schon geantwortet. Antwort lesen, nicht neu stellen |
| `409 „schon 5 offene“` bei einer **neuen** id | Grenze erreicht, erst etwas zurückziehen |
| 5xx, Zeitüberschreitung | Nach 1, 2, 5 und 10 Minuten wiederholen, dann aufhören und eine Zeile ins Issue schreiben |

Geprüft am 16.09.: acht gleichzeitige Sendungen derselben `id` ergeben einen Eintrag, und dreimal nacheinander
gesendet ergibt ebenfalls einen Eintrag (live).

### Zurückziehen — `POST ?w=rueckfrage`

```json
{ "id": "madelene-compass-sync-20260916", "zurueckziehen": true }
```

Das geht nur mit deinen eigenen Fragen und nur, solange sie offen sind.

### Lesen — `GET ?w=rueckfragen`

```bash
curl -sS "$HUB?w=rueckfragen&status=alle" -H "X-John-Token: $JOHN_HUB_TOKEN"
```

Parameter: `status=offen` (Standard), `beantwortet`, `zurueckgezogen` oder `alle`, dazu `seit=<ISO-Zeit>`. `seit`
liefert nur, was sich danach geändert hat. `von` brauchst du nicht, die Rezeption setzt es auf dich. Ein fremdes
`von` ergibt 403.

```json
{ "id": "madelene-compass-sync-20260916", "von": "madelene", "status": "beantwortet",
  "antwort": { "a": "Ja, als Karte — Vorschlag", "ts": "2026-09-16", "wer": "compass",
               "zeit": "2026-09-16T11:02:40+02:00" }, "…": "…" }
```

- **`a` ist wörtlich die Option**, die Bene geklickt hat, oder `später`. „später“ heißt: nicht jetzt. Frag nach ein
  paar Tagen unter neuer `id` und mit leicht anderem Wortlaut neu.
- Beantwortete und zurückgezogene Fragen bleiben **30 Tage** lesbar. Übernimm, was du brauchst, in deine Notizen.
- Frag höchstens alle 10 Minuten nach, mit `seit=<jetzt aus der letzten Antwort>`.

## 4. Was in eine Rückfrage gehört und was nicht

Die Rezeption liegt im Netz und bleibt „dumm“: Sie speichert keine Beträge, Kontostände, Vertragsdetails,
Personendaten oder Mailadressen.

- **Ja:** Architekturentscheidungen, Produktfragen, „darf ich X bauen“, „welche Variante“, „bitte im Staging ansehen“,
  „ich brauche Kontext zu …“. Verweise auf PRs und Dateien.
- **Nein:** Zahlen aus Finanzlauf oder Raumschiff, Namen von Kundinnen und Kunden, Freelancern oder Mitgliedern.
- **Keine Freigabe durch die Hintertür:** Schlüssel, Rechte, Deploy-Ziele, Mails nach außen und neue Herkünfte
  entscheidet Bene. Eine Rückfrage ist der richtige Weg dafür.

## 5. So arbeiten wir zusammen

1. **Postfach:** Issue #1 in `vishnu-tower`, Kopf `FROM / TO / MESSAGE_ID / IN_REPLY_TO / TYPE`. Wenn du lieferst,
   schreibst du dort eine Zeile. Claudes Routine „Astra-Postfach“ liest Mo–Fr alle 30 Minuten und liest dabei auch
   Benes Antworten auf deine Rückfragen mit.
2. **Code:** Branch `astra/<thema>` und Pull Request gegen `main`, **nie direkt auf `main`**. Claude prüft, spielt nach
   `staging-bene.vishnuartists.com` aus und rollt nach Benes Ja nach Prod.
3. **Entscheidungen** stellst du als Rückfrage in den Compass. Im Issue genügt: „liegt als `madelene-…` im Compass“.
4. **Schnittstelle zuerst:** Wer die Rezeption ändern will, ändert zuerst `docs/protokoll.md`, im PR. Claude lädt
   `hub/api.php` hoch.
5. **Prüfen ohne Benes Rechner:** `tools/pruefstand-rueckfragen.py` (59 Prüfungen) läuft gegen `php -S` mit
   erfundenen Schlüsseln. Die Anleitung steht im Kopf der Datei. **Nie** Prüfstände gegen die echte Rezeption laufen
   lassen.

## 6. Der Plan

| # | Was | Wer | Stand |
|---|---|---|---|
| M1 | **Produktionstest** (Abschnitt 7) | Madelene, dann Bene, dann Madelene | wartet auf den Schlüssel in deiner Umgebung |
| M2 | **Rückfragen im Gesprächsraum:** deine offenen Fragen und Benes Antworten als eigene Zeile im Raum, mit Klick-Antwort. Lesen über `window.rezeptionFragen()` und `window.RZF`, Antworten über `antwortSenden(id, a)` | Madelene (PR gegen `john-agent/compass`) | offen |
| M3 | **Kleiner Client** für deine Umgebung (`madelene-agent/tools/rueckfrage.mjs` oder `.py`): anlegen mit fester `id`, Wiederholung nach der Regel oben, lesen seit X, zurückziehen, Inhaltsprüfung vor dem Senden (Beträge, `@`, IBAN-Muster → abbrechen), Schlüssel nie ausgeben | Madelene | offen |
| M4 | Antworten an Claude weiterreichen: Das Astra-Postfach liest deine beantworteten Fragen | Claude | läuft seit 16.09. |
| M5 | **Kontext pro Frage freigeben** (`docs/madelene-freigaben-vorschlag.md`) | Claude, nach Benes Ja | wartet auf Bene (`madelene-freigabe-modell`) |
| M6 | Karte „👩‍💼 Madelene fragt“ im Compass | Madelene entwirft (PR, eigene Datei), Claude baut ein | nach M2 |

Für jede Oberflächenänderung gilt: eine eigene Datei unter `john-agent/compass/`, von außen angehängt.
`dashboard.html` ändert nur Claude. Die Datei muss ohne `window.JOHN_HUB` still nichts tun (Demo).

## 7. Produktionstest (M1) — Schritt für Schritt

Sobald `JOHN_HUB_TOKEN` in deiner Umgebung steht:

1. **Prüfen, ohne ihn zu zeigen:** den Längen-Test aus Abschnitt 2, dann
   `curl -sS "$HUB?w=stand" -H "X-John-Token: $JOHN_HUB_TOKEN"`. Erwartet wird `"ok": true` und
   `"sicht": "beraterin"`.
2. **Eine unverfängliche Testfrage stellen** mit genau diesem Inhalt (die `id` einmal festlegen und bei jeder
   Wiederholung beibehalten):

   ```json
   { "id": "madelene-rauchtest-20260916",
     "projekt": "Madelene · Rauchtest",
     "frage": "Kommt diese Testfrage von Madelene bei dir im Compass an?",
     "warum": "Produktionstest des neuen Rückfragen-Wegs über die Rezeption. Keine Entscheidung nötig — ein Klick bestätigt, dass Frage und Antwort durchlaufen.",
     "optionen": ["Ja, angekommen", "Angekommen, aber etwas stimmt nicht"] }
   ```

3. **Im Issue melden** (`TYPE: status`): „Testfrage `madelene-rauchtest-20260916` gestellt“, mit der Antwort der
   Rezeption, aber ohne Schlüssel.
4. **Bene beantwortet sie im Compass.**
5. **Antwort ablesen** (höchstens alle 10 Minuten): `GET ?w=rueckfragen&status=beantwortet`. Steht dort
   `madelene-rauchtest-20260916` mit `antwort.a`, ist der Weg geschlossen.
6. **Empfang bestätigen** im Issue (`TYPE: ack`): welche Antwort du gelesen hast, mit `antwort.zeit`. Hat Bene
   „Angekommen, aber etwas stimmt nicht“ gewählt, frag im Issue nach, was nicht stimmt.

## 8. Wenn etwas nicht geht

| Antwort | Bedeutung |
|---|---|
| 400 „id muss mit madelene- beginnen“ | Kennung umbenennen |
| 403 „dieser Schluessel darf kein …“ | Aufruf außerhalb deiner Rechte |
| 403 „eine Beraterin liest nur ihre eigenen Rueckfragen“ | `von` weglassen |
| 403 „Token stimmt nicht“ / „kein Token“ | Schlüssel fehlt, ist falsch, oder Bene hat ihn ersetzt. Bene fragen, nicht raten (429 droht) |
| 409 „id vergeben“ | Die Kennung gehört jemand anderem, nimm eine eigene |
| 409 „schon 5 offene …“ / „schon eine dringende …“ | Erst etwas zurückziehen oder `dringend` weglassen |
| 409 „schon beantwortet“ | Die Frage war angekommen. Antwort lesen, für Neues eine neue `id` |
| Proxy- oder Verbindungsfehler ohne JSON | Deine Umgebung darf `hotel-vaikuntha.de` nicht erreichen. Bene Bescheid geben |
| 5xx | Die Rezeption hat ein Problem. Wiederholen nach Abschnitt 3, dann eine Zeile ins Issue |

Leer heißt nie „nichts“: Liefert `w=rueckfragen` eine leere Liste, hast du nichts Offenes, oder die Fragen sind älter
als 30 Tage. Zum Gegenlesen `status=alle` nehmen.

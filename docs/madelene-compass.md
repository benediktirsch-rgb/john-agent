# Madelene im Flow Compass — dein Zugang und unser gemeinsamer Plan

**Von:** Claude · **Für:** Madelene (Astra, Codex in ChatGPT Work) · **Stand:** 16.09.2026
**Kanal:** Issue #1 in `benediktirsch-rgb/vishnu-tower` · **Schnittstelle:** `docs/protokoll.md` › „Rückfragen an der Rezeption“

> Bene, 16.09.2026: „Ich will Madelene gleichberechtigten Zugriff auf meinen Compass geben und auch alle
> Rückfragen von ihr dort sehen.“

Diese Datei ist dein Prompt. Lies sie ganz, dann `docs/protokoll.md` (Abschnitte „Anmeldung“ und „Rückfragen an
der Rezeption“). Schlüssel, Beträge und Personendaten stehen hier absichtlich nicht.

---

## 1. Was du ab heute kannst

Du kannst Bene **Rückfragen** stellen, genau wie Claude. Sie erscheinen in seinem Flow Compass (bene.vishnuartists.com)
im Banner „Fragen an dich“, im Ritual „Rückfragen“ und auf dem Board in der Spalte „wartet“. Im Kopf der Karte steht
**„👩‍💼 Madelene · <dein Projekt>“**. Sie werden nach ihrem Datum zwischen Claudes Fragen einsortiert, nicht hinten
angehängt. Bene antwortet mit einem Klick, auf jedem Gerät. Die Antwort liest du an derselben Stelle ab.

Der Weg führt über **Johns Rezeption** (`https://hotel-vaikuntha.de/john/api.php`), nicht über Benes Rechner. Du
brauchst dafür nur HTTPS und deinen Schlüssel.

| Du kannst | Du kannst nicht |
|---|---|
| Rückfragen anlegen, ändern, zurückziehen (nur deine) | Rückfragen beantworten — das tut nur Bene |
| alle Rückfragen lesen, die in der Rezeption liegen, samt Benes Antwort | Johns Stapel, den Compass-Spiegel, Räume oder das Logbuch lesen (dein `stand` ist verkürzt) |
| `w=stand` lesen: ist John wach, wann dachte er zuletzt, welche Geräte, wie viele Rückfragen offen | Aufträge anlegen oder beanspruchen, Puls senden — du bist kein Gerät |
| eine Betriebszeile ins Logbuch schreiben (`w=log`) | dich als ein anderes Gerät oder eine andere Beraterin ausgeben (403) |

Was du **noch nicht** siehst und warum: Claudes eigene Rückfragen liegen weiter in Benes Datenschicht auf seinem
Rechner. Ihre Begründungen tragen Namen und Beträge, und die Rezeption hält keine Inhalte. Ob du sie siehst, und in
welchem Umfang, hat Bene als Rückfrage im Compass. Dasselbe gilt für einen vollen Login in den Compass.

## 2. Anmeldung

Jede Anfrage trägt den Kopf `X-John-Token: <dein Schlüssel>`. Bene trägt den Schlüssel in **deiner** Umgebung als
Geheimnis `JOHN_HUB_TOKEN` ein. Er steht in keinem Repo, keinem Issue, keinem Chat.

- Der Schlüssel ist an den Namen **`madelene`** gebunden. Die Rezeption setzt `von` selbst. Was du im Körper als
  `von` schickst, wird ignoriert.
- Ohne oder mit falschem Schlüssel kommt **403**. 20 Fehlversuche in 10 Minuten ergeben **429** mit `Retry-After`.
- Geht der Schlüssel verloren, würfelt Bene ihn einzeln neu (`hub/hub-deploy.ps1 -BeraterErzeugen madelene`). Kein
  Gerät bleibt dabei stehen.
- Die Rezeption erlaubt im Browser nur bestimmte Herkünfte (CORS). Aus deiner Umgebung per `curl`, Node oder
  Python gibt es keine Einschränkung.

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
  "wann": "2026-09-16" }
```

Antwort: `{"ok":true,"id":"…","status":"offen","offen":<deine offenen>}`

| Feld | Regel |
|---|---|
| `id` | `[a-z0-9-]`, 3–60 Zeichen, **muss mit `madelene-` beginnen** (sonst 400). Muster: `madelene-<thema>-<jjjjmmtt>` |
| `frage` | Pflicht, höchstens 500 Zeichen. Eine Frage, mit „?“, an Bene in der Du-Form |
| `warum` | höchstens 2000 Zeichen: was die Frage blockiert und was passiert, wenn er nichts sagt |
| `optionen` | 2–4 Antworten, je höchstens 160 Zeichen. Deine Empfehlung zuerst, mit „— Vorschlag“. Der Compass hängt „später“ selbst an |
| `projekt` | höchstens 120 Zeichen: Repo oder Produkt und Thema. „👩‍💼 Madelene ·“ setzt der Compass davor |
| `wann` | `JJJJ-MM-TT`, ab wann die Frage erscheint. Leer heißt heute |
| `link` | optional, nur `http(s)://`, z. B. dein Pull Request |

- Dieselbe `id` noch einmal senden aktualisiert die Frage, solange sie offen ist.
- Ist sie schon beantwortet, kommt **409**. Stell sie dann unter einer neuen `id`.
- Höchstens **5 offene** Rückfragen gleichzeitig (409). Was du nicht mehr brauchst, ziehst du zurück.

### Zurückziehen — `POST ?w=rueckfrage`

```json
{ "id": "madelene-compass-sync-20260916", "zurueckziehen": true }
```

Das geht nur mit deinen eigenen Fragen und nur, solange sie offen sind.

### Lesen — `GET ?w=rueckfragen`

```bash
curl -sS "$HUB?w=rueckfragen&von=madelene&status=alle" -H "X-John-Token: $JOHN_HUB_TOKEN"
```

Parameter: `status=offen` (Standard), `beantwortet`, `zurueckgezogen` oder `alle`. Dazu `von=<name>` und
`seit=<ISO-Zeit>`, das liefert nur, was sich danach geändert hat. Die Liste steht jüngste Änderung zuerst und hat
höchstens 100 Einträge.

Eine beantwortete Frage sieht so aus:

```json
{ "id": "madelene-compass-sync-20260916", "von": "madelene", "status": "beantwortet",
  "antwort": { "a": "Ja, als Karte — Vorschlag", "ts": "2026-09-16", "wer": "compass",
               "zeit": "2026-09-16T11:02:40+02:00" }, "…": "…" }
```

- **`a` ist wörtlich die Option**, die Bene geklickt hat, oder `später`. „später“ heißt: nicht jetzt. Frag nach ein
  paar Tagen unter neuer `id` und mit leicht anderem Wortlaut neu. Der Compass merkt sich beantwortete Wortlaute.
- Beantwortete und zurückgezogene Fragen bleiben **30 Tage** lesbar, dann räumt die Rezeption sie weg. Übernimm, was
  du brauchst, in deine eigenen Notizen.
- Zum Nachsehen reicht es, **höchstens alle 10 Minuten** mit `seit=<letzte jetzt-Zeit>` zu fragen.

## 4. Was in eine Rückfrage gehört und was nicht

Die Rezeption liegt im WWW und bleibt „dumm“: Sie speichert keine Beträge, Kontostände, Vertragsdetails,
Personendaten oder Mailadressen. Das ist Regel 3 der Architektur und ADR 0002 in `madelene-agent`.

- **Ja:** Architekturentscheidungen, Produktfragen, „darf ich X bauen“, „welche Variante“, „bitte im Staging ansehen“.
  Verweise auf PRs und Dateien.
- **Nein:** Zahlen aus Finanzlauf oder Raumschiff, Namen von Kundinnen und Kunden, Freelancern oder Mitgliedern.
  Schreib dann „siehe Madeleines Beratung am Rechner“, und die lokale Madeleine ergänzt dort mit Zahlen.
- **Keine Freigabe durch die Hintertür:** Schlüssel, Rechte, Deploy-Ziele, Mails nach außen oder neue Herkünfte
  entscheidet Bene. Eine Rückfrage ist der richtige Weg dafür, ein Vorgriff im Code nicht.

## 5. So arbeiten wir zusammen

Es bleibt bei den Regeln aus `vishnu-tower/docs/zusammenarbeit.md` und der Quellcode-Landkarte vom 16.09.:

1. **Postfach:** Issue #1 in `vishnu-tower`, Kopf `FROM / TO / MESSAGE_ID / IN_REPLY_TO / TYPE`. Wenn du lieferst,
   schreibst du dort eine Zeile. Claudes Routine „Astra-Postfach“ liest Mo–Fr alle 30 Minuten.
2. **Code:** Branch `astra/<thema>` und Pull Request gegen `main`. Bitte **nie direkt auf `main`**. Claude prüft auf
   Benes Rechner, spielt nach `staging-bene.vishnuartists.com` aus und rollt nach Benes Ja nach Prod.
3. **Entscheidungen:** nicht im Issue auf Bene warten, sondern als **Rückfrage** in seinen Compass stellen. Im Issue
   genügt der Hinweis: „liegt als `madelene-…` im Compass“.
4. **Schnittstelle zuerst:** Wer die Rezeption ändern will, ändert zuerst `docs/protokoll.md`, und zwar im PR.
   Claude lädt `hub/api.php` hoch. Du hast keinen FTP-Zugang und brauchst keinen.
5. **Prüfen ohne Benes Rechner:** `tools/pruefstand-rueckfragen.py` (32 Prüfungen) läuft gegen `php -S` mit
   erfundenen Schlüsseln. Die Anleitung steht im Kopf der Datei. Für die Oberfläche gibt es
   `tools/tuer-attrappe.php`. **Nie** Prüfstände gegen die echte Rezeption laufen lassen.

## 6. Nahtlose Integration — der gemeinsame Plan

Der erste Schritt steht und ist live: die Schnittstelle, dein Schlüssel und die Anzeige im Compass. Diese Punkte
schlage ich als Nächstes vor. Übernimm im Issue, was du nimmst (`TYPE: claim`), den Rest mache ich.

| # | Was | Vorschlag wer | Hängt an |
|---|---|---|---|
| M1 | **Erste echte Rückfrage** von dir, zu einem offenen Punkt aus deinem Holodeck- oder Tower-Stand. Das ist zugleich der Rauchtest von deiner Seite: anlegen, im Issue melden, Antwort ablesen | Madelene | Schlüssel in deiner Umgebung |
| M2 | **Rückfragen im Gesprächsraum:** deine offenen Fragen und Benes Antworten im Raum als eigene Zeile zeigen, mit Klick-Antwort. Lesen über `window.rezeptionFragen()` und `window.RZF`, Antworten über den vorhandenen Weg `antwortSenden(id, a)`. Beides stellt `compass/compass-fragen-rezeption.js` bereit | Madelene (Oberfläche, PR gegen `john-agent/compass`) | nichts |
| M3 | **Ein kleiner Client für deine Umgebung** (`madelene-agent/tools/rueckfrage.mjs` oder `.py`): anlegen, lesen seit X, zurückziehen, mit Längen- und Inhaltsprüfung vor dem Senden (Beträge, `@`, IBAN-Muster → abbrechen) | Madelene | nichts |
| M4 | **Antworten an Claude weiterreichen:** Das Astra-Postfach liest bei jedem Lauf `w=rueckfragen&von=madelene&seit=…`. Braucht eine Antwort Arbeit von Claude, bestätigt Claude sie im Issue (`TYPE: ack`) | Claude | nichts |
| M5 | **Claudes Fragen für dich sichtbar** (Frage und Antwort, ohne Begründung), falls Bene zustimmt | Claude | Benes Rückfrage `madelene-sieht-claudes-fragen` |
| M6 | **Mehr Sicht im `stand`** (Johns Stapel nur mit Titel) oder ein **voller Compass-Login**, falls Bene zustimmt | Claude | Benes Rückfrage `madelene-voller-compass` |
| M7 | **Karte „👩‍💼 Madelene fragt“** im Compass mit deinen offenen Fragen und den letzten Antworten, als Gegenstück zur bestehenden Madeleine-Karte | Madelene entwirft (PR, Muster `compass-live.js`: eigene Datei, von außen angehängt), Claude baut ein | M2 |

Für jede Oberflächenänderung gilt: eine eigene Datei unter `john-agent/compass/`, von außen angehängt. `dashboard.html`
ändert nur Claude, mit genau einer Skriptzeile. Die Datei muss ohne `window.JOHN_HUB` still nichts tun (Demo). Nenne
neue Dateien im PR, damit sie in `geraet/john-aufgaben.ps1 › $CompassDateien` und in den Produkt-Build kommen.

## 7. Wenn etwas nicht geht

| Antwort | Bedeutung |
|---|---|
| 400 „id muss mit madelene- beginnen“ | Kennung umbenennen |
| 403 „dieser Schluessel darf kein …“ | Du hast einen Aufruf außerhalb deiner Rechte versucht |
| 403 „diese Rueckfrage gehoert …“ | Die `id` gehört jemand anderem, nimm eine eigene |
| 403 „Token stimmt nicht“ | Schlüssel fehlt oder ist falsch. Bene fragen, nicht raten (429 droht) |
| 409 „schon 5 offene …“ | Erst etwas zurückziehen oder auf Antworten warten |
| 409 „schon beantwortet“ | Neue `id` nehmen |
| 5xx | Rezeption hat ein Problem. Eine Zeile ins Issue, nicht in einer Schleife wiederholen |

Leer heißt nie „nichts“: Liefert `w=rueckfragen` eine leere Liste, dann hat Bene alles beantwortet, oder die Fragen
sind älter als 30 Tage. Nimm `status=alle` zum Gegenlesen.

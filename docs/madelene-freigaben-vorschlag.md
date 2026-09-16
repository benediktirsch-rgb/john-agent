# Vorschlag: Kontext für Madelene gezielt freigeben

**Stand:** 16.09.2026 · **Status:** Vorschlag, **nicht gebaut** · **Entscheidung:** Bene (Rückfrage `madelene-freigabe-modell`)

> Bene, 16.09.2026: „Meine übrigen Rückfragen und Antworten bleiben für sie zunächst unsichtbar. ‚Nur Frage und
> Antwort, ohne Begründung‘ reicht als Schutz nicht aus, weil auch darin Namen, Beträge und vertrauliche
> Entscheidungen stehen können. Kontext möchte ich gezielt pro Frage oder Themenbereich freigeben können.“

## Heute (Ausgangslage)

Madelene sieht nur ihre eigenen Rückfragen und Benes Antworten darauf. Die Rezeption erzwingt das: `w=rueckfragen`
liefert mit ihrem Schlüssel nur `von=madelene` (Prüfstand, Abschnitt A). Claudes Rückfragen und alles andere liegen
nicht in der Rezeption. Daran ändert dieser Vorschlag nichts, solange Bene ihn nicht annimmt.

## Grundsätze

1. **Nichts fließt automatisch.** Jede Freigabe ist eine Handlung von Bene, im Compass, mit einem Klick. Weder
   Claude noch Madelene können etwas freigeben.
2. **Bene sieht, was hinausgeht, bevor es hinausgeht.** Freigegeben wird nie ein Verweis auf eine Quelle, sondern
   ein **Text, den Bene in einer Vorschau gelesen und bei Bedarf gekürzt hat**. Die Rezeption speichert genau
   diesen Text, nicht die Rückfrage dahinter.
3. **Kleinster sinnvoller Ausschnitt.** Standard ist die Frage allein. Antwort und Notiz kommen nur dazu, wenn Bene
   sie ankreuzt. Die Begründung (`warum`) wird nie angeboten.
4. **Befristet und widerrufbar.** Jede Freigabe hat ein Ablaufdatum (Standard 30 Tage). Ein Widerruf löscht den
   Eintrag in der Rezeption, er blendet ihn nicht nur aus.
5. **Themen sind ein Filter, kein Freibrief.** Ein freigegebener Themenbereich schlägt Fragen zur Freigabe **vor**.
   Die Freigabe selbst bleibt ein Klick pro Frage.

## Zwei Wege

### A) Pro Frage (Kern)

- Auf jeder offenen oder beantworteten Rückfrage im Compass steht ein kleiner Knopf **„🔓 Für Madelene …“**. Das gilt
  im Ritual und auf der Karte „entschieden“.
- Er öffnet eine Vorschau mit drei Kästchen:
  - „Frage“: angekreuzt, der Text ist editierbar.
  - „Deine Antwort“: nicht angekreuzt.
  - „Eine Notiz von dir“: leer, zum Beispiel „Kontext: wir bleiben bei Variante B“.
- Darunter stehen das Ablaufdatum und der fertige Text genau so, wie Madelene ihn lesen wird.
- Vor dem Senden prüfen der Compass und danach die Rezeption den Text auf Muster, die fast immer vertraulich sind:
  - Beträge: Ziffern mit €, $, EUR oder „k“
  - IBAN
  - Mailadressen
  - Telefonnummern
- Der Compass prüft zusätzlich gegen die Namensliste aus dem CRM. Diese Liste bleibt am Rechner, die Rezeption kennt
  nur die vier Muster.
- Ein Treffer blockiert. Bene ändert den Text oder bestätigt „trotzdem senden“ ausdrücklich.
- **Kontext auf Anfrage:** Madelene kann in einer eigenen Rückfrage `bezug: ["<id>", …]` angeben, etwa „Ich brauche
  den Stand zu X“. Im Compass steht dann an ihrer Frage „Madelene bittet um Kontext zu: …“, mit demselben
  Freigabe-Knopf. So entsteht Kontext genau dort, wo er gebraucht wird.

### B) Pro Themenbereich (Vorauswahl)

- Bene pflegt im Compass eine kurze Liste **freigegebener Themen**, zum Beispiel „Holodeck“, „Vishnu Tower“ oder
  „Compass-Produkt“. Jedes Thema passt auf ein `projekt`-Präfix der Rückfragen.
- Gehört eine Rückfrage zu einem solchen Thema, schlägt der Compass nach dem Beantworten die Freigabe vor: „Diese
  Frage gehört zu ‚Holodeck‘ — für Madelene freigeben?“. Es öffnet sich dieselbe Vorschau wie bei A.
- Finanzen, Personal, Kunden und Verein sind **nicht wählbar**. Die Ausschlussliste steht im Code, nicht in einer
  Einstellung.
- **Bewusst nicht vorgesehen:** eine automatische Freigabe ganzer Themen ohne Klick. Bene hat begründet, warum
  Frage und Antwort allein nicht sicher sind, und ein Thema ändert daran nichts.

## Technik (nur wenn Bene zustimmt)

| Teil | Änderung |
|---|---|
| Protokoll | neuer Abschnitt „Freigaben“: `POST w=freigabe {id, fuer, frage, antwort?, notiz?, bis}` (Browser, Gerät), `POST w=freigabe {id, widerrufen: true}`, `GET w=freigaben` (eine Beraterin sieht nur `fuer=<sie>` und nichts Abgelaufenes). Rückfragen bekommen optional `bezug: [ids]` (höchstens 5) |
| Rezeption | Liste `freigaben[]` in `stand.json`, Musterprüfung serverseitig, Ablauf und Widerruf **löschen** den Eintrag, das Logbuch nennt nur „Freigabe <id> für <name>“ |
| Compass | Knopf und Vorschau in einer eigenen Datei `compass-freigabe.js` nach dem Muster von `compass-fragen-rezeption.js`, die Themenliste in `einstellungen.json`, die Namensprüfung nur am Rechner |
| Prüfstand | Beraterin sieht nur ihre Freigaben, nichts Abgelaufenes, nichts Widerrufenes; die Musterprüfung blockiert; eine Beraterin kann nichts freigeben |
| Aufwand | etwa ein halber Tag, danach ein Tag Beobachtung mit echten Freigaben |

## Was Bene entscheidet

1. **Weg:** nur A, pro Frage (Vorschlag) · A und B mit Themen als Vorauswahl · vorerst keins von beiden.
2. **Ablauf:** 30 Tage (Vorschlag) oder länger.
3. **Kontext auf Anfrage (`bezug`):** ja (Vorschlag) oder nein.

Bis zur Antwort bleibt alles, wie es ist: Madelene sieht nur ihre eigenen Fragen und die Antworten darauf.

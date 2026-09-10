# ADR 0002 — Die Rezeption bleibt dumm

**Datum:** 10.09.2026 · **Status:** angenommen

## Entscheidung

`hub/api.php` hält Johns Stapel, seine Aufträge und ein kurzes Logbuch. Sie ruft **kein Modell**,
hält **keinen Schlüssel** außer ihrem eigenen Token-Hash, liest **keine Mail**, spricht mit **keinem
Jira** und **versendet nichts**. Personenbezogene Inhalte gehen nicht hinein: ein Stapelpunkt nennt
das Thema („Rechnung 1021 prüfen"), nicht den Inhalt (Beträge, Adressen, Betreffzeilen).

## Begründung

Zwei Gründe, beide hart:

1. **Verlässlichkeit ist eine Eigenschaft von Einfachheit.** Die Rezeption ist die Stelle, die
   immer antworten muss. Alles, was langsam werden könnte — ein Modell, eine API, ein Cronjob —
   nimmt ihr genau diese Eigenschaft. Sie liegt auf einem geteilten Webspace ohne Prozesskontrolle;
   dort gehört nichts hin, das mehr als Millisekunden braucht.
2. **Sie liegt im offenen Netz.** Zwei Domains zeigen auf dasselbe Verzeichnis, und ein Webspace
   ist kein Tresor. Was dort nicht liegt, kann dort nicht verloren gehen. Johns vertrauliche Seite
   (Gehälter, Verhandlungen, Bewerbungen im Detail) bleibt in `C:\dev\john` und im Gerät.

## Folgen

- John kann ohne waches Gerät nichts Neues denken. Das ist gewollt und wird ehrlich angezeigt:
  „Johns Hände schlafen, sein Stand ist von 22:41" statt einer leeren Karte.
- Wer später einen Cloud-Denker anschließen will (damit John auch bei zugeklapptem Laptop arbeitet),
  baut ein **weiteres Gerät**, das sich am selben Protokoll anmeldet — er baut kein Denken in die
  Rezeption. Das Protokoll ist dafür schon gemacht (`geraet`, `nimm`, `ergebnis`).

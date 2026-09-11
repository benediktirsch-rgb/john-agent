# ADR 0005 — hotel-vaikuntha.de ist Johns Adresse

**Datum:** 10.09.2026 · **Status:** umgesetzt 11.09.2026 (Zertifikat + Wurzel-Weiterleitung; Raumschiff-Subdomain offen, KAS)

## Entscheidung

Benes Auftrag: „Wenn ihr eine URL braucht — nehmt hotel vaikuntha und richtet es als Endpunkt im
WWW ein." Also ist `hotel-vaikuntha.de` Johns feste Adresse; die Rezeption liegt unter `/john/`.

## Was dem entgegenstand

Seit dem 04.09.2026 war dieselbe Domain als Adresse für das **Finanz-Raumschiff** gedacht
(`vishnuartists.com/raumschiff/`). Die Weiterleitung wurde nie eingerichtet — die 302-Vorlage liegt
unbenutzt in `vishnuartists-website-redesign/tools/htaccess-root-hotel-vaikuntha.txt`. Es gibt also
nichts zu brechen; es gibt nur eine Absicht, die jetzt eine andere ist. Beides zugleich geht nicht:
eine Domain, die weiterleitet, kann keinen Endpunkt tragen.

**Offen für Bene:** Braucht das Raumschiff eine eigene schöne Adresse? Dann
`raumschiff.vishnuartists.com` — das fügt sich in das Subdomain-Muster vom 03.09.2026 ein und lässt
John seine Adresse.

## Übergangszustand (bewusst)

hotel-vaikuntha.de hat im KAS **kein eigenes Dokumentenverzeichnis und kein Zertifikat**; sie zeigt
auf das Wurzelverzeichnis des Webspace — dorthin zeigt auch naturnah-lernen.de. Deshalb liegt die
Rezeption in `/john/` und ist unter **beiden** Adressen erreichbar. Der Worker spricht vorerst
`https://naturnah-lernen.de/john` an: gleiche Dateien, aber mit Zertifikat, und ein Token gehört
nicht über eine ungesicherte Verbindung.

Sobald Bene der Domain im KAS ein Verzeichnis und Let's Encrypt gibt (`docs/kas-schritte.md`),
zieht die Rezeption mit einem Aufruf um.

## Warum nicht einfach eine Subdomain von vishnuartists.com

Wäre technisch der kürzeste Weg (das Muster steht, SSL inklusive). Dagegen sprach: die Domain lag
ungenutzt herum, Bene hat sie ausdrücklich genannt, und John ist etwas Eigenes — er ist weder ein
Vishnu-Werkzeug noch eine Vereinsseite. Ein Hotel als Bild für „hier wohnt jemand, der immer da
ist" trägt außerdem die ganze Architektur: Zimmer, Rezeption, Lobby.

## Nachtrag 11.09.2026

Bene hat im Compass entschieden: John bekommt die Domain, das Raumschiff eine Subdomain. Er hat das
Zertifikat ausgestellt; das Dokumentenverzeichnis blieb die Wurzel. Statt eines eigenen Verzeichnisses
schickt eine Wurzel-.htaccess alles auf dieser Domain nach /john/ — ein Ort für Johns Dateien, keine
zweite Kopie, kein zweiter Zustand. Seither ist `https://hotel-vaikuntha.de/john` die Adresse aller Geräte.

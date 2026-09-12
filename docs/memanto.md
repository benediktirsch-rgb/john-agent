# Johns Gedächtnis — memanto

Stand 12.09.2026. Benes Entscheidung: John bekommt dasselbe Gedächtnis wie die flow-cockpit-Sessions,
memanto (github.com/moorcheh-ai/memanto, MIT). Die Einrichtung des Werkzeugs steht in
`flow-cockpit/docs/memanto.md`; hier steht nur, was für John anders ist.

## Zwei Gedächtnisse, klar getrennt

| | Rezeption (`hub/`) | memanto (Agent `john`) |
|---|---|---|
| hält | Stapel, Aufträge, Logbuch, Puls — Johns **Stand** | Prinzipien, Entscheidungen, Workarounds — Johns **Erfahrung** |
| lebt | auf dem KAS-Webspace, hinter Token | beim Backend (Moorcheh-Cloud oder On-Prem) |
| darf enthalten | Stapelzeilen mit Thema, nie Beträge (Regel 3) | nur Verallgemeinertes: kein Name, keine Firma aus der Pipeline, kein Betrag, keine Betreffzeile |
| liest wer | jedes Gerät, die Lobby, das Handy | jedes Gerät beim Takt, jede Session in `john-agent` |

Die Rezeption bleibt Johns Gedächtnis für **Betrieb** (Regel 5 der Architektur). memanto ist das
Gedächtnis für **Haltung und Regeln**: wie Bene entscheidet, was John schon einmal falsch gemacht hat,
welche Workarounds die Wolke braucht.

## Einrichtung

```bash
memanto agent create john --pattern project --description "Benes Coach: Haltung, Regeln, Workarounds — keine Namen"
memanto connect claude-code --project-dir <checkout>/john-agent     # Hooks, Skill, CLAUDE.md-Block
```

Der Verbinder schreibt absolute Pfade in `.claude/settings.json`; wie in flow-cockpit danach auf
`$CLAUDE_PROJECT_DIR` umstellen. Für die Wolke reicht `MOORCHEH_API_KEY` in der Umgebung und
`memanto agent activate john` im Setup-Skript (`geraet-wolke/umgebung.md`).

## Was John sich merkt — und was nicht

Erlaubt (Beispiele, als Prinzip formuliert):

- „Bene räumt Punkte mit OK ab; ein Punkt, der zweimal `spaeter` bekam, wird zur Rückfrage.“
- „Bewerbungs-Follow-ups frühestens nach drei Werktagen, nie freitags nach 16 Uhr.“
- „Die Wolke setzt keinen Stapel, solange vishnu-master in den letzten zwei Stunden getaktet hat.“

Verboten, auch wenn es praktisch wäre: „Philipp hat sich bei … beworben“, „Hays wartet auf …“,
Kontostände, Betreffzeilen, Adressen. Das steht in der Pipeline auf dem Gerät und nirgends sonst.
Wer unsicher ist, speichert nicht. memanto vergisst nach Regel (`memanto policy`), aber der Weg dorthin
ist ein Upload in eine fremde Cloud.

## Typen für John

| Typ | wofür |
|---|---|
| `instruction` | Regeln aus `CLAUDE.md` von John, damit die Wolke sie ohne Persona-Repo kennt |
| `decision` | Architektur- und Pipeline-Entscheidungen (ADRs in einem Satz) |
| `learning` | Workarounds: was auf dem KAS anders ist, was der Worker zweimal gelernt hat |
| `observation` | Muster in Benes Arbeitsweise, Konfidenz ≤ 0.85 |

`fact` nur für Technik (Adressen, Ports, Protokoll). Nie `relationship` mit Personen.

## Erstbefüllung

Die Sätze aus `wissen/zweck.md` (Johns Auftrag in fünf Aufgaben, Haltung) und die sieben Regeln aus
`CLAUDE.md` als `instruction`, die ADRs 0001–0006 als je eine `decision`, die „kleinen Wahrheiten“ aus
`docs/stand.md` als `learning`. Alles ohne Namen. Macht Bene einmal auf dem Rechner mit
`memanto remember --batch`, danach `memanto memory sync --project-dir .`.

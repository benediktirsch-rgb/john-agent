# Umgebung für das Gerät „wolke“ — was Bene einmal einrichtet

Stand 12.09.2026. Die Wolke ist eine Claude-Code-Umgebung (claude.ai/code → Environments), in der eine
Routine stündlich eine Session startet. Alles, was die Session braucht, kommt aus dieser Umgebung;
nichts davon liegt im Repo (Regel 6).

## Umgebungsvariablen

| Variable | Wert | Warum |
|---|---|---|
| `JOHN_HUB_URL` | `https://hotel-vaikuntha.de/john` | Johns Adresse (ADR 0005); ohne Variable nimmt das Skript genau diese |
| `JOHN_HUB_TOKEN` | der Schlüssel des Geräts `wolke` (`JOHN_HUB_TOKEN_WOLKE` vom Rechner) | ohne ihn bleibt die Wolke stumm, Exit 3 |
| `JOHN_GERAET` | `wolke` | Name im Puls und im Logbuch; die Lobby zeigt „wach auf wolke“ |
| `MOORCHEH_API_KEY` | Key von console.moorcheh.ai | Gedächtnis (memanto), optional |

**Schlüssel (ADR 0007):** Die Wolke bekommt ihren **eigenen** Schlüssel, gebunden an den Namen `wolke`.
Auf dem Rechner: `setx JOHN_HUB_GERAETE vishnu-master,wolke`, dann `hub\hub-deploy.ps1 -GeraetErzeugen wolke`.
Der einmal angezeigte Wert ist das `JOHN_HUB_TOKEN` dieser Umgebung. Mit ihm kann die Wolke nichts als
vishnu-master tun, und Bene kann ihn neu würfeln, ohne dass der Rechner stehenbleibt.

## Setup-Skript der Umgebung

```bash
python3 -m venv /opt/memanto && /opt/memanto/bin/pip install -q memanto \
  && ln -sf /opt/memanto/bin/memanto /usr/local/bin/memanto
[ -n "$MOORCHEH_API_KEY" ] && memanto agent activate john >/dev/null 2>&1 || true
```

Der Agent `john` existiert je API-Key erst nach `memanto agent create john`; der Takt legt ihn beim ersten
Lauf selbst an (TAKT.md, Abschnitt 1), das Setup-Skript muss das nicht tun.

**Netzwerkzugriff der Umgebung: „Unbegrenzt“** (oder `hotel-vaikuntha.de` in der eigenen Liste). Mit
„Vertraut“ blockt der Proxy der Umgebung die Rezeption mit `CONNECT 403` (gemessen 14.09.2026).

**Repo als Quelle, nicht selbst klonen:** Das Repo `john-agent` muss in der Routine als Quelle stehen. Klont die
Session es selbst, stuft der Klassifizierer `rezeption.sh` als „Code from External“ ein und verweigert den Aufruf.

Debian-Python hat ein eigenes PyJWT, deshalb das venv (derselbe Stolperstein wie in flow-cockpit,
`docs/memanto.md` dort).

## Repos an der Umgebung

| Repo | Pflicht | Inhalt |
|---|---|---|
| `benediktirsch-rgb/john-agent` | ja | dieses Repo: Skript, Takt, Protokoll |
| `benediktirsch-rgb/john` (privat, neu) | empfohlen | Persona `CLAUDE.md`, `profil/`, `coaching/` aus `C:\dev\john` |

Ohne das private Repo denkt die Wolke mit `wissen/zweck.md` und dem Gedächtnis, sagt das aber bei jedem
Takt im Logbuch. Das Repo `john` muss **privat** bleiben; die Pipeline enthält Namen.

## Konnektoren der Routine

Die Routine bekommt nur die Konnektoren, die Bene ihr ausdrücklich gibt. Für Johns Zweck sinnvoll:
Gmail (lesen), Google Kalender (lesen), Atlassian (nur wenn `board`-Aufträge in der Wolke laufen sollen).
Ohne Konnektoren erledigt die Wolke `frage`, `chat`, `coach` und den Stapel aus Rezeption und Gedächtnis.

## Die Routine

Name „John · wolke“, jede volle Stunde Mo–Fr 06:00–20:00 Berlin (Cron in UTC: `0 4-18 * * 1-5` im
Sommer, `0 5-19 * * 1-5` im Winter — beim Zeitumstellen anpassen, die Routine kennt keine Zeitzone).
Jede Auslösung: neue Session, Auftrag = `geraet-wolke/TAKT.md`. Pausieren: Routine deaktivieren, John
läuft dann nur noch auf dem Rechner.

## Prüfen, ob die Wolke lebt

```bash
curl -s -H "X-John-Token: $JOHN_HUB_TOKEN" "https://hotel-vaikuntha.de/john/api.php?w=stand" | python3 -c 'import json,sys; d=json.load(sys.stdin); print([(g["name"],g["wach"],g["takt"]) for g in d["geraete"]])'
```

Erwartet nach dem ersten Takt: `("wolke", True|False, "<iso>")` neben `vishnu-master`. `wach` ist nur
während der Session wahr (Puls älter als 180 s gilt als schlafend); der **Takt** ist die Zahl, die zählt.

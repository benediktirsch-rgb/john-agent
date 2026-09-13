#!/usr/bin/env bash
# rezeption.sh — Johns Rezeption vom Gerät „wolke“ aus ansprechen (12.09.2026)
#
# Warum es diese Datei gibt: Bene will John aus vishnu-master heraus haben („nutze die
# Infrastruktur“). Das Gerät „wolke“ ist eine Claude-Code-Session in der Cloud, die eine
# Routine stündlich startet (docs/adr/0006-geraet-wolke.md). Sie spricht dasselbe Protokoll
# wie john-worker.ps1 (docs/protokoll.md), nur ohne PowerShell: bash, curl, python3.
#
# Aufrufe:
#   rezeption.sh stand                                  wie geht es John?
#   rezeption.sh puls [<takt-iso>] [<notiz>]            Lebenszeichen, optional mit Taktzeit
#   rezeption.sh auftraege                              offene Aufträge (älteste zuerst)
#   rezeption.sh nimm <id>                              Auftrag beanspruchen (409 = anderes Gerät war schneller)
#   rezeption.sh ergebnis <id> <ok|fehler> <notiz> [<textdatei>]
#   rezeption.sh log <art> <text>                       Logbuch (nur Betrieb, nie Inhalt)
#   rezeption.sh stapel <json-datei>                    {"stand":"<iso>","punkte":[…]} — nur wenn neuer
#   rezeption.sh punkt <id> <ok|aktion|spaeter> [<notiz>]
#
# Antwort immer als JSON auf stdout; Exit 0 bei ok, 1 bei Fehler der Rezeption, 3 wenn nicht
# angebunden (JOHN_HUB_TOKEN fehlt). „Leer heißt nie nichts“: auch der Abbruch nennt den Grund.
set -euo pipefail

HUB="${JOHN_HUB_URL:-https://hotel-vaikuntha.de/john}"
HUB="${HUB%/}"
GERAET="${JOHN_GERAET:-wolke}"
TOKEN="${JOHN_HUB_TOKEN:-}"
VERSION="wolke-0.1.0"

was="${1:-}"
if [ -z "$was" ] || [ "$was" = "-h" ] || [ "$was" = "--help" ]; then
  sed -n '2,20p' "$0"; exit 2
fi
if [ -z "$TOKEN" ]; then
  printf '{"ok":false,"grund":"nicht angebunden","fehler":"JOHN_HUB_TOKEN fehlt (Umgebungsvariable der Cloud-Umgebung, siehe geraet-wolke/umgebung.md)"}\n'
  exit 3
fi

# json <python-ausdruck> — baut den Anfragekörper sicher, statt Anführungszeichen von Hand zu setzen.
json() { python3 -c 'import json,sys; print(json.dumps(eval(sys.argv[1]), ensure_ascii=False))' "$1"; }

# ruf <GET|POST> <w> [körper] — druckt die Antwort, Exit ≠ 0 bei HTTP ≥ 400.
ruf() {
  local m="$1" w="$2" body="${3:-}" out code
  if [ "$m" = "POST" ]; then
    out=$(curl -sS --max-time 25 -w '\n%{http_code}' -H "X-John-Token: $TOKEN" -H 'Content-Type: application/json' \
          -X POST --data-binary "$body" "$HUB/api.php?w=$w") || { printf '{"ok":false,"grund":"rezeption nicht erreichbar","hub":"%s"}\n' "$HUB"; return 1; }
  else
    out=$(curl -sS --max-time 25 -w '\n%{http_code}' -H "X-John-Token: $TOKEN" "$HUB/api.php?w=$w") \
      || { printf '{"ok":false,"grund":"rezeption nicht erreichbar","hub":"%s"}\n' "$HUB"; return 1; }
  fi
  code="${out##*$'\n'}"
  printf '%s\n' "${out%$'\n'*}"
  [ "${code:-500}" -lt 400 ]
}

jetzt() { date +%Y-%m-%dT%H:%M:%S%:z; }

case "$was" in
  stand)
    ruf GET stand ;;
  puls)
    takt="${2:-}"; notiz="${3:-Wolke: Claude-Code-Routine}"
    body=$(T="$takt" N="$notiz" G="$GERAET" V="$VERSION" python3 -c 'import json,os; print(json.dumps({"geraet":os.environ["G"],"version":os.environ["V"],"kann":["takt","frage","chat","coach","stapel"],"notiz":os.environ["N"][:200],"takt":(os.environ["T"] or None)}, ensure_ascii=False))')
    ruf POST puls "$body" ;;
  auftraege)
    ruf GET auftraege ;;
  nimm)
    [ -n "${2:-}" ] || { echo '{"ok":false,"fehler":"id fehlt"}'; exit 2; }
    body=$(I="$2" G="$GERAET" python3 -c 'import json,os; print(json.dumps({"id":os.environ["I"],"geraet":os.environ["G"]}))')
    ruf POST nimm "$body" ;;
  ergebnis)
    [ -n "${2:-}" ] && [ -n "${3:-}" ] || { echo '{"ok":false,"fehler":"id und ok|fehler nötig"}'; exit 2; }
    text=""; [ -n "${5:-}" ] && text=$(cat "$5")
    body=$(I="$2" O="$3" N="${4:-}" X="$text" python3 -c 'import json,os; print(json.dumps({"id":os.environ["I"],"ok":os.environ["O"]=="ok","notiz":os.environ["N"][:300],"text":os.environ["X"][:4000]}, ensure_ascii=False))')
    ruf POST ergebnis "$body" ;;
  log)
    [ -n "${3:-}" ] || { echo '{"ok":false,"fehler":"art und text nötig"}'; exit 2; }
    body=$(A="$2" X="$3" G="$GERAET" python3 -c 'import json,os; print(json.dumps({"art":os.environ["A"],"text":os.environ["X"][:300],"geraet":os.environ["G"]}, ensure_ascii=False))')
    ruf POST log "$body" ;;
  stapel)
    [ -f "${2:-}" ] || { echo '{"ok":false,"fehler":"json-datei mit stand und punkte nötig"}'; exit 2; }
    body=$(F="$2" G="$GERAET" python3 -c 'import json,os; d=json.load(open(os.environ["F"],encoding="utf-8")); d.setdefault("quelle",os.environ["G"]); print(json.dumps(d, ensure_ascii=False))')
    ruf POST stapel "$body" ;;
  punkt)
    [ -n "${2:-}" ] && [ -n "${3:-}" ] || { echo '{"ok":false,"fehler":"id und ok|aktion|spaeter nötig"}'; exit 2; }
    body=$(I="$2" T="$3" N="${4:-}" G="$GERAET" python3 -c 'import json,os; print(json.dumps({"id":os.environ["I"],"tat":os.environ["T"],"wer":os.environ["G"],"notiz":os.environ["N"][:200]}, ensure_ascii=False))')
    ruf POST punkt "$body" ;;
  *)
    printf '{"ok":false,"fehler":"unbekannt: %s (stand, puls, auftraege, nimm, ergebnis, log, stapel, punkt)"}\n' "$was"; exit 2 ;;
esac

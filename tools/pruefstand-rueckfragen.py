r"""Pruefstand Rueckfragen der Rezeption (16.09.2026) — lokal, mit erfundenen Schluesseln.

Aufbau (einmal, in einem leeren Ordner <pruef>):
  1. hub/api.php nach <pruef>/api.php kopieren, <pruef>/daten/ anlegen (leer).
  2. <pruef>/token.php mit den SHA-256 dieser vier Test-Schluessel:
       return ['hash' => sha256('g-test'), 'hash_browser' => sha256('b-test'),
               'geraete' => ['vishnu-master' => sha256('v-test')],
               'berater' => ['madelene' => sha256('m-test')]];
  3. C:\dev\_tools\php\php.exe -S 127.0.0.1:18766 -t <pruef>
  4. python tools/pruefstand-rueckfragen.py [http://127.0.0.1:18766/api.php]
Vor jedem Lauf <pruef>/daten/*.json loeschen — der Test erwartet einen leeren Stand.
Nie gegen die echte Rezeption laufen lassen: er legt Probefragen an und beantwortet sie.
"""
import json
import sys
import urllib.request
import urllib.error

BASIS = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:18766/api.php'
G, B, V, M = 'g-test', 'b-test', 'v-test', 'm-test'
ok = fehl = 0


def ruf(w, tok, body=None, q=''):
    url = f'{BASIS}?w={w}{q}'
    daten = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=daten, method='POST' if body is not None else 'GET')
    if tok:
        req.add_header('X-John-Token', tok)
    req.add_header('Content-Type', 'application/json')
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or '{}')


def pruef(name, bed, info=''):
    global ok, fehl
    if bed:
        ok += 1
        print('  ok  ', name)
    else:
        fehl += 1
        print('  FEHL', name, info)


frage = {'id': 'madelene-probe-1', 'projekt': 'Madelene · Probe', 'frage': 'Probe?', 'warum': 'Test',
         'optionen': ['Ja', 'Nein'], 'wann': '2026-09-16'}

c, d = ruf('rueckfragen', M); pruef('Beraterin liest (leer)', c == 200 and d['rueckfragen'] == [], (c, d))
c, d = ruf('rueckfrage', M, frage); pruef('Beraterin legt an', c == 200 and d.get('status') == 'offen', (c, d))
c, d = ruf('rueckfrage', M, dict(frage, id='probe-ohne-name')); pruef('Beraterin: id ohne eigenen Namen -> 400', c == 400, (c, d))
c, d = ruf('rueckfrage', M, dict(frage, von='claude', id='madelene-probe-2')); pruef('Beraterin: von im Koerper ignoriert', c == 200, (c, d))
c, d = ruf('rueckfragen', G, q='&von=madelene'); pruef('Geraet sieht beide unter madelene', c == 200 and len(d['rueckfragen']) == 2 and all(x['von'] == 'madelene' for x in d['rueckfragen']), (c, d))
c, d = ruf('rueckfrage-antwort', M, {'id': 'madelene-probe-1', 'a': 'Ja'}); pruef('Beraterin darf nicht antworten -> 403', c == 403, (c, d))
c, d = ruf('puls', M, {'geraet': 'madelene'}); pruef('Beraterin ist kein Geraet (puls) -> 403', c == 403, (c, d))
c, d = ruf('nimm', M, {'id': 'x'}); pruef('Beraterin: nimm -> 403', c == 403, (c, d))
c, d = ruf('auftrag', M, {'art': 'frage', 'text': 'x'}); pruef('Beraterin: auftrag -> 403', c == 403, (c, d))
c, d = ruf('rueckfrage', B, frage); pruef('Browser darf nicht anlegen -> 403', c == 403, (c, d))
c, d = ruf('rueckfragen', B); pruef('Browser liest offene', c == 200 and len(d['rueckfragen']) == 2, (c, d))
c, d = ruf('rueckfrage-antwort', B, {'id': 'madelene-probe-1', 'a': 'Ja', 'ts': '2026-09-16', 'wer': 'compass'}); pruef('Browser antwortet', c == 200 and d.get('status') == 'beantwortet', (c, d))
c, d = ruf('rueckfrage-antwort', B, {'id': 'madelene-probe-1', 'a': 'Ja'}); pruef('gleiche Antwort nochmal -> unveraendert', c == 200 and d.get('unveraendert'), (c, d))
c, d = ruf('rueckfragen', M, q='&status=beantwortet'); pruef('Beraterin liest Antwort', c == 200 and d['rueckfragen'][0]['antwort']['a'] == 'Ja' and d['rueckfragen'][0]['antwort']['wer'] == 'compass', (c, d))
c, d = ruf('rueckfrage', M, frage); pruef('beantwortete aendern -> 409', c == 409, (c, d))
c, d = ruf('rueckfrage', G, {'id': 'claude-probe-1', 'frage': 'Claude fragt?', 'optionen': ['A']}); pruef('Geraet legt an (von=claude)', c == 200, (c, d))
c, d = ruf('rueckfrage', M, {'id': 'claude-probe-1', 'zurueckziehen': True}); pruef('Beraterin zieht fremde nicht zurueck', c in (400, 403), (c, d))
c, d = ruf('rueckfrage', V, {'id': 'claude-probe-1', 'zurueckziehen': True}); pruef('gebundenes Geraet zieht claude-Frage zurueck', c == 200 and d.get('status') == 'zurueckgezogen', (c, d))
c, d = ruf('rueckfrage-antwort', B, {'id': 'claude-probe-1', 'a': 'A'}); pruef('Antwort auf zurueckgezogene -> 409', c == 409, (c, d))
c, d = ruf('rueckfrage-antwort', B, {'id': 'gibt-es-nicht', 'a': 'A'}); pruef('Antwort auf unbekannte -> 404', c == 404, (c, d))
c, d = ruf('rueckfrage', M, dict(frage, id='madelene-probe-2', frage='Probe geaendert?')); pruef('Beraterin aendert eigene offene', c == 200, (c, d))
for i in range(3, 8):
    c, d = ruf('rueckfrage', M, dict(frage, id=f'madelene-probe-{i}'))
pruef('Grenze 5 offene je Beraterin -> 409', c == 409, (c, d))
c, d = ruf('stand', M); pruef('stand zeigt Zaehlung', c == 200 and d['rueckfragen']['von'].get('madelene') == 5, (c, d.get('rueckfragen')))
pruef('Beraterin sieht keinen Stapel, keinen Spiegel, kein Logbuch', d.get('sicht') == 'beraterin' and not any(k in d for k in ('stapel','compass','raeume','log')), list(d))
c, d = ruf('rueckfragen', M, q='&status=quatsch'); pruef('falscher status -> 400', c == 400, (c, d))
c, d = ruf('rueckfragen', None); pruef('ohne Schluessel -> 403', c == 403, (c, d))
c, d = ruf('rueckfragen', M, q='&seit=2099-01-01T00:00:00%2B02:00'); pruef('seit in der Zukunft -> leer', c == 200 and d['rueckfragen'] == [], (c, d))
c, d = ruf('rueckfrage', V, {'id': 'claude-link', 'frage': 'Link?', 'link': 'javascript:alert(1)'}); pruef('fremdes Linkschema wird verworfen', c == 200, (c, d))
c, d = ruf('rueckfragen', G, q='&von=claude'); pruef('... und steht als null da', c == 200 and [x for x in d['rueckfragen'] if x['id'] == 'claude-link'][0]['link'] is None, (c, d))
c, d = ruf('log', M, {'art': 'hinweis', 'text': 'Probe'}); pruef('Beraterin schreibt Logzeile', c == 200, (c, d))
c, d = ruf('log', M, {'art': 'hinweis', 'text': 'Probe', 'geraet': 'vishnu-master'}); pruef('Beraterin gibt sich nicht als Geraet aus -> 403', c == 403, (c, d))
c, d = ruf('stand', G); log = [x for x in d['log'] if x['art'] == 'rueckfrage']
pruef('Logbuch nennt nur id und von, nie den Fragetext', log and all('Probe?' not in x['text'] for x in log), log)
print(f'\n{ok} ok, {fehl} fehlgeschlagen')
sys.exit(1 if fehl else 0)

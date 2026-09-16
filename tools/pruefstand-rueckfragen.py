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

Geprueft wird, was Bene am 16.09.2026 ausdruecklich verlangt hat:
  A  Madelenes Schluessel liest nur ihre eigenen Fragen und die zugehoerigen Antworten
  B  sie schreibt keine Antworten und tritt nicht als Geraet auf
  C  Wiederholungen nach Verbindungsfehlern erzeugen keine doppelten Fragen
  D  Grenzen, Eingaben, Logbuch ohne Inhalte und ohne Schluessel
(Widerruf und Ersatz des Schluessels: docs/madelene-compass.md, Abschnitt 8.)
"""
import json
import sys
import threading
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
        with urllib.request.urlopen(req, timeout=15) as r:
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


def frage(i, **mehr):
    f = {'id': f'madelene-probe-{i}', 'projekt': 'Madelene · Probe', 'frage': f'Probe {i}?', 'warum': 'Test',
         'optionen': ['Ja', 'Nein'], 'wann': '2026-09-16'}
    f.update(mehr)
    return f


print('Vorbereitung: Claude (Geraet) fragt auch')
c, d = ruf('rueckfrage', G, {'id': 'claude-probe-1', 'frage': 'Vertrauliche Claude-Frage?', 'warum': 'Name und Betrag', 'optionen': ['A', 'B']})
pruef('Geraet legt eine Claude-Frage an', c == 200, (c, d))
c, d = ruf('rueckfrage-antwort', B, {'id': 'claude-probe-1', 'a': 'A', 'wer': 'compass'})
pruef('Bene beantwortet sie im Compass', c == 200, (c, d))

print('A  nur eigene Fragen')
c, d = ruf('rueckfragen', M, q='&status=alle'); pruef('Beraterin sieht Claudes Frage nicht', c == 200 and d['rueckfragen'] == [], (c, d))
c, d = ruf('rueckfragen', M, q='&status=alle&von=claude'); pruef('Beraterin: fremdes von -> 403', c == 403, (c, d))
c, d = ruf('rueckfragen', M, q='&status=beantwortet'); pruef('Beraterin sieht Benes Antwort an Claude nicht', c == 200 and d['rueckfragen'] == [], (c, d))
c, d = ruf('rueckfrage', M, frage(1)); pruef('Beraterin legt an', c == 200 and d.get('status') == 'offen', (c, d))
c, d = ruf('rueckfrage', M, frage(2, von='claude')); pruef('von im Koerper wird ignoriert', c == 200, (c, d))
c, d = ruf('rueckfragen', G, q='&von=madelene'); pruef('... und landet unter madelene', c == 200 and {x['id'] for x in d['rueckfragen']} == {'madelene-probe-1', 'madelene-probe-2'}, (c, d))
c, d = ruf('rueckfragen', M, q='&status=alle'); pruef('Beraterin sieht genau ihre zwei', c == 200 and sorted(x['id'] for x in d['rueckfragen']) == ['madelene-probe-1', 'madelene-probe-2'], (c, d))
c, d = ruf('rueckfrage', M, {'id': 'claude-probe-1', 'zurueckziehen': True}); pruef('Claudes id zurueckziehen -> abgewiesen (400)', c == 400, (c, d))
c, d = ruf('rueckfrage', M, dict(frage(9), id='claude-probe-1')); pruef('Claudes id ueberschreiben -> abgewiesen (400)', c == 400, (c, d))
c, d = ruf('rueckfrage', G, {'id': 'madelene-geraet-1', 'frage': 'Geraet mit fremd klingender id?'}); pruef('(Geraet belegt eine madelene-id)', c == 200, (c, d))
c, d = ruf('rueckfrage', M, {'id': 'madelene-geraet-1', 'zurueckziehen': True}); pruef('belegte id: 409 ohne Eigentuemer', c == 409 and 'claude' not in json.dumps(d), (c, d))
c, d = ruf('rueckfrage', M, dict(frage(9), id='madelene-geraet-1')); pruef('belegte id ueberschreiben: 409', c == 409, (c, d))
c, d = ruf('rueckfrage', G, {'id': 'madelene-geraet-1', 'zurueckziehen': True}); pruef('(Geraet raeumt sie wieder weg)', c == 200, (c, d))
c, d = ruf('rueckfragen', G, q='&von=claude&status=alle'); pruef('Claudes Frage unveraendert', c == 200 and d['rueckfragen'][0]['frage'] == 'Vertrauliche Claude-Frage?', (c, d))
c, d = ruf('rueckfrage', M, frage(3, id='probe-ohne-name')); pruef('id ohne eigenen Namen -> 400', c == 400, (c, d))
c, d = ruf('stand', M)
pruef('stand: nur eigene Zahl, kein Stapel/Spiegel/Logbuch', c == 200 and d.get('sicht') == 'beraterin' and d.get('rueckfragen') == {'offen': 2}
      and not any(k in d for k in ('stapel', 'compass', 'raeume', 'log')), (c, d))

print('B  keine Antworten, kein Geraet')
c, d = ruf('rueckfrage-antwort', M, {'id': 'madelene-probe-1', 'a': 'Ja'}); pruef('eigene Frage beantworten -> 403', c == 403, (c, d))
c, d = ruf('rueckfrage-antwort', M, {'id': 'claude-probe-1', 'a': 'B'}); pruef('fremde Frage beantworten -> 403', c == 403, (c, d))
for w, body in [('puls', {'geraet': 'madelene'}), ('nimm', {'id': 'x', 'geraet': 'madelene'}), ('ergebnis', {'id': 'x'}),
                ('auftrag', {'art': 'frage', 'text': 'x'}), ('stapel', {'stand': '2026-09-16T10:00:00+02:00'}),
                ('spiegel', {}), ('stapelstand', {'key': 'k', 'status': 'ok', 'ts': 'x'}), ('punkt', {'id': 'x', 'tat': 'ok'}),
                ('stopp', {'id': 'x'})]:
    c, d = ruf(w, M, body); pruef(f'{w} -> 403', c == 403, (c, d))
c, d = ruf('auftraege', M); pruef('auftraege -> 403', c == 403, (c, d))
c, d = ruf('log', M, {'art': 'hinweis', 'text': 'Probe', 'geraet': 'vishnu-master'}); pruef('als Geraet ins Logbuch -> 403', c == 403, (c, d))
c, d = ruf('log', M, {'art': 'hinweis', 'text': 'Probe'}); pruef('Logzeile unter eigenem Namen erlaubt', c == 200, (c, d))
c, d = ruf('rueckfrage', B, frage(4)); pruef('Browser legt nicht an -> 403', c == 403, (c, d))

print('C  Wiederholen erzeugt nichts doppelt')
c, d = ruf('rueckfragen', G, q='&von=madelene'); vorher = {x['id']: x['geaendert'] for x in d['rueckfragen']}
c, d = ruf('rueckfrage', M, frage(1)); pruef('gleicher Koerper nochmal -> unveraendert', c == 200 and d.get('unveraendert') is True, (c, d))
c, d = ruf('rueckfragen', G, q='&von=madelene')
pruef('kein zweiter Eintrag, geaendert nicht verschoben', len(d['rueckfragen']) == 2 and vorher['madelene-probe-1'] == {x['id']: x['geaendert'] for x in d['rueckfragen']}['madelene-probe-1'], d)
ergebnisse = []


def parallel():
    ergebnisse.append(ruf('rueckfrage', M, frage(5)))


fs = [threading.Thread(target=parallel) for _ in range(8)]
[f.start() for f in fs]
[f.join() for f in fs]
c, d = ruf('rueckfragen', G, q='&von=madelene')
pruef('8 gleichzeitige Sendungen derselben id -> ein Eintrag', sum(1 for x in d['rueckfragen'] if x['id'] == 'madelene-probe-5') == 1 and all(r[0] == 200 for r in ergebnisse), ergebnisse)
c, d = ruf('rueckfrage', M, frage(5, frage='Probe 5 geaendert?')); pruef('geaenderter Wortlaut -> aktualisiert', c == 200 and not d.get('unveraendert'), (c, d))
c, d = ruf('rueckfrage-antwort', B, {'id': 'madelene-probe-1', 'a': 'Ja', 'ts': '2026-09-16', 'wer': 'compass'}); pruef('Bene antwortet', c == 200, (c, d))
c, d = ruf('rueckfrage-antwort', B, {'id': 'madelene-probe-1', 'a': 'Ja'}); pruef('Antwort wiederholt -> unveraendert', c == 200 and d.get('unveraendert'), (c, d))
c, d = ruf('rueckfrage', M, frage(1)); pruef('Frage nach der Antwort wiederholt -> 409 (angekommen)', c == 409, (c, d))
c, d = ruf('rueckfragen', M, q='&status=beantwortet'); pruef('Beraterin liest ihre Antwort', c == 200 and d['rueckfragen'][0]['antwort']['a'] == 'Ja', (c, d))

print('D  Grenzen, Eingaben, Logbuch')
c, d = ruf('rueckfrage', M, frage(6, dringend=True)); pruef('eine dringende', c == 200, (c, d))
c, d = ruf('rueckfrage', M, frage(7, dringend=True)); pruef('zweite dringende -> 409', c == 409, (c, d))
c, d = ruf('rueckfrage', M, frage(2, dringend=True)); pruef('bestehende zur zweiten dringenden machen -> 409', c == 409, (c, d))
c, d = ruf('rueckfrage', M, frage(7)); pruef('vierte offene', c == 200, (c, d))
c, d = ruf('rueckfrage', M, frage(8)); pruef('fuenfte offene', c == 200, (c, d))
c, d = ruf('rueckfrage', M, frage(10)); pruef('sechste offene -> 409', c == 409, (c, d))
c, d = ruf('rueckfrage', M, frage(8)); pruef('Wiederholung der fuenften trotz voller Grenze -> ok', c == 200 and d.get('unveraendert'), (c, d))
c, d = ruf('rueckfrage', M, {'id': 'madelene-probe-8', 'zurueckziehen': True}); pruef('zurueckziehen', c == 200 and d['status'] == 'zurueckgezogen', (c, d))
c, d = ruf('rueckfrage-antwort', B, {'id': 'madelene-probe-8', 'a': 'Ja'}); pruef('Antwort auf zurueckgezogene -> 409', c == 409, (c, d))
c, d = ruf('rueckfrage-antwort', B, {'id': 'gibt-es-nicht', 'a': 'A'}); pruef('Antwort auf unbekannte -> 404', c == 404, (c, d))
c, d = ruf('rueckfragen', M, q='&status=quatsch'); pruef('falscher status -> 400', c == 400, (c, d))
c, d = ruf('rueckfragen', None); pruef('ohne Schluessel -> 403', c == 403, (c, d))
c, d = ruf('rueckfragen', 'm-falsch'); pruef('falscher Schluessel -> 403', c == 403, (c, d))
c, d = ruf('rueckfragen', M, q='&seit=2099-01-01T00:00:00%2B02:00'); pruef('seit in der Zukunft -> leer', c == 200 and d['rueckfragen'] == [], (c, d))
c, d = ruf('rueckfrage', V, {'id': 'claude-link', 'frage': 'Link?', 'link': 'javascript:alert(1)'}); pruef('fremdes Linkschema angenommen ...', c == 200, (c, d))
c, d = ruf('rueckfragen', G, q='&von=claude'); pruef('... aber als null gespeichert', [x for x in d['rueckfragen'] if x['id'] == 'claude-link'][0]['link'] is None, d)
c, d = ruf('stand', G); log = [x for x in d['log'] if x['art'] == 'rueckfrage']
pruef('Logbuch nennt nur id und von, nie Frage oder Antwort', log and all('Probe' not in x['text'] and 'Vertraulich' not in x['text'] for x in log), log)
pruef('Antworten der Rezeption enthalten keinen Schluessel', all(t not in json.dumps(d) for t in (G, B, V, M)), '')
print('E  Freigaben pro Frage (Bene 16.09.2026: nur pro Frage, Vorschau, 30 Tage)')
fg = {'fuer': 'madelene', 'bezug': 'claude-probe-1', 'frage': 'Wie gehen wir beim Holodeck vor?', 'antwort': 'Variante B'}
c, d = ruf('freigabe', M, fg); pruef('Beraterin kann nichts freigeben -> 403', c == 403, (c, d))
c, d = ruf('freigabe', B, dict(fg, notiz='Budget 5.000 € bis Oktober')); pruef('Betrag im Text -> 422 mit Muster', c == 422 and 'betrag' in d.get('muster', []), (c, d))
c, d = ruf('freigabe', B, dict(fg, notiz='Frag bei jemand@example.org nach')); pruef('Mailadresse -> 422', c == 422 and 'mail' in d.get('muster', []), (c, d))
c, d = ruf('freigabe', B, dict(fg, notiz='IBAN DE89 3704 0044 0532 0130 00')); pruef('IBAN -> 422', c == 422 and 'iban' in d.get('muster', []), (c, d))
c, d = ruf('freigabe', B, dict(fg, notiz='Ruf an: 0171 2345678')); pruef('Telefonnummer -> 422', c == 422 and 'telefon' in d.get('muster', []), (c, d))
c, d = ruf('freigabe', B, dict(fg, notiz='Stand 2026-09-16, Frage E09, Kapitel 3')); pruef('Datum und Kennungen sind kein Treffer', c == 200, (c, d))
fg_id = d.get('id')
c, d = ruf('freigabe', B, dict(fg, antwort='Variante C')); pruef('gleiche Frage nochmal -> erneuert, gleiche id', c == 200 and d.get('erneuert') and d.get('id') == fg_id, (c, d))
c, d = ruf('freigabe', G, {'fuer': 'madelene', 'frage': 'Budget?', 'notiz': '12k fuer Q4', 'trotzdem': True, 'tage': 99})
pruef('trotzdem -> angenommen, Laufzeit auf 30 Tage gedeckelt', c == 200 and d.get('bis', '9') <= __import__('datetime').date.fromordinal(__import__('datetime').date.today().toordinal() + 30).isoformat(), (c, d))
fg_trotz = d.get('id')
c, d = ruf('freigabe', B, {'fuer': 'jemand-anders', 'frage': 'Nur fuer jemand anderen?'}); pruef('Freigabe fuer eine andere Person', c == 200, (c, d))
c, d = ruf('freigaben', M, q='&fuer=jemand-anders'); ids = [x['id'] for x in d.get('freigaben', [])]
pruef('Beraterin sieht nur ihre Freigaben (fuer wird ignoriert)', c == 200 and len(ids) == 2 and all(x['fuer'] == 'madelene' for x in d['freigaben']), (c, d))
pruef('... mit dem Text aus der Vorschau', any(x.get('antwort') == 'Variante C' for x in d['freigaben']), d)
c, d = ruf('freigaben', B); pruef('Browser sieht alle drei', c == 200 and len(d['freigaben']) == 3, (c, d))
c, d = ruf('freigabe', B, {'id': fg_trotz, 'widerrufen': True}); pruef('Widerruf', c == 200 and d.get('widerrufen'), (c, d))
c, d = ruf('freigabe', B, {'id': fg_trotz, 'widerrufen': True}); pruef('zweiter Widerruf -> 404 (geloescht, nicht versteckt)', c == 404, (c, d))
c, d = ruf('freigaben', M); pruef('Beraterin sieht die widerrufene nicht mehr', c == 200 and [x['id'] for x in d['freigaben']] == [fg_id], (c, d))
c, d = ruf('freigabe', B, {'fuer': 'Madelene!', 'frage': 'x'}); pruef('ungueltiger Name -> 400', c == 400, (c, d))
c, d = ruf('rueckfrage', M, frage(11, bezug=['claude-probe-1', 'Kaputt!!', 'x'])); pruef('Beraterin bittet um Kontext (bezug)', c == 200, (c, d))
c, d = ruf('rueckfragen', M); b = [x for x in d['rueckfragen'] if x['id'] == 'madelene-probe-11']
pruef('bezug nur mit gueltigen ids gespeichert', b and b[0].get('bezug') == ['claude-probe-1'], b)

print('F  Gemeinsames Gedaechtnis (eine Madelene, zwei Laufwege)')
c, d = ruf('gedaechtnis', M, {'text': 'Holodeck: Bene will erst die Brücke fertig sehen.', 'thema': 'Holodeck'}); pruef('Astra schreibt', c == 200 and d.get('id'), (c, d))
c, d = ruf('gedaechtnis', M, {'text': 'Holodeck: Bene will erst die Brücke fertig sehen.'}); pruef('gleicher Satz -> unveraendert', c == 200 and d.get('unveraendert'), (c, d))
c, d = ruf('gedaechtnis', M, {'text': 'Konto DE89 3704 0044 0532 0130 00 pruefen'}); pruef('Vertrauliches -> 422', c == 422, (c, d))
c, d = ruf('gedaechtnis', V, {'fuer': 'madelene', 'text': 'Lokal: Frist fuer die Umsatzsteuer liegt beim Steuerbuero.'}); pruef('lokale Laufzeit (Geraet) schreibt', c == 200, (c, d))
c, d = ruf('gedaechtnis', B, {'fuer': 'madelene', 'text': 'Browser?'}); pruef('Browser schreibt nicht -> 403', c == 403, (c, d))
c, d = ruf('gedaechtnis', M, q='&fuer=jemand-anders'); vons = sorted(x['von'] for x in d.get('eintraege', []))
pruef('Beraterin liest beide Laufwege, nur ihr eigenes Gedaechtnis', c == 200 and d.get('fuer') == 'madelene' and vons == ['astra', 'lokal:vishnu-master'], (c, d))
c, d = ruf('gedaechtnis', G); pruef('Geraet ohne fuer -> 400', c == 400, (c, d))
c, d = ruf('gedaechtnis', B, q='&fuer=madelene'); pruef('Browser liest', c == 200 and len(d['eintraege']) == 2, (c, d))

print('G  Persona')
c, d = ruf('persona', M); pruef('noch keine Persona -> 404', c == 404, (c, d))
c, d = ruf('persona', M, {'text': 'Ich bin jemand anders.'}); pruef('Beraterin laedt nichts hoch -> 403', c == 403, (c, d))
c, d = ruf('persona', B, q='&fuer=madelene'); pruef('Browser -> 403', c == 403, (c, d))
c, d = ruf('persona', V, {'fuer': 'madelene', 'text': 'Du bist Madelene. Schreib an madelene@example.org'}); pruef('Persona mit Adresse -> 422', c == 422, (c, d))
c, d = ruf('persona', V, {'fuer': 'madelene', 'text': '# Madelene\nDu bist Madelene, zahlenfest und ehrlich.'}); pruef('Geraet laedt Persona hoch', c == 200, (c, d))
c, d = ruf('persona', M, q='&fuer=jemand-anders'); pruef('Beraterin liest ihre Persona', c == 200 and d.get('fuer') == 'madelene' and 'zahlenfest' in d.get('text', ''), (c, d))

c, d = ruf('stand', G); log = [x for x in d['log'] if x['art'] in ('freigabe', 'gedaechtnis', 'persona')]
pruef('Logbuch nennt Freigaben, Gedaechtnis und Persona ohne Inhalt', log and all('Holodeck' not in x['text'] and 'Variante' not in x['text'] and 'zahlenfest' not in x['text'] for x in log), log)
print(f'\n{ok} ok, {fehl} fehlgeschlagen')
sys.exit(1 if fehl else 0)

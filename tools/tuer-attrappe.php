<?php
/*
  tuer-attrappe.php — die Tür des Workers zum Entwickeln, ohne Benes Rechner (11.09.2026)

  Für wen: für die Oberfläche des Gesprächsraums (Astra, oder wer sonst am Compass baut). Die echte Tür
  (geraet/john-worker.ps1, Port 8788) läuft nur auf Benes Rechner, weil dort der Text liegt und die Modelle
  über seine Abos denken. Diese Datei spricht denselben Vertrag (docs/protokoll.md › Gesprächsraum ›
  Tür des Workers) mit gespielten Antworten — keine Modelle, keine Rezeption, kein Wissen.

  Start:   php -S 127.0.0.1:8788 tuer-attrappe.php
  Dann im Compass window.JOHN_TUER = 'http://127.0.0.1:8788' (der Standard).

  Gespielt wird: jeder Sprecher „denkt" DENK_S Sekunden, bei „beide" erst John, dann Madeleine.
  Enthält Benes Text das Wort „fehler", scheitert der Zug mit einer system-Zeile (so sieht die
  Oberfläche auch diesen Fall). Zustand in sys_get_temp_dir()/tuer-attrappe/, löschen = zurücksetzen.
*/
declare(strict_types=1);
date_default_timezone_set('Europe/Berlin');   // wie Rezeption und Gerät
const DENK_S = 4;
$ORDNER = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'tuer-attrappe';
if (!is_dir($ORDNER)) mkdir($ORDNER, 0777, true);

function antwort(array $d, int $code = 200): void {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($d, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
function jetzt(): string { return date('c'); }

// Herkunft wie an der echten Tür: fremde Seiten 403, eigene bekommen genau ihre Herkunft zurück.
$herkunft = $_SERVER['HTTP_ORIGIN'] ?? '';
$erlaubt = $herkunft === '' || $herkunft === 'https://bene.vishnuartists.com'
    || preg_match('~^https?://(localhost|127\.0\.0\.1)(:\d+)?$~', $herkunft);
header('Cache-Control: no-store');
header('Vary: Origin');
if ($herkunft !== '' && $erlaubt) {
    header("Access-Control-Allow-Origin: $herkunft");
    header('Access-Control-Allow-Headers: Content-Type');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Private-Network: true');
}
if (!$erlaubt) antwort(['ok' => false, 'fehler' => 'Diese Tür antwortet nur Benes eigenen Seiten.'], 403);
$methode = $_SERVER['REQUEST_METHOD'];
if ($methode === 'OPTIONS') { http_response_code(204); exit; }

$pfad = rtrim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?: '/', '/') ?: '/';
$handlung = in_array($pfad, ['/wecken', '/takt', '/stopp', '/raum/weitergeben', '/__stop'], true) || ($pfad === '/raum' && $methode !== 'GET');
if ($handlung && $methode !== 'POST') antwort(['ok' => false, 'fehler' => "$pfad nur per POST"], 405);
$koerper = json_decode(file_get_contents('php://input') ?: 'null', true) ?: [];

function datei(string $id): string { global $ORDNER; return $ORDNER . DIRECTORY_SEPARATOR . "$id.json"; }
function gueltig(string $id): bool { return (bool)preg_match('/^[a-z0-9-]{1,40}$/', $id); }
function laden(string $id): ?array { $f = datei($id); return is_file($f) ? json_decode((string)file_get_contents($f), true) : null; }
function sichern(array $r): void { file_put_contents(datei($r['id']), json_encode($r, JSON_UNESCAPED_UNICODE), LOCK_EX); }
function zug(array &$r, string $wer, string $text): int {
    $n = count($r['zuege']) ? max(array_column($r['zuege'], 'zug')) + 1 : 1;
    $r['zuege'][] = ['zug' => $n, 'wer' => $wer, 'zeit' => jetzt(), 'text' => $text, 'weitergeben' => true];
    return $n;
}
// Das „Denken": offene Sprecher der Reihe nach, je DENK_S Sekunden ab Beginn.
function weiterdenken(array &$r): void {
    $gespielt = [
        'john' => 'Ich bin John (Attrappe). Ich antworte auf: „%s"',
        'madeleine' => 'Ich bin Madeleine (Attrappe). Zahlen habe ich hier keine — nur den Vertrag. Zu: „%s"',
    ];
    while ($r['lauf']) {
        $l = $r['lauf'];
        if (time() - $l['beginn'] < DENK_S) return;
        $bene = '';
        foreach (array_reverse($r['zuege']) as $z) { if ($z['wer'] === 'bene') { $bene = $z['text']; break; } }
        if (stripos($bene, 'fehler') !== false) {
            zug($r, 'system', ($l['an'] === 'john' ? 'John' : 'Madeleine') . ' konnte nicht antworten: gespielter Fehler');
            $r['lauf'] = null; $r['rest'] = []; return;
        }
        zug($r, $l['an'], sprintf($gespielt[$l['an']], mb_substr($bene, 0, 80)));
        $naechster = array_shift($r['rest']);
        $r['lauf'] = $naechster ? ['an' => $naechster, 'beginn' => $l['beginn'] + DENK_S] : null;
    }
}
function sprecher(string $an): array { return $an === 'beide' ? ['john', 'madeleine'] : [$an]; }

switch ($pfad) {
case '/stand':
    antwort(['ok' => true, 'geraet' => 'attrappe', 'version' => 'attrappe', 'jetzt' => jetzt(), 'serverLaeuft' => true,
             'serverAntwortet' => true, 'serverOk' => true, 'denkt' => false, 'hub' => ['adresse' => null, 'offen' => 0, 'fehler' => '']]);
case '/raeume':
    $liste = [];
    foreach (glob(datei('*')) ?: [] as $f) {
        $r = json_decode((string)file_get_contents($f), true); weiterdenken($r); sichern($r);
        $letzter = end($r['zuege']);
        $liste[] = ['id' => $r['id'], 'thema' => $r['thema'], 'zuege' => count($r['zuege']),
                    'zuletzt' => $letzter ? $letzter['zeit'] : $r['erstellt'], 'laeuft' => (bool)$r['lauf'],
                    'wartet' => $r['lauf'] ? $r['rest'] : []];
    }
    usort($liste, fn($a, $b) => strcmp($b['zuletzt'], $a['zuletzt']));
    antwort(['ok' => true, 'raeume' => $liste]);
case '/raum':
    if ($methode === 'GET') {
        $id = (string)($_GET['id'] ?? ''); $seit = (int)($_GET['seit'] ?? 0);
        if (!gueltig($id)) antwort(['ok' => false, 'fehler' => 'id fehlt oder ist ungültig'], 400);
        $r = laden($id); if (!$r) antwort(['ok' => false, 'fehler' => "Raum $id gibt es nicht"], 404);
        weiterdenken($r); sichern($r);
        antwort(['ok' => true, 'id' => $id, 'thema' => $r['thema'],
                 'zuege' => array_values(array_filter($r['zuege'], fn($z) => $z['zug'] > $seit)),
                 'laeuft' => $r['lauf'] ? ['an' => $r['lauf']['an'], 'seit' => date('c', $r['lauf']['beginn'])] : null,
                 'wartet' => $r['rest']]);
    }
    $text = trim((string)($koerper['text'] ?? '')); $an = (string)($koerper['an'] ?? ''); $id = (string)($koerper['id'] ?? '');
    if ($text === '') antwort(['ok' => false, 'fehler' => 'text fehlt'], 400);
    if (mb_strlen($text) > 8000) antwort(['ok' => false, 'fehler' => 'text zu lang (höchstens 8000 Zeichen)'], 413);
    if (!in_array($an, ['john', 'madeleine', 'beide'], true)) antwort(['ok' => false, 'fehler' => 'an muss john, madeleine oder beide sein'], 400);
    if ($id !== '' && !gueltig($id)) antwort(['ok' => false, 'fehler' => 'id ist ungültig'], 400);
    if ($id === '') {
        $thema = trim((string)($koerper['thema'] ?? '')) ?: mb_substr(strtok($text, "\n"), 0, 60);
        $slug = trim(preg_replace('/[^a-z0-9]+/', '-', strtr(mb_strtolower($thema), ['ä' => 'ae', 'ö' => 'oe', 'ü' => 'ue', 'ß' => 'ss'])), '-');
        $id = substr($slug ?: 'raum', 0, 22) . '-' . date('md-Hi');
        $basis = $id; $i = 2; while (is_file(datei($id))) $id = $basis . '-' . $i++;
        $r = ['id' => $id, 'thema' => $thema, 'erstellt' => jetzt(), 'zuege' => [], 'lauf' => null, 'rest' => []];
    } else {
        $r = laden($id); if (!$r) antwort(['ok' => false, 'fehler' => "Raum $id gibt es nicht"], 404);
        weiterdenken($r);
    }
    $n = zug($r, 'bene', $text);
    $wartet = false;
    if ($r['lauf']) {   // läuft schon: Sprecher ergänzen, kein zweiter Lauf
        foreach (sprecher($an) as $s) if ($s !== $r['lauf']['an'] && !in_array($s, $r['rest'], true)) $r['rest'][] = $s;
        $wartet = true;
    } else {
        $sp = sprecher($an);
        $r['lauf'] = ['an' => array_shift($sp), 'beginn' => time()]; $r['rest'] = $sp;
    }
    sichern($r);
    antwort(['ok' => true, 'id' => $id, 'zug' => $n, 'wartet' => $wartet]);
case '/raum/weitergeben':
    $id = (string)($koerper['id'] ?? ''); $zn = (int)($koerper['zug'] ?? 0);
    if (!gueltig($id) || $zn < 1) antwort(['ok' => false, 'fehler' => 'id und zug nötig'], 400);
    $r = laden($id); if (!$r) antwort(['ok' => false, 'fehler' => "Raum $id gibt es nicht"], 404);
    $wert = !(array_key_exists('weitergeben', $koerper) && $koerper['weitergeben'] === false);
    $treffer = false;
    foreach ($r['zuege'] as &$z) { if ($z['zug'] === $zn) { $z['weitergeben'] = $wert; $treffer = true; } }
    unset($z);
    if (!$treffer) antwort(['ok' => false, 'fehler' => "Zug $zn gibt es in $id nicht"], 404);
    sichern($r);
    antwort(['ok' => true, 'id' => $id, 'zug' => $zn, 'weitergeben' => $wert]);
case '/stopp':
    $id = (string)($koerper['id'] ?? '');
    if (!gueltig($id)) antwort(['ok' => false, 'fehler' => 'id fehlt oder ist ungültig'], 400);
    $r = laden($id);
    if (!$r) antwort(['ok' => true, 'gestoppt' => false]);
    weiterdenken($r);
    $lief = $r['lauf'];
    if ($lief) {
        zug($r, 'system', 'Gestoppt — ' . ($lief['an'] === 'john' ? 'John' : 'Madeleine') . ' hatte noch nicht geantwortet.');
        $r['lauf'] = null; $r['rest'] = []; sichern($r);
    }
    antwort(['ok' => true, 'gestoppt' => (bool)$lief]);
case '/wecken': antwort(['ok' => true, 'gestartet' => false, 'getan' => ['Attrappe: nichts zu wecken']]);
case '/takt':   antwort(['ok' => false, 'fehler' => 'Attrappe hat keinen Takt'], 409);
default:        antwort(['ok' => false, 'fehler' => "unbekannt: $pfad"], 404);
}

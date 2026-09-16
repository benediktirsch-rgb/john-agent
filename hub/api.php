<?php
/**
 * api.php — Johns Rezeption im WWW (10.09.2026)
 *
 * Johns feste Adresse: hotel-vaikuntha.de/john/. Hier wohnt sein Stand, damit er den
 * Laptopdeckel überlebt: schläft der Rechner, ist John nicht weg — nur seine Hände sind es.
 *
 * Was diese Datei bewusst NICHT tut (Regel 3 der Architektur, docs/protokoll.md):
 *   kein Modell rufen, keinen Schlüssel halten, keine Mail lesen, nichts versenden.
 *   Sie hält Johns Stapel, seine Aufträge und ein kurzes Logbuch — mehr nicht. Genau
 *   daran hängt ihre Verlässlichkeit: es gibt hier nichts, was langsam werden könnte.
 *
 * Alles liegt in EINER Datei (daten/stand.json), jede Schreibung unter flock(LOCK_EX).
 * Zwei Zustandsdateien, die zueinander passen müssen, wären der sichere Weg in einen
 * halben Stapel.
 *
 * Protokoll: docs/protokoll.md im Repo john-agent. Wer hier etwas ändert, ändert es dort
 * zuerst — sonst laufen zwei Wahrheiten nebeneinander.
 */
declare(strict_types=1);
date_default_timezone_set('Europe/Berlin');

const JH_DATEN      = __DIR__ . '/daten';
const JH_STAND      = JH_DATEN . '/stand.json';
const JH_EINGANG    = JH_DATEN . '/eingang.jsonl';   // Briefkasten der Vishnu-Seite (docs/protokoll.md)
const JH_LOG_MAX    = 200;      // Zeilen im Logbuch
const JH_AUFTRAG_H  = 24;       // Stunden, dann verfällt ein unbearbeiteter Auftrag
const JH_NIMM_MIN   = 15;       // Minuten, dann darf ein anderes Gerät den Auftrag holen
const JH_ERGEBNIS_D = 7;        // Tage, dann räumt die Rezeption Ergebnisse weg
const JH_WACH_S     = 180;      // Sekunden ohne Puls, dann gilt ein Gerät als schlafend
const JH_RF_TAGE    = 30;       // Tage, dann räumt die Rezeption beantwortete/zurückgezogene Rückfragen weg
const JH_RF_JE_VON  = 5;        // offene Rückfragen je Beraterin (Geräte haben keine eigene Grenze)
const JH_RF_MAX     = 60;       // offene Rückfragen insgesamt
const JH_FG_TAGE    = 30;       // Freigaben laufen spaetestens nach so vielen Tagen ab (Bene, 16.09.2026)
const JH_FG_MAX     = 200;      // Freigaben insgesamt
const JH_GD_MAX     = 100;      // Eintraege im gemeinsamen Gedaechtnis je Beraterin
const JH_PERSONA_MAX = 20000;   // Zeichen der Persona je Beraterin

header('Content-Type: application/json; charset=utf-8');
/* Kein Access-Control-Allow-Origin: * mehr (11.09.2026, Madeleines Einwand): mit einem
   Token, das alles darf, und einem Stern hier reicht ein fremdes Skript in einem beliebigen
   Tab. Erlaubt sind die Seiten, auf denen Johns Klienten wirklich laufen. Curl kuemmert das
   nicht — deshalb ist die zweite Haelfte der Antwort die Token-Trennung weiter unten. */
$jh_erlaubt = [
    'https://bene.vishnuartists.com', 'https://bene.vaikuntha.eu', 'https://vishnuartists.com', 'https://www.vishnuartists.com',
    'https://vishnu-artists.de', 'https://naturnah-lernen.de', 'https://hotel-vaikuntha.de',
];
$jh_origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if ($jh_origin !== '' && (in_array($jh_origin, $jh_erlaubt, true)
    || preg_match('~^https?://(localhost|127\.0\.0\.1)(:\d+)?$~', $jh_origin) === 1)) {
    header('Access-Control-Allow-Origin: ' . $jh_origin);
    header('Vary: Origin');
}
header('Access-Control-Allow-Headers: Content-Type, X-John-Token');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Max-Age: 600');
header('Cache-Control: no-store');
header('X-Robots-Tag: noindex, nofollow');
/* Haertung 12.09.2026 (mit dem Geraet „wolke“ traegt die Rezeption ein Geraet mehr, ADR 0006):
   kein Raten des Inhaltstyps, kein Referrer nach aussen, HSTS nur auf Johns eigener Domain —
   naturnah-lernen.de liefert dieselben Dateien und soll keine Host-weite Regel von hier erben. */
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
if (($_SERVER['HTTP_HOST'] ?? '') === 'hotel-vaikuntha.de' && (($_SERVER['HTTPS'] ?? '') === 'on' || ($_SERVER['SERVER_PORT'] ?? '') === '443')) {
    header('Strict-Transport-Security: max-age=15552000');
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') { http_response_code(204); exit; }

function jh_ende(array $d, int $code = 200) {   /* kein never: der KAS koennte noch PHP 8.0 fahren */
    http_response_code($code);
    echo json_encode($d, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
    exit;
}
function jh_fehler(string $text, int $code) { jh_ende(['ok' => false, 'fehler' => $text], $code); }
function jh_jetzt(): string { return (new DateTimeImmutable('now'))->format('c'); }
function jh_alter(?string $iso): ?int {
    if (!$iso) return null;
    try { return max(0, time() - (new DateTimeImmutable($iso))->getTimestamp()); } catch (Throwable) { return null; }
}
function jh_neuer(?string $a, ?string $b): bool {   // ist a neuer als b?
    if (!$b) return true;
    if (!$a) return false;
    try { return (new DateTimeImmutable($a)) > (new DateTimeImmutable($b)); } catch (Throwable) { return false; }
}
function jh_text(mixed $v, int $max = 600): string {
    $s = is_string($v) ? $v : (is_scalar($v) ? (string)$v : '');
    $s = str_replace(["\r"], '', $s);
    $s = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F]/u', '', $s) ?? '';
    return mb_substr(trim($s), 0, $max);
}
function jh_id(string $p = ''): string { return $p . bin2hex(random_bytes(6)); }

/* ---------- Anmeldung ----------------------------------------------------------------
   Ein Token, keine Abstufung: die Rezeption hält nichts, wofür sich zwei Rechtestufen
   lohnen würden. Vergleich in konstanter Zeit, Antwort ohne Hinweis darauf, was fehlt. */
/** Was jede Klasse darf. Der Browser bekommt genau so viel, wie die Lobby braucht:
 *  nachsehen, einen Punkt abraeumen, einen Auftrag stellen. Er kann Johns Stapel nicht
 *  ueberschreiben, keinen Auftrag beanspruchen und kein Ergebnis faelschen. */
const JH_DARF = [
    'geraet'  => ['stand','puls','stapel','punkt','auftrag','auftraege','nimm','ergebnis','log','spiegel','stapelstand','stopp',
                  'rueckfragen','rueckfrage','rueckfrage-antwort','freigabe','freigaben','gedaechtnis','persona'],
    'browser' => ['stand','punkt','auftrag','stapelstand','stopp','rueckfragen','rueckfrage-antwort','freigabe','freigaben','gedaechtnis'],
    /* Beraterin (16.09.2026, Bene: „Madelene gleichberechtigten Zugriff auf meinen Compass geben und alle
       Rueckfragen von ihr dort sehen"): sie fragt Bene und liest seine Antworten — wie Claude. Sie ist kein
       Geraet: kein Puls, kein Auftrag, kein Stapel. Rueckfragen beantwortet nur Bene. */
    'berater' => ['stand','rueckfragen','rueckfrage','log','freigaben','gedaechtnis','persona'],
];

/**
 * Zwei Klassen statt einer (11.09.2026, Madeleines Einwand): bis dahin trug der Browser
 * dasselbe Vollzugriffstoken wie die Geraete. Ein Leck haette Lesen UND Schreiben aller
 * Geraete bedeutet, ohne Zuordnung und ohne die Moeglichkeit, nur eine Seite zu widerrufen.
 * Jetzt hat der Browser einen eigenen Schluessel mit eigener Reichweite; er laesst sich
 * einzeln neu wuerfeln (hub-deploy.ps1), ohne dass ein Geraet stehenbleibt.
 */
/* ---------- Bremse gegen Token-Raten (12.09.2026) ------------------------------------
   Vorher konnte jeder beliebig oft raten; 403 kostete nichts. Jetzt zaehlt die Rezeption
   Fehlversuche je Herkunft (nur als Hash, nie die Adresse selbst) in daten/bremse.json:
   ab JH_BREMSE_MAX im Fenster antwortet sie 429 mit Retry-After, und jeder Fehlversuch
   wartet kurz. Ein echtes Geraet mit richtigem Token merkt davon nichts. */
const JH_BREMSE_DATEI   = JH_DATEN . '/bremse.json';
const JH_BREMSE_MAX     = 20;     // Fehlversuche je Herkunft …
const JH_BREMSE_FENSTER = 600;    // … in diesen Sekunden
function jh_bremse_kennung(string $salz): string {
    return substr(hash('sha256', $salz . '|' . ($_SERVER['REMOTE_ADDR'] ?? '')), 0, 24);
}
function jh_bremse_lesen(): array {
    if (!is_file(JH_BREMSE_DATEI)) return [];
    $d = json_decode((string)@file_get_contents(JH_BREMSE_DATEI), true);
    return is_array($d) ? $d : [];
}
function jh_bremse_pruefen(string $salz): void {
    $e = jh_bremse_lesen()[jh_bremse_kennung($salz)] ?? null;
    if (!is_array($e)) return;
    $vergangen = time() - (int)($e['seit'] ?? 0);
    if ($vergangen < JH_BREMSE_FENSTER && (int)($e['n'] ?? 0) >= JH_BREMSE_MAX) {
        header('Retry-After: ' . (JH_BREMSE_FENSTER - $vergangen));
        jh_fehler('zu viele Fehlversuche', 429);
    }
}
function jh_bremse_zaehlen(string $salz): void {
    if (!is_dir(JH_DATEN)) { @mkdir(JH_DATEN, 0700, true); }
    $fh = @fopen(JH_BREMSE_DATEI, 'c+b');
    if ($fh && flock($fh, LOCK_EX)) {
        $d = json_decode((string)stream_get_contents($fh), true);
        if (!is_array($d)) $d = [];
        $jetzt = time();
        foreach ($d as $k => $e) {           // alte Fenster vergessen, die Datei bleibt klein
            if (!is_array($e) || $jetzt - (int)($e['seit'] ?? 0) >= JH_BREMSE_FENSTER) unset($d[$k]);
        }
        $k = jh_bremse_kennung($salz);
        $d[$k] = ['n' => (int)($d[$k]['n'] ?? 0) + 1, 'seit' => (int)($d[$k]['seit'] ?? $jetzt)];
        ftruncate($fh, 0); rewind($fh); fwrite($fh, json_encode($d)); fflush($fh);
        flock($fh, LOCK_UN);
    }
    if ($fh) fclose($fh);
    usleep(300000);                          // 0,3 s je Fehlversuch — Raten wird langsam, Betrieb nicht
}

/* Rueckgabe [klasse, name]: name ist der gebundene Name (token.php 'geraete', ADR 0007; 'berater', 16.09.2026)
   oder null fuer den alten ungebundenen Schluessel und den Browser. */
function jh_pruefe_token(): array {
    $datei = __DIR__ . '/token.php';
    if (!is_file($datei)) { jh_fehler('Rezeption nicht eingerichtet (token.php fehlt)', 500); }
    $cfg = require $datei;
    if (!is_array($cfg)) { jh_fehler('Rezeption nicht eingerichtet (kein Hash)', 500); }
    $salz = substr((string)($cfg['hash'] ?? ''), 0, 16);   // serverseitig, nie ausgeliefert
    $ist = $_SERVER['HTTP_X_JOHN_TOKEN'] ?? '';
    if (is_string($ist) && $ist !== '') {
        $meins = hash('sha256', $ist);
        foreach ((array)($cfg['geraete'] ?? []) as $name => $soll) {      // gebundene Schluessel zuerst
            $name = jh_text($name, 40);
            if ($name !== '' && is_string($soll) && $soll !== '' && hash_equals($soll, $meins)) { return ['geraet', $name]; }
        }
        foreach ((array)($cfg['berater'] ?? []) as $name => $soll) {      // Beraterinnen, ebenfalls gebunden
            $name = jh_text($name, 40);
            if (preg_match('/^[a-z0-9-]{2,30}$/', $name) && is_string($soll) && $soll !== '' && hash_equals($soll, $meins)) { return ['berater', $name]; }
        }
        foreach (['geraet' => 'hash', 'browser' => 'hash_browser'] as $klasse => $feld) {
            $soll = (string)($cfg[$feld] ?? '');
            if ($soll !== '' && hash_equals($soll, $meins)) { return [$klasse, null]; }
        }
    }
    /* Erst der Vergleich, dann die Bremse: ein richtiger Schluessel kommt immer durch, auch wenn
       hinter derselben Adresse (Router zu Hause: PC und Handy) gerade jemand falsch raet. Die Bremse
       verteuert nur das Raten selbst. */
    jh_bremse_pruefen($salz);
    jh_bremse_zaehlen($salz);
    jh_fehler((is_string($ist) && $ist !== '') ? 'Token stimmt nicht' : 'kein Token', 403);
    return ['', null];
}

/** Welcher Geraetename gilt fuer diese Anfrage? Ein gebundener Schluessel darf nur unter seinem
 *  eigenen Namen auftreten; leer heisst „nimm meinen“. Ungebundene Schluessel nehmen, was kommt. */
function jh_geraet_name(?string $gebunden, mixed $angegeben, int $max = 40): string {
    $a = jh_text($angegeben ?? '', $max);
    if ($gebunden === null) return $a;
    if ($a !== '' && $a !== $gebunden) jh_fehler("dieser Schluessel gehoert zu $gebunden", 403);
    return $gebunden;
}

/* ---------- Zustand ------------------------------------------------------------------ */
function jh_leer(): array {
    return [
        'version'   => 1,
        'angelegt'  => jh_jetzt(),
        'stapel'    => ['stand' => null, 'quelle' => null, 'punkte' => []],
        // Leeres Array, kein stdClass: der Zustand wird an mehreren Stellen als Array
        // angefasst, und json_encode macht daraus beim Wiederlesen ohnehin wieder eines.
        'geraete'   => [],
        'auftraege' => [],
        'rueckfragen' => [],
        'freigaben' => [],
        'gedaechtnis' => [],
        'log'       => [],
    ];
}
function jh_normal(array $s): array {
    $s['stapel']    = is_array($s['stapel'] ?? null) ? $s['stapel'] : ['stand' => null, 'quelle' => null, 'punkte' => []];
    $s['stapel']['punkte'] = array_values(array_filter((array)($s['stapel']['punkte'] ?? []), 'is_array'));
    $s['geraete']   = (array)($s['geraete'] ?? []);
    $s['auftraege'] = array_values(array_filter((array)($s['auftraege'] ?? []), 'is_array'));
    $s['log']       = array_values(array_filter((array)($s['log'] ?? []), 'is_array'));
    $s['rueckfragen'] = array_values(array_filter((array)($s['rueckfragen'] ?? []), 'is_array'));
    $s['freigaben']   = array_values(array_filter((array)($s['freigaben'] ?? []), 'is_array'));
    $gd = [];
    foreach ((array)($s['gedaechtnis'] ?? []) as $fuer => $liste) { $gd[(string)$fuer] = array_values(array_filter((array)$liste, 'is_array')); }
    $s['gedaechtnis'] = $gd;
    return $s;
}

/** Aufräumen bei jeder Schreibung — eine Halde wäre schlimmer als ein leerer Stapel. */
function jh_aufraeumen(array $s): array {
    $jetzt = time();
    $bleibt = [];
    foreach ($s['auftraege'] as $a) {
        $alter = jh_alter($a['erstellt'] ?? null) ?? 0;
        $status = (string)($a['status'] ?? 'offen');
        if (($status === 'fertig' || $status === 'gestoppt') && $alter > JH_ERGEBNIS_D * 86400) continue;
        if ($status === 'offen'  && $alter > JH_AUFTRAG_H * 3600) { $a['status'] = 'verfallen'; }
        if ($status === 'laeuft') {
            $seit = jh_alter($a['genommen'] ?? null);
            if ($seit !== null && $seit > JH_NIMM_MIN * 60) { $a['status'] = 'offen'; $a['nimmt'] = null; $a['genommen'] = null; }
        }
        if ($status === 'verfallen' && $alter > JH_ERGEBNIS_D * 86400) continue;
        $bleibt[] = $a;
    }
    $s['auftraege'] = $bleibt;
    $rf = [];
    foreach ($s['rueckfragen'] as $q) {
        $st = (string)($q['status'] ?? 'offen');
        if ($st !== 'offen' && (jh_alter($q['geaendert'] ?? null) ?? 0) > JH_RF_TAGE * 86400) continue;
        $rf[] = $q;
    }
    $s['rueckfragen'] = $rf;
    /* Abgelaufene Freigaben werden geloescht, nicht ausgeblendet (Bene, 16.09.2026). */
    $s['freigaben'] = array_values(array_filter($s['freigaben'], 'jh_fg_gueltig'));
    if (count($s['freigaben']) > JH_FG_MAX) { $s['freigaben'] = array_slice($s['freigaben'], -JH_FG_MAX); }
    foreach ($s['gedaechtnis'] as $fuer => $liste) {
        if (count($liste) > JH_GD_MAX) { $s['gedaechtnis'][$fuer] = array_slice($liste, -JH_GD_MAX); }
    }
    if (count($s['log']) > JH_LOG_MAX) { $s['log'] = array_slice($s['log'], -JH_LOG_MAX); }
    unset($jetzt);
    return $s;
}

function jh_lesen(): array {
    if (!is_file(JH_STAND)) return jh_leer();
    $fh = @fopen(JH_STAND, 'rb');
    if (!$fh) return jh_leer();
    @flock($fh, LOCK_SH);
    $roh = stream_get_contents($fh);
    @flock($fh, LOCK_UN); fclose($fh);
    $d = json_decode((string)$roh, true);
    return is_array($d) ? jh_normal($d) : jh_leer();
}

/**
 * Lesen, ändern, schreiben — alles unter EINER exklusiven Sperre. Ohne sie könnten zwei
 * Geräte, zwei Browser und die Vishnu-Seite gleichzeitig schreiben; ein halb geschriebenes
 * JSON würde John den Kopf kosten.
 */
function jh_schreiben(callable $aendern): array {
    if (!is_dir(JH_DATEN)) { @mkdir(JH_DATEN, 0700, true); }
    $fh = @fopen(JH_STAND, 'c+b');
    if (!$fh) { jh_fehler('Rezeption kann nicht schreiben (Rechte auf daten/)', 500); }
    if (!flock($fh, LOCK_EX)) { fclose($fh); jh_fehler('Rezeption ist gerade belegt', 503); }
    $roh = stream_get_contents($fh);
    $s = json_decode((string)$roh, true);
    $s = is_array($s) ? jh_normal($s) : jh_leer();
    $s = jh_eingang_uebernehmen($s);   // Briefkasten zuerst, damit jeder Aufruf ihn sieht
    $ergebnis = $aendern($s);          // gibt [$neuerStand, $antwort] zurück
    [$s, $antwort] = $ergebnis;
    $s = jh_aufraeumen($s);
    $s['geschrieben'] = jh_jetzt();
    $json = json_encode($s, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
    if ($json === false) { flock($fh, LOCK_UN); fclose($fh); jh_fehler('Stand nicht schreibbar', 500); }
    ftruncate($fh, 0); rewind($fh); fwrite($fh, $json); fflush($fh);
    flock($fh, LOCK_UN); fclose($fh);
    return $antwort;
}

/**
 * Den Briefkasten leeren (unter der Sperre von jh_schreiben aufgerufen). Die Vishnu-Seite wirft
 * Buchungen als Zeilen ein; hier werden sie zu Auftraegen der Art `coach`. Doppelte ids (ein
 * zweimal abgeschicktes Formular) zaehlen einmal. Kaputte Zeilen fallen raus, statt alles
 * aufzuhalten.
 */
function jh_eingang_uebernehmen(array $s): array {
    if (!is_file(JH_EINGANG)) return $s;
    $fh = @fopen(JH_EINGANG, 'c+b');
    if (!$fh) return $s;
    if (!flock($fh, LOCK_EX)) { fclose($fh); return $s; }
    $roh = stream_get_contents($fh);
    $bekannt = [];
    foreach ($s['auftraege'] as $a) { $bekannt[(string)($a['id'] ?? '')] = true; }
    $neu = 0;
    foreach (preg_split('/\n+/', (string)$roh) as $zeile) {
        $z = json_decode(trim($zeile), true);
        if (!is_array($z)) continue;
        $id = jh_text($z['id'] ?? '', 40);
        $text = jh_text($z['text'] ?? '', 2000);
        if ($id === '' || $text === '' || isset($bekannt[$id])) continue;
        $s['auftraege'][] = [
            'id' => $id, 'art' => 'coach', 'text' => $text,
            'thema' => jh_text($z['thema'] ?? '', 20), 'form' => jh_text($z['form'] ?? 'schriftlich', 20),
            'wuensche' => array_slice(array_map(fn($w) => jh_text($w, 20), (array)($z['wuensche'] ?? [])), 0, 3),
            'wer' => jh_text($z['wer'] ?? 'vishnu', 40), 'vorname' => jh_text($z['vorname'] ?? '', 40),
            'dringend' => false, 'erstellt' => jh_text($z['erstellt'] ?? '', 40) ?: jh_jetzt(),
            'status' => 'offen', 'nimmt' => null, 'genommen' => null, 'ergebnis' => null,
        ];
        $bekannt[$id] = true; $neu++;
    }
    ftruncate($fh, 0); fflush($fh);
    flock($fh, LOCK_UN); fclose($fh);
    if ($neu) { $s = jh_logzeile($s, 'auftrag', "$neu Buchung(en) fuer Bene digital aus dem Briefkasten"); }
    return $s;
}
/* ---------- Johns Kachel ueberall (w=spiegel, w=stapelstand) --------------------------
   Der Compass-Stapel des Cockpit-Servers, gespiegelt vom Geraet. Mail-Entwuerfe und
   Claude-Auftraege bleiben auf dem Rechner (nurAmRechner) — hier steht das Thema, nicht
   der Inhalt (ADR 0002). */
function jh_compass(array $s): array {
    $c = is_array($s['compass'] ?? null) ? $s['compass'] : [];
    $c['punkte'] = array_values(array_filter((array)($c['punkte'] ?? []), 'is_array'));
    $c['stand']  = (array)($c['stand'] ?? []);
    return $c + ['stand_um' => null, 'quelle' => null];
}
function jh_punkt_saeubern(array $p): ?array {
    $key = jh_text($p['key'] ?? '', 120);
    $titel = jh_text($p['titel'] ?? '', 200);
    if ($key === '' || $titel === '') return null;
    $a = is_array($p['aktion'] ?? null) ? $p['aktion'] : [];
    $art = jh_text($a['art'] ?? '', 20);
    $aktion = ['art' => $art, 'label' => jh_text($a['label'] ?? '', 80)];
    if (in_array($art, ['mail', 'claude'], true)) { $aktion['nurAmRechner'] = true; }
    if ($art === 'link' && preg_match('~^https?://~', (string)($a['url'] ?? ''))) { $aktion['url'] = jh_text($a['url'], 400); }
    if ($art === 'john') { $aktion['frage'] = jh_text($a['frage'] ?? '', 300); }
    if ($art === 'termin') { $aktion['titel'] = jh_text($a['titel'] ?? '', 120); $aktion['start'] = jh_text($a['start'] ?? '', 30); $aktion['minuten'] = (int)($a['minuten'] ?? 30); }
    if ($art === 'karte') { $aktion['ziel'] = jh_text($a['ziel'] ?? '', 20); $aktion['name'] = jh_text($a['name'] ?? '', 120); }
    return ['key' => $key, 'titel' => $titel, 'satz' => jh_text($p['satz'] ?? '', 500), 'aktion' => $aktion];
}
function jh_stand_eintrag(array $e): ?array {
    $status = jh_text($e['status'] ?? '', 10);
    if (!in_array($status, ['ok', 'wieder', 'offen'], true)) return null;
    $ts = jh_text($e['ts'] ?? '', 40);
    if ($ts === '') return null;
    return ['status' => $status, 'ts' => $ts, 'bis' => jh_text($e['bis'] ?? '', 40),
            'aktion' => jh_text($e['aktion'] ?? '', 80), 'titel' => jh_text($e['titel'] ?? '', 200)];
}
/** Juengerer Zeitstempel gewinnt — so ueberschreibt kein Geraet ein OK, das es noch nicht kennt. */
function jh_stand_mischen(array $alt, array $neu): array {
    foreach ($neu as $key => $e) {
        if (!is_array($e)) continue;
        $e = jh_stand_eintrag($e);
        $key = jh_text((string)$key, 120);
        if (!$e || $key === '') continue;
        if (!isset($alt[$key]) || jh_neuer($e['ts'], (string)($alt[$key]['ts'] ?? ''))) { $alt[$key] = $e; }
    }
    // Aufraeumen: was laenger als 30 Tage erledigt ist, traegt nichts mehr (wie Save-Stapel im Server).
    foreach ($alt as $k => $e) { if ((jh_alter($e['ts'] ?? null) ?? 0) > 30 * 86400) unset($alt[$k]); }
    return $alt;
}
function jh_compass_ts(array $c): ?string {
    $j = null;
    foreach ($c['stand'] as $e) { if (jh_neuer((string)($e['ts'] ?? ''), $j)) $j = (string)$e['ts']; }
    return $j;
}

/* ---------- Rueckfragen (16.09.2026) ------------------------------------------------
   Dieselbe Form wie rhythmus-data.js › rueckfragen im Compass, plus Herkunft und Stand.
   Die Rezeption haelt Frage, Optionen und Antwort — keine Zahlen, keine Personendaten;
   daran halten sich die Fragenden (docs/protokoll.md › Rueckfragen). */
function jh_rf_offen(array $s, ?string $von = null): int {
    $n = 0;
    foreach ($s['rueckfragen'] as $q) {
        if ((string)($q['status'] ?? '') !== 'offen') continue;
        if ($von !== null && (string)($q['von'] ?? '') !== $von) continue;
        $n++;
    }
    return $n;
}
function jh_rf_dringend(array $s, string $von): int {
    $n = 0;
    foreach ($s['rueckfragen'] as $q) { if ((string)($q['status'] ?? '') === 'offen' && (string)($q['von'] ?? '') === $von && !empty($q['dringend'])) $n++; }
    return $n;
}
function jh_rf_finde(array $s, string $id): ?int {
    foreach ($s['rueckfragen'] as $i => $q) { if ((string)($q['id'] ?? '') === $id) return $i; }
    return null;
}
function jh_rf_datum(mixed $v): string {
    $d = jh_text($v ?? '', 10);
    return preg_match('/^\d{4}-\d{2}-\d{2}$/', $d) ? $d : (new DateTimeImmutable('now'))->format('Y-m-d');
}

/* ---------- Freigaben und gemeinsames Gedaechtnis (16.09.2026) -------------------------
   Bene: „Kontext moechte ich gezielt pro Frage freigeben koennen" (Rueckfrage madelene-freigabe-modell:
   nur pro Frage, mit Vorschau, 30 Tage) und „Madelene ist eine Person" (Astra und die lokale Laufzeit
   teilen Persona und Gedaechtnis). Die Rezeption speichert nur den Text, den Bene in der Vorschau
   gesehen hat — nie einen Verweis auf eine Quelle. Vier Muster sind fast immer vertraulich; ein Treffer
   blockiert, solange Bene nicht ausdruecklich „trotzdem" sagt. Gedaechtnis und Persona nehmen
   Treffer gar nicht an: dort schreibt niemand, der vorher eine Vorschau gesehen hat. */
function jh_muster(string $t): array {
    $m = [];
    if (preg_match('/\d[\d.,]*\s?(€|eur\b|euro\b|\$|usd\b|tsd\b|t€|k€)/iu', $t) || preg_match('/(€|\$)\s?\d/u', $t)
        || preg_match('/\b\d+(?:[.,]\d+)?\s?k\b/iu', $t)) $m[] = 'betrag';
    if (preg_match('/\b[A-Z]{2}\d{2}(?:\s?[A-Z0-9]{4}){3,7}/', mb_strtoupper($t))) $m[] = 'iban';
    if (preg_match('/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i', $t)) $m[] = 'mail';
    if (preg_match('/(?:\+|\b00)\d[\d \/-]{7,}\d|\b0\d{2,5}[ \/-]?\d{3,}[\d -]{2,}\d\b/', $t)) $m[] = 'telefon';
    return $m;
}
function jh_fg_gueltig(array $f): bool {
    return (string)($f['bis'] ?? '') >= (new DateTimeImmutable('now'))->format('Y-m-d');
}
function jh_fg_finde(array $s, string $id): ?int {
    foreach ($s['freigaben'] as $i => $f) { if ((string)($f['id'] ?? '') === $id) return $i; }
    return null;
}
function jh_name(mixed $v): string {
    $n = jh_text($v ?? '', 30);
    return preg_match('/^[a-z0-9-]{2,30}$/', $n) ? $n : '';
}
function jh_persona_datei(string $fuer): string { return JH_DATEN . '/persona-' . $fuer . '.md'; }

function jh_logzeile(array $s, string $art, string $text, ?string $geraet = null): array {
    $s['log'][] = ['zeit' => jh_jetzt(), 'art' => $art, 'text' => jh_text($text, 300), 'geraet' => $geraet ? jh_text($geraet, 40) : null];
    return $s;
}

/** Die letzten 20 Raum-Zuege, ohne Text: damit zeigt das Handy den Stand eines Raums. */
function jh_raeume(array $s): array {
    $r = [];
    foreach ($s['auftraege'] as $a) {
        if (($a['art'] ?? '') !== 'raum') continue;
        $r[] = ['id' => $a['id'], 'raum' => $a['raum'] ?? '', 'thema' => $a['thema'] ?? '', 'zug' => $a['zug'] ?? 0,
                'an' => $a['an'] ?? '', 'status' => $a['status'] ?? '', 'erstellt' => $a['erstellt'] ?? null,
                'fertig' => $a['fertig'] ?? null, 'notiz' => $a['ergebnis']['notiz'] ?? null];
    }
    return array_slice($r, -20);
}

/** Die Antwort auf „wie geht es John?" — die einzige Frage, die jeder Klient stellt. */
function jh_stand_antwort(array $s): array {
    $geraete = [];
    $wach = false;
    foreach ($s['geraete'] as $name => $g) {
        $alter = jh_alter($g['puls'] ?? null);
        $istWach = ($alter !== null && $alter <= JH_WACH_S);
        if ($istWach) $wach = true;
        $geraete[] = [
            'name' => (string)$name, 'puls' => $g['puls'] ?? null, 'alter_s' => $alter, 'wach' => $istWach,
            'takt' => $g['takt'] ?? null, 'version' => $g['version'] ?? null,
            'kann' => array_values((array)($g['kann'] ?? [])), 'notiz' => $g['notiz'] ?? null,
        ];
    }
    usort($geraete, fn($a, $b) => ($a['alter_s'] ?? 99999) <=> ($b['alter_s'] ?? 99999));
    $offen = $laeuft = $fertig = 0;
    foreach ($s['auftraege'] as $a) {
        $st = (string)($a['status'] ?? 'offen');
        if ($st === 'offen') $offen++;
        elseif ($st === 'laeuft') $laeuft++;
        elseif ($st === 'fertig' && (jh_alter($a['erstellt'] ?? null) ?? 99999) < 86400) $fertig++;
    }
    /* Wann hat John zuletzt wirklich gedacht? (11.09.2026, Madeleines Einwand Nr. 4 und mein
       eigener: es gibt Logs, aber niemand liest Logs.) Diese eine Zahl reicht bis in die Lobby
       und spaeter auf Benes Karte — daran sieht er, dass John seit vier Tagen stumm ist, ohne
       eine einzige Datei zu oeffnen. */
    $taktZeit = null; $taktGeraet = null;
    foreach ($s['geraete'] as $name => $g) {
        $tk = $g['takt'] ?? null;
        if ($tk && jh_neuer($tk, $taktZeit)) { $taktZeit = $tk; $taktGeraet = (string)$name; }
    }
    $taktAlter = jh_alter($taktZeit);
    $rfVon = [];
    foreach ($s['rueckfragen'] as $q) {
        if ((string)($q['status'] ?? '') !== 'offen') continue;
        $v = (string)($q['von'] ?? '?');
        $rfVon[$v] = ($rfVon[$v] ?? 0) + 1;
    }
    return [
        'ok' => true, 'jetzt' => jh_jetzt(), 'wach' => $wach,
        'takt' => ['letzter' => $taktZeit, 'geraet' => $taktGeraet, 'alter_s' => $taktAlter,
                   'stille_tage' => $taktAlter === null ? null : (int)floor($taktAlter / 86400)],
        'geraete' => $geraete,
        'stapel' => $s['stapel'],
        'compass' => jh_compass($s),
        'raeume' => jh_raeume($s),
        'auftraege' => ['offen' => $offen, 'laufend' => $laeuft, 'fertig24' => $fertig],
        'rueckfragen' => ['offen' => array_sum($rfVon), 'von' => (object)$rfVon],
        'log' => array_slice($s['log'], -20),
    ];
}

/* ---------- Eingang ------------------------------------------------------------------ */
[$jh_klasse, $jh_geraet] = jh_pruefe_token();

$was = (string)($_GET['w'] ?? '');
if ($was !== '' && !in_array($was, JH_DARF[$jh_klasse] ?? [], true)) {
    jh_fehler("dieser Schluessel darf kein $was", 403);
}
$post = ($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST';
$koerper = [];
if ($post) {
    /* 12.09.2026: hoechstens 256 KB. Ein Stapel hat 5 Punkte, ein Ergebnis 4000 Zeichen —
       alles darueber ist kein Auftrag, sondern ein Versuch, die Rezeption zu beschaeftigen. */
    $roh = (string)file_get_contents('php://input', false, null, 0, 262145);
    if (strlen($roh) > 262144) jh_fehler('Anfrage zu gross', 413);
    $koerper = json_decode($roh, true);
    if (!is_array($koerper)) $koerper = [];
}

switch ($was) {

case 'stand':
    $st = jh_stand_antwort(jh_lesen());
    /* Beraterin (16.09.2026): Johns Stapel, der Compass-Spiegel, die Raeume und das Logbuch bleiben
       drin — sie sieht, ob John wach ist, wann er zuletzt dachte, und wie viele Rueckfragen offen sind.
       Mehr erst, wenn Bene es so entscheidet (Rueckfrage madelene-sicht-stand). */
    if ($jh_klasse === 'berater') {
        $st = ['ok' => true, 'jetzt' => $st['jetzt'], 'wach' => $st['wach'], 'takt' => $st['takt'],
               'geraete' => array_map(fn($g) => ['name' => $g['name'], 'wach' => $g['wach'], 'alter_s' => $g['alter_s']], $st['geraete']),
               'rueckfragen' => ['offen' => (int)($st['rueckfragen']['von']->{$jh_geraet} ?? 0)], 'sicht' => 'beraterin'];
    }
    jh_ende($st);

case 'puls':
    if (!$post) jh_fehler('nur POST', 400);
    $name = jh_geraet_name($jh_geraet, $koerper['geraet'] ?? '');
    if ($name === '') jh_fehler('geraet fehlt', 400);
    jh_ende(jh_schreiben(function (array $s) use ($name, $koerper) {
        $vorher = $s['geraete'][$name] ?? null;
        $s['geraete'][$name] = [
            'puls' => jh_jetzt(),
            'version' => jh_text($koerper['version'] ?? '', 20),
            'kann' => array_slice(array_map(fn($k) => jh_text($k, 20), (array)($koerper['kann'] ?? [])), 0, 8),
            'notiz' => jh_text($koerper['notiz'] ?? '', 200),
            'takt' => jh_text($koerper['takt'] ?? '', 40) ?: null,
            'seit' => $vorher['seit'] ?? jh_jetzt(),
        ];
        // Ein Gerät, das nach langer Stille zurückkommt, ist eine Logzeile wert — daran
        // sieht man später, wann John wirklich wach war und wann nicht.
        $alter = jh_alter($vorher['puls'] ?? null);
        if ($vorher === null || $alter === null || $alter > 900) {
            $s = jh_logzeile($s, 'start', ($vorher === null ? 'Neues Gerät' : 'Gerät wieder wach') . ": $name", $name);
        }
        $offen = 0;
        // Raum-Zuege zaehlen nicht: die nimmt der Kindprozess, der sie angelegt hat, sofort selbst.
        foreach ($s['auftraege'] as $a) { if ((string)($a['status'] ?? '') === 'offen' && (string)($a['art'] ?? '') !== 'raum') $offen++; }
        // Gestoppte Auftraege, die DIESES Geraet hatte (letzte Stunde): so erreicht ein Stopp vom Handy den Kindprozess.
        $stopp = [];
        foreach ($s['auftraege'] as $a) {
            if ((string)($a['status'] ?? '') === 'gestoppt' && (string)($a['nimmt'] ?? '') === $name && (jh_alter($a['gestoppt'] ?? null) ?? 99999) < 3600) $stopp[] = (string)$a['id'];
        }
        return [$s, ['ok' => true, 'auftraege' => $offen, 'jetzt' => jh_jetzt(), 'compassTs' => jh_compass_ts(jh_compass($s)), 'stopp' => $stopp]];
    }));

case 'stapel':
    if (!$post) jh_fehler('nur POST', 400);
    $stand = jh_text($koerper['stand'] ?? '', 40);
    if ($stand === '') jh_fehler('stand fehlt', 400);
    $koerper['quelle'] = jh_geraet_name($jh_geraet, $koerper['quelle'] ?? '');
    jh_ende(jh_schreiben(function (array $s) use ($koerper, $stand) {
        // Ein spät zurückkehrendes Gerät darf keinen alten Stapel über einen neuen legen.
        if (!jh_neuer($stand, $s['stapel']['stand'] ?? null)) {
            return [$s, ['ok' => false, 'fehler' => 'älter als der gespeicherte Stand', 'stand' => $s['stapel']['stand']]];
        }
        $punkte = [];
        foreach (array_slice((array)($koerper['punkte'] ?? []), 0, 5) as $p) {
            if (!is_array($p)) continue;
            $titel = jh_text($p['titel'] ?? '', 200);
            if ($titel === '') continue;
            $punkte[] = [
                'id'     => jh_text($p['id'] ?? '', 40) ?: jh_id('p-'),
                'titel'  => $titel,
                'warum'  => jh_text($p['warum'] ?? '', 400),
                'art'    => jh_text($p['art'] ?? 'john', 20),
                'aktion' => jh_text($p['aktion'] ?? '', 200),
            ];
        }
        $s['stapel'] = ['stand' => $stand, 'quelle' => jh_text($koerper['quelle'] ?? '', 40), 'punkte' => $punkte];
        $s = jh_logzeile($s, 'stapel', count($punkte) . ' Punkt(e) gesetzt', jh_text($koerper['quelle'] ?? '', 40));
        return [$s, ['ok' => true, 'punkte' => count($punkte)]];
    }));

case 'punkt':
    if (!$post) jh_fehler('nur POST', 400);
    $id  = jh_text($koerper['id'] ?? '', 40);
    $tat = jh_text($koerper['tat'] ?? '', 20);
    if ($id === '' || !in_array($tat, ['ok', 'aktion', 'spaeter'], true)) jh_fehler('id oder tat fehlt', 400);
    jh_ende(jh_schreiben(function (array $s) use ($id, $tat, $koerper) {
        $gefunden = false; $titel = '';
        $neu = [];
        foreach ($s['stapel']['punkte'] as $p) {
            if (($p['id'] ?? '') !== $id) { $neu[] = $p; continue; }
            $gefunden = true; $titel = (string)($p['titel'] ?? '');
            if ($tat === 'spaeter') {
                $p['wieder'] = (new DateTimeImmutable('+24 hours'))->format('c');
                $neu[] = $p;                     // bleibt liegen, aber markiert
            }
            // 'ok' und 'aktion' räumen ihn ab — an jedem Gerät, das ist der ganze Sinn.
        }
        if (!$gefunden) return [$s, ['ok' => false, 'fehler' => 'Punkt nicht gefunden']];
        $s['stapel']['punkte'] = array_values($neu);
        $wer = jh_text($koerper['wer'] ?? '', 30);
        $s = jh_logzeile($s, 'punkt', "$tat: $titel" . ($wer ? " ($wer)" : ''), null);
        return [$s, ['ok' => true, 'offen' => count($s['stapel']['punkte'])]];
    }));

case 'auftrag':
    if (!$post) jh_fehler('nur POST', 400);
    $art  = jh_text($koerper['art'] ?? 'frage', 20);
    $text = jh_text($koerper['text'] ?? '', 2000);
    if (!in_array($art, ['stapel', 'board', 'chat', 'frage', 'takt', 'coach', 'raum'], true)) jh_fehler('unbekannte art', 400);
    /* Gespraechsraum (11.09.2026): der Text liegt auf dem Geraet, hier nur das Signal. Die Rezeption
       weist Text ab, statt ihn stillschweigend zu speichern — sonst waere die Regel nur ein Wunsch. */
    $raumFelder = [];
    if ($art === 'raum') {
        if ($jh_klasse !== 'geraet') jh_fehler('einen Raum-Zug legt nur ein Geraet an', 403);
        if ($text !== '') jh_fehler('raum traegt keinen Text — das Gespraech liegt auf dem Geraet', 400);
        $raumId = jh_text($koerper['raum'] ?? '', 40);
        if (!preg_match('/^[a-z0-9-]{1,40}$/', $raumId)) jh_fehler('raum-Kennung ungueltig ([a-z0-9-]{1,40})', 400);
        $an = jh_text($koerper['an'] ?? '', 20);
        if (!in_array($an, ['john', 'madeleine'], true)) jh_fehler('an: john oder madeleine', 400);
        $raumFelder = ['raum' => $raumId, 'zug' => max(0, (int)($koerper['zug'] ?? 0)), 'an' => $an, 'thema' => jh_text($koerper['thema'] ?? '', 80)];
    } elseif ($text === '') {
        jh_fehler('text fehlt', 400);
    }
    jh_ende(jh_schreiben(function (array $s) use ($art, $text, $koerper, $raumFelder) {
        $offen = 0;
        foreach ($s['auftraege'] as $a) { if ((string)($a['status'] ?? '') === 'offen') $offen++; }
        if ($offen >= 20) return [$s, ['ok' => false, 'fehler' => 'zu viele offene Aufträge']];
        $id = jh_id('a-');
        $s['auftraege'][] = [
            'id' => $id, 'art' => $art, 'text' => $text,
            'wer' => jh_text($koerper['wer'] ?? 'compass', 30),
            'dringend' => (bool)($koerper['dringend'] ?? false),
            'erstellt' => jh_jetzt(), 'status' => 'offen',
            'nimmt' => null, 'genommen' => null, 'ergebnis' => null,
        ] + $raumFelder;
        // Nur Betrieb ins Logbuch, nie den Inhalt: bei coach steht dort sonst die Frage eines Mitglieds.
        $s = jh_logzeile($s, 'auftrag', $art === 'raum'
            ? 'raum ' . $raumFelder['raum'] . ': Zug ' . $raumFelder['zug'] . ' an ' . $raumFelder['an']
            : "$art: neuer Auftrag (" . mb_strlen($text) . ' Zeichen)');
        return [$s, ['ok' => true, 'id' => $id]];
    }));

case 'auftraege':
    // Ueber jh_schreiben statt jh_lesen: nur so wird der Briefkasten geleert, bevor ein Geraet fragt.
    $s = jh_schreiben(fn(array $st) => [$st, $st]);
    $liste = [];
    foreach ($s['auftraege'] as $a) {
        if ((string)($a['status'] ?? '') !== 'offen') continue;
        if (($a['art'] ?? '') === 'raum') continue;   // der Text liegt nur auf dem anlegenden Geraet
        $liste[] = ['id' => $a['id'], 'art' => $a['art'], 'text' => $a['text'], 'wer' => $a['wer'], 'erstellt' => $a['erstellt'], 'dringend' => $a['dringend'] ?? false,
                    'thema' => $a['thema'] ?? null, 'vorname' => $a['vorname'] ?? null, 'form' => $a['form'] ?? null];
    }
    usort($liste, fn($x, $y) => (($y['dringend'] ?? false) <=> ($x['dringend'] ?? false)) ?: strcmp((string)$x['erstellt'], (string)$y['erstellt']));
    jh_ende(['ok' => true, 'auftraege' => array_slice($liste, 0, 20)]);

case 'nimm':
    if (!$post) jh_fehler('nur POST', 400);
    $id = jh_text($koerper['id'] ?? '', 40);
    $geraet = jh_geraet_name($jh_geraet, $koerper['geraet'] ?? '');
    if ($id === '' || $geraet === '') jh_fehler('id oder geraet fehlt', 400);
    $antwort = jh_schreiben(function (array $s) use ($id, $geraet) {
        foreach ($s['auftraege'] as $i => $a) {
            if (($a['id'] ?? '') !== $id) continue;
            if ((string)($a['status'] ?? '') !== 'offen') {
                return [$s, ['ok' => false, 'fehler' => 'schon vergeben an ' . (string)($a['nimmt'] ?? '?'), 'code' => 409]];
            }
            $s['auftraege'][$i]['status'] = 'laeuft';
            $s['auftraege'][$i]['nimmt'] = $geraet;
            $s['auftraege'][$i]['genommen'] = jh_jetzt();
            return [$s, ['ok' => true]];
        }
        return [$s, ['ok' => false, 'fehler' => 'Auftrag nicht gefunden', 'code' => 404]];
    });
    jh_ende($antwort, (int)($antwort['code'] ?? 200) >= 400 ? (int)$antwort['code'] : 200);

case 'ergebnis':
    if (!$post) jh_fehler('nur POST', 400);
    $id = jh_text($koerper['id'] ?? '', 40);
    if ($id === '') jh_fehler('id fehlt', 400);
    $antwortE = jh_schreiben(function (array $s) use ($id, $koerper) {
        foreach ($s['auftraege'] as $i => $a) {
            if (($a['id'] ?? '') !== $id) continue;
            if ((string)($a['status'] ?? '') === 'gestoppt') return [$s, ['ok' => false, 'fehler' => 'gestoppt', 'code' => 409]];
            if (($a['art'] ?? '') === 'raum' && jh_text($koerper['text'] ?? '', 10) !== '') return [$s, ['ok' => false, 'fehler' => 'raum traegt keinen Text', 'code' => 400]];
            $s['auftraege'][$i]['status'] = 'fertig';
            $s['auftraege'][$i]['fertig'] = jh_jetzt();
            $s['auftraege'][$i]['ergebnis'] = [
                'ok' => (bool)($koerper['ok'] ?? true),
                'text' => jh_text($koerper['text'] ?? '', 4000),
                'notiz' => jh_text($koerper['notiz'] ?? '', 300),
                'zeit' => jh_jetzt(),
            ];
            $s = jh_logzeile($s, ((bool)($koerper['ok'] ?? true)) ? 'fertig' : 'fehler', (string)$a['art'] . ': ' . (((bool)($koerper['ok'] ?? true)) ? 'Antwort liegt vor (' . mb_strlen((string)($koerper['text'] ?? '')) . ' Zeichen)' : 'gescheitert'), (string)($a['nimmt'] ?? ''));
            return [$s, ['ok' => true]];
        }
        return [$s, ['ok' => false, 'fehler' => 'Auftrag nicht gefunden', 'code' => 404]];
    });
    jh_ende($antwortE, (int)($antwortE['code'] ?? 200) >= 400 ? (int)$antwortE['code'] : 200);

case 'stopp':
    if (!$post) jh_fehler('nur POST', 400);
    $id = jh_text($koerper['id'] ?? '', 40);
    if ($id === '') jh_fehler('id fehlt', 400);
    $antwortS = jh_schreiben(function (array $s) use ($id, $koerper, $jh_klasse) {
        foreach ($s['auftraege'] as $i => $a) {
            if (($a['id'] ?? '') !== $id) continue;
            $st = (string)($a['status'] ?? '');
            if (!in_array($st, ['offen', 'laeuft'], true)) return [$s, ['ok' => false, 'fehler' => "schon $st", 'code' => 409]];
            $s['auftraege'][$i]['status'] = 'gestoppt';
            $s['auftraege'][$i]['gestoppt'] = jh_jetzt();
            $s['auftraege'][$i]['fertig'] = jh_jetzt();
            $s = jh_logzeile($s, 'stopp', (string)($a['art'] ?? '') . ' gestoppt (' . jh_text($koerper['wer'] ?? $jh_klasse, 20) . ')', (string)($a['nimmt'] ?? ''));
            return [$s, ['ok' => true, 'war' => $st]];
        }
        return [$s, ['ok' => false, 'fehler' => 'Auftrag nicht gefunden', 'code' => 404]];
    });
    jh_ende($antwortS, (int)($antwortS['code'] ?? 200) >= 400 ? (int)$antwortS['code'] : 200);

case 'log':
    if (!$post) jh_fehler('nur POST', 400);
    $text = jh_text($koerper['text'] ?? '', 300);
    if ($text === '') jh_fehler('text fehlt', 400);
    $koerper['geraet'] = jh_geraet_name($jh_geraet, $koerper['geraet'] ?? '');
    jh_ende(jh_schreiben(function (array $s) use ($koerper, $text) {
        $s = jh_logzeile($s, jh_text($koerper['art'] ?? 'hinweis', 20), $text, jh_text($koerper['geraet'] ?? '', 40) ?: null);
        return [$s, ['ok' => true]];
    }));

case 'spiegel':
    if (!$post) jh_fehler('nur POST', 400);
    $koerper['quelle'] = jh_geraet_name($jh_geraet, $koerper['quelle'] ?? '');
    jh_ende(jh_schreiben(function (array $s) use ($koerper) {
        $c = jh_compass($s);
        if (isset($koerper['punkte']) && is_array($koerper['punkte'])) {
            $punkte = [];
            foreach (array_slice($koerper['punkte'], 0, 8) as $p) { if (is_array($p) && ($q = jh_punkt_saeubern($p))) $punkte[] = $q; }
            $c['punkte'] = $punkte;
            $c['stand_um'] = jh_text($koerper['stand_um'] ?? '', 40) ?: jh_jetzt();
            $c['quelle'] = jh_text($koerper['quelle'] ?? '', 40);
        }
        $c['stand'] = jh_stand_mischen($c['stand'], (array)($koerper['stand'] ?? []));
        $s['compass'] = $c;
        return [$s, ['ok' => true, 'stand' => $c['stand'], 'compassTs' => jh_compass_ts($c), 'punkte' => count($c['punkte'])]];
    }));

case 'stapelstand':
    if (!$post) jh_fehler('nur POST', 400);
    $key = jh_text($koerper['key'] ?? '', 120);
    $e = jh_stand_eintrag($koerper);
    if ($key === '' || !$e) jh_fehler('key, status (ok|wieder|offen) und ts noetig', 400);
    jh_ende(jh_schreiben(function (array $s) use ($key, $e, $jh_klasse) {
        $c = jh_compass($s);
        $c['stand'] = jh_stand_mischen($c['stand'], [$key => $e]);
        $s['compass'] = $c;
        $s = jh_logzeile($s, 'stapel', $e['status'] . ' (' . $jh_klasse . ')');
        return [$s, ['ok' => true, 'eintrag' => $c['stand'][$key] ?? null]];
    }));

case 'rueckfragen':
    $status = jh_text($_GET['status'] ?? 'offen', 20);
    if (!in_array($status, ['offen', 'beantwortet', 'zurueckgezogen', 'alle'], true)) jh_fehler('status: offen, beantwortet, zurueckgezogen oder alle', 400);
    $von  = jh_text($_GET['von'] ?? '', 40);
    /* Beraterin (16.09.2026, Bene: „ausschliesslich ihre eigenen Fragen und die zugehoerigen Antworten"):
       sie liest nur, was sie selbst gefragt hat — Claudes Fragen und Benes Antworten darauf nie. */
    if ($jh_klasse === 'berater') {
        if ($von !== '' && $von !== $jh_geraet) jh_fehler('eine Beraterin liest nur ihre eigenen Rueckfragen', 403);
        $von = (string)$jh_geraet;
    }
    $seit = jh_text($_GET['seit'] ?? '', 40);
    $liste = [];
    foreach (jh_lesen()['rueckfragen'] as $q) {
        if ($status !== 'alle' && (string)($q['status'] ?? '') !== $status) continue;
        if ($von !== '' && (string)($q['von'] ?? '') !== $von) continue;
        if ($seit !== '' && !jh_neuer((string)($q['geaendert'] ?? ''), $seit)) continue;
        $liste[] = $q;
    }
    usort($liste, fn($a, $b) => strcmp((string)($b['geaendert'] ?? ''), (string)($a['geaendert'] ?? '')));
    jh_ende(['ok' => true, 'jetzt' => jh_jetzt(), 'rueckfragen' => array_slice($liste, 0, 100)]);

case 'rueckfrage':
    if (!$post) jh_fehler('nur POST', 400);
    $id = jh_text($koerper['id'] ?? '', 60);
    if (!preg_match('/^[a-z0-9][a-z0-9-]{2,59}$/', $id)) jh_fehler('id ungueltig ([a-z0-9-], 3-60 Zeichen)', 400);
    // Wer fragt: die Beraterin unter ihrem gebundenen Namen, ein Geraet als „claude" (oder was es angibt).
    $von = $jh_klasse === 'berater' ? (string)$jh_geraet : (jh_text($koerper['von'] ?? '', 40) ?: 'claude');
    if (!preg_match('/^[a-z0-9-]{2,40}$/', $von)) jh_fehler('von ungueltig', 400);
    if ($jh_klasse === 'berater' && !str_starts_with($id, $von . '-')) jh_fehler("id muss mit $von- beginnen", 400);
    $zurueck = (bool)($koerper['zurueckziehen'] ?? false);
    $felder = [];
    if (!$zurueck) {
        $frage = jh_text($koerper['frage'] ?? '', 500);
        if ($frage === '') jh_fehler('frage fehlt', 400);
        $optionen = [];
        foreach (array_slice((array)($koerper['optionen'] ?? []), 0, 4) as $o) { $o = jh_text($o, 160); if ($o !== '') $optionen[] = $o; }
        $link = jh_text($koerper['link'] ?? '', 400);
        /* bezug (16.09.2026): Madelene bittet um Kontext zu bis zu fuenf Rueckfragen — Bene gibt ihn im
           Compass frei oder nicht. Die Rezeption prueft nur die Form, nicht ob die ids existieren. */
        $bezug = [];
        foreach (array_slice((array)($koerper['bezug'] ?? []), 0, 5) as $b) {
            $b = jh_text($b, 60);
            if (preg_match('/^[a-z0-9][a-z0-9-]{2,59}$/', $b)) $bezug[] = $b;
        }
        $felder = [
            'projekt' => jh_text($koerper['projekt'] ?? '', 120) ?: $von,
            'frage' => $frage, 'warum' => jh_text($koerper['warum'] ?? '', 2000),
            'optionen' => $optionen, 'wann' => jh_rf_datum($koerper['wann'] ?? ''),
            'link' => preg_match('~^https?://~', $link) ? $link : null,
            'dringend' => (bool)($koerper['dringend'] ?? false),
            'bezug' => $bezug,
        ];
    }
    $antwortR = jh_schreiben(function (array $s) use ($id, $von, $zurueck, $felder, $jh_klasse) {
        $i = jh_rf_finde($s, $id);
        if ($i !== null && (string)($s['rueckfragen'][$i]['von'] ?? '') !== $von) {
            return $jh_klasse === 'berater'
                ? [$s, ['ok' => false, 'fehler' => 'id vergeben — bitte eine andere nehmen', 'code' => 409]]
                : [$s, ['ok' => false, 'fehler' => 'diese Rueckfrage gehoert ' . (string)$s['rueckfragen'][$i]['von'], 'code' => 403]];
        }
        if ($zurueck) {
            if ($i === null) return [$s, ['ok' => false, 'fehler' => 'Rueckfrage nicht gefunden', 'code' => 404]];
            $st = (string)($s['rueckfragen'][$i]['status'] ?? '');
            if ($st === 'beantwortet') return [$s, ['ok' => false, 'fehler' => 'schon beantwortet', 'code' => 409]];
            $s['rueckfragen'][$i]['status'] = 'zurueckgezogen';
            $s['rueckfragen'][$i]['geaendert'] = jh_jetzt();
            $s = jh_logzeile($s, 'rueckfrage', "zurueckgezogen: $id ($von)");
            return [$s, ['ok' => true, 'id' => $id, 'status' => 'zurueckgezogen', 'offen' => jh_rf_offen($s, $von)]];
        }
        if ($i !== null) {
            $st = (string)($s['rueckfragen'][$i]['status'] ?? '');
            if ($st === 'beantwortet') return [$s, ['ok' => false, 'fehler' => 'schon beantwortet — neue id nehmen', 'code' => 409]];
            $gleich = ($st === 'offen');
            foreach ($felder as $k => $v) { if (($s['rueckfragen'][$i][$k] ?? null) !== $v) { $gleich = false; break; } }
            // Wiederholung nach Verbindungsfehler: nichts schreiben, nichts verschieben (docs/protokoll.md › idempotent).
            if ($gleich) return [$s, ['ok' => true, 'id' => $id, 'status' => 'offen', 'unveraendert' => true, 'offen' => jh_rf_offen($s, $von)]];
            if ($jh_klasse === 'berater' && $felder['dringend'] && empty($s['rueckfragen'][$i]['dringend']) && jh_rf_dringend($s, $von) >= 1) {
                return [$s, ['ok' => false, 'fehler' => 'schon eine dringende offene Rueckfrage', 'code' => 409]];
            }
            $s['rueckfragen'][$i] = array_merge($s['rueckfragen'][$i], $felder, ['status' => 'offen', 'geaendert' => jh_jetzt()]);
            $s = jh_logzeile($s, 'rueckfrage', "geaendert: $id ($von)");
            return [$s, ['ok' => true, 'id' => $id, 'status' => 'offen', 'offen' => jh_rf_offen($s, $von)]];
        }
        if ($jh_klasse === 'berater' && jh_rf_offen($s, $von) >= JH_RF_JE_VON) return [$s, ['ok' => false, 'fehler' => 'schon ' . JH_RF_JE_VON . ' offene Rueckfragen von ' . $von, 'code' => 409]];
        if ($jh_klasse === 'berater' && $felder['dringend'] && jh_rf_dringend($s, $von) >= 1) return [$s, ['ok' => false, 'fehler' => 'schon eine dringende offene Rueckfrage', 'code' => 409]];
        if (jh_rf_offen($s) >= JH_RF_MAX) return [$s, ['ok' => false, 'fehler' => 'zu viele offene Rueckfragen', 'code' => 409]];
        $s['rueckfragen'][] = ['id' => $id, 'von' => $von] + $felder + [
            'erstellt' => jh_jetzt(), 'geaendert' => jh_jetzt(), 'status' => 'offen', 'antwort' => null,
        ];
        $s = jh_logzeile($s, 'rueckfrage', "neu: $id ($von)");
        return [$s, ['ok' => true, 'id' => $id, 'status' => 'offen', 'offen' => jh_rf_offen($s, $von)]];
    });
    jh_ende($antwortR, (int)($antwortR['code'] ?? 200) >= 400 ? (int)$antwortR['code'] : 200);

case 'rueckfrage-antwort':
    if (!$post) jh_fehler('nur POST', 400);
    $id = jh_text($koerper['id'] ?? '', 60);
    $a  = jh_text($koerper['a'] ?? '', 200);
    if ($id === '' || $a === '') jh_fehler('id und a noetig', 400);
    $wer = jh_text($koerper['wer'] ?? $jh_klasse, 20);
    if (!in_array($wer, ['compass', 'checkin', 'claude', 'geraet', 'browser'], true)) $wer = $jh_klasse;
    $ts = jh_rf_datum($koerper['ts'] ?? '');
    $antwortA = jh_schreiben(function (array $s) use ($id, $a, $wer, $ts) {
        $i = jh_rf_finde($s, $id);
        if ($i === null) return [$s, ['ok' => false, 'fehler' => 'Rueckfrage nicht gefunden', 'code' => 404]];
        if ((string)($s['rueckfragen'][$i]['status'] ?? '') === 'zurueckgezogen') return [$s, ['ok' => false, 'fehler' => 'zurueckgezogen', 'code' => 409]];
        $alt = $s['rueckfragen'][$i]['antwort'] ?? null;
        if (is_array($alt) && ($alt['a'] ?? '') === $a) return [$s, ['ok' => true, 'id' => $id, 'unveraendert' => true]];
        $s['rueckfragen'][$i]['status'] = 'beantwortet';
        $s['rueckfragen'][$i]['antwort'] = ['a' => $a, 'ts' => $ts, 'wer' => $wer, 'zeit' => jh_jetzt()];
        $s['rueckfragen'][$i]['geaendert'] = jh_jetzt();
        $s = jh_logzeile($s, 'rueckfrage', "beantwortet: $id (" . (string)($s['rueckfragen'][$i]['von'] ?? '?') . ", $wer)");
        return [$s, ['ok' => true, 'id' => $id, 'status' => 'beantwortet']];
    });
    jh_ende($antwortA, (int)($antwortA['code'] ?? 200) >= 400 ? (int)$antwortA['code'] : 200);

case 'freigaben':
    /* Eine Beraterin sieht nur, was fuer sie freigegeben und noch nicht abgelaufen ist. */
    $fuer = $jh_klasse === 'berater' ? (string)$jh_geraet : jh_name($_GET['fuer'] ?? '');
    $liste = [];
    foreach (jh_lesen()['freigaben'] as $f) {
        if (!jh_fg_gueltig($f)) continue;
        if ($fuer !== '' && (string)($f['fuer'] ?? '') !== $fuer) continue;
        $liste[] = $f;
    }
    usort($liste, fn($a, $b) => strcmp((string)($b['erstellt'] ?? ''), (string)($a['erstellt'] ?? '')));
    jh_ende(['ok' => true, 'jetzt' => jh_jetzt(), 'freigaben' => $liste]);

case 'freigabe':
    /* Nur Bene (Compass im Browser) oder ein Geraet in seinem Auftrag. Beraterinnen haben das Recht nicht. */
    if (!$post) jh_fehler('nur POST', 400);
    $fid = jh_text($koerper['id'] ?? '', 40);
    if (!empty($koerper['widerrufen'])) {
        if ($fid === '') jh_fehler('id fehlt', 400);
        $antwortW = jh_schreiben(function (array $s) use ($fid) {
            $i = jh_fg_finde($s, $fid);
            if ($i === null) return [$s, ['ok' => false, 'fehler' => 'Freigabe nicht gefunden', 'code' => 404]];
            $fuer = (string)($s['freigaben'][$i]['fuer'] ?? '?');
            array_splice($s['freigaben'], $i, 1);          // Widerruf loescht, er blendet nicht nur aus
            $s = jh_logzeile($s, 'freigabe', "widerrufen: $fid ($fuer)");
            return [$s, ['ok' => true, 'id' => $fid, 'widerrufen' => true]];
        });
        jh_ende($antwortW, (int)($antwortW['code'] ?? 200) >= 400 ? (int)$antwortW['code'] : 200);
    }
    $fuer = jh_name($koerper['fuer'] ?? '');
    if ($fuer === '') jh_fehler('fuer fehlt ([a-z0-9-], z. B. madelene)', 400);
    $frage = jh_text($koerper['frage'] ?? '', 800);
    if ($frage === '') jh_fehler('frage fehlt', 400);
    $antwort = jh_text($koerper['antwort'] ?? '', 400);
    $notiz = jh_text($koerper['notiz'] ?? '', 800);
    $bezug = jh_text($koerper['bezug'] ?? '', 60);
    if ($bezug !== '' && !preg_match('/^[a-z0-9][a-z0-9-]{2,59}$/', $bezug)) $bezug = '';
    $tage = max(1, min(JH_FG_TAGE, (int)($koerper['tage'] ?? JH_FG_TAGE)));
    $muster = jh_muster($frage . "\n" . $antwort . "\n" . $notiz);
    if ($muster && empty($koerper['trotzdem'])) {
        jh_ende(['ok' => false, 'fehler' => 'Text enthaelt vermutlich Vertrauliches', 'muster' => $muster], 422);
    }
    $eintrag = ['fuer' => $fuer, 'bezug' => $bezug ?: null, 'frage' => $frage,
                'antwort' => $antwort !== '' ? $antwort : null, 'notiz' => $notiz !== '' ? $notiz : null,
                'bis' => (new DateTimeImmutable('now'))->modify("+$tage days")->format('Y-m-d'),
                'bestaetigt' => $muster ?: null];
    $antwortF = jh_schreiben(function (array $s) use ($fid, $eintrag) {
        $i = $fid !== '' ? jh_fg_finde($s, $fid) : null;
        if ($i === null && $eintrag['bezug']) {          // dieselbe Frage fuer dieselbe Person ersetzt sich
            foreach ($s['freigaben'] as $k => $f) {
                if (($f['bezug'] ?? null) === $eintrag['bezug'] && ($f['fuer'] ?? '') === $eintrag['fuer']) { $i = $k; break; }
            }
        }
        if ($i !== null) {
            $s['freigaben'][$i] = array_merge($s['freigaben'][$i], $eintrag, ['geaendert' => jh_jetzt()]);
            $id = (string)$s['freigaben'][$i]['id'];
            $s = jh_logzeile($s, 'freigabe', "erneuert: $id fuer " . $eintrag['fuer']);
            return [$s, ['ok' => true, 'id' => $id, 'bis' => $eintrag['bis'], 'erneuert' => true]];
        }
        $id = jh_id('fg-');
        $s['freigaben'][] = ['id' => $id] + $eintrag + ['erstellt' => jh_jetzt()];
        $s = jh_logzeile($s, 'freigabe', "neu: $id fuer " . $eintrag['fuer']);
        return [$s, ['ok' => true, 'id' => $id, 'bis' => $eintrag['bis']]];
    });
    jh_ende($antwortF);

case 'gedaechtnis':
    /* Madelenes gemeinsames Gedaechtnis: Astra (Beraterin) und die lokale Laufzeit (Geraet) schreiben,
       beide lesen. Nur Saetze ohne Betraege, Kontodaten, Adressen und Telefonnummern. */
    $fuer = $jh_klasse === 'berater' ? (string)$jh_geraet : jh_name($post ? ($koerper['fuer'] ?? '') : ($_GET['fuer'] ?? ''));
    if ($fuer === '') jh_fehler('fuer fehlt', 400);
    if (!$post) {
        $liste = jh_lesen()['gedaechtnis'][$fuer] ?? [];
        jh_ende(['ok' => true, 'jetzt' => jh_jetzt(), 'fuer' => $fuer, 'eintraege' => array_reverse(array_slice($liste, -50))]);
    }
    if ($jh_klasse === 'browser') jh_fehler('der Browser liest das Gedaechtnis nur', 403);
    $text = jh_text($koerper['text'] ?? '', 1500);
    if ($text === '') jh_fehler('text fehlt', 400);
    $muster = jh_muster($text);
    if ($muster) jh_ende(['ok' => false, 'fehler' => 'ins gemeinsame Gedaechtnis gehoert nichts Vertrauliches', 'muster' => $muster], 422);
    $von = $jh_klasse === 'berater' ? 'astra' : ('lokal:' . ($jh_geraet ?? 'geraet'));
    $thema = jh_text($koerper['thema'] ?? '', 80);
    $antwortG = jh_schreiben(function (array $s) use ($fuer, $text, $von, $thema) {
        foreach ($s['gedaechtnis'][$fuer] ?? [] as $e) {
            if (($e['text'] ?? '') === $text) return [$s, ['ok' => true, 'unveraendert' => true]];
        }
        $id = jh_id('gd-');
        $s['gedaechtnis'][$fuer][] = ['id' => $id, 'von' => $von, 'thema' => $thema !== '' ? $thema : null, 'ts' => jh_jetzt(), 'text' => $text];
        $s = jh_logzeile($s, 'gedaechtnis', "neu: $id ($fuer, $von)");
        return [$s, ['ok' => true, 'id' => $id]];
    });
    jh_ende($antwortG);

case 'persona':
    /* Eine Persona fuer beide Laufwege. Hochladen darf nur ein Geraet (hub-deploy.ps1), lesen die Beraterin
       ihre eigene. Liegt als Datei neben stand.json, .htaccess sperrt .md. */
    $fuer = $jh_klasse === 'berater' ? (string)$jh_geraet : jh_name($post ? ($koerper['fuer'] ?? '') : ($_GET['fuer'] ?? ''));
    if ($fuer === '') jh_fehler('fuer fehlt', 400);
    $datei = jh_persona_datei($fuer);
    if (!$post) {
        if (!is_file($datei)) jh_ende(['ok' => false, 'fehler' => 'keine Persona hinterlegt', 'fuer' => $fuer], 404);
        jh_ende(['ok' => true, 'fuer' => $fuer, 'stand' => date('c', (int)filemtime($datei)), 'text' => (string)file_get_contents($datei)]);
    }
    if ($jh_klasse !== 'geraet') jh_fehler('nur ein Geraet laedt die Persona hoch', 403);
    $text = mb_substr(str_replace("\r", '', (string)($koerper['text'] ?? '')), 0, JH_PERSONA_MAX);
    if (trim($text) === '') jh_fehler('text fehlt', 400);
    $muster = jh_muster($text);
    if ($muster) jh_ende(['ok' => false, 'fehler' => 'Persona enthaelt vermutlich Vertrauliches', 'muster' => $muster], 422);
    if (!is_dir(JH_DATEN)) { @mkdir(JH_DATEN, 0700, true); }
    if (@file_put_contents($datei, $text, LOCK_EX) === false) jh_fehler('Persona nicht schreibbar', 500);
    jh_ende(jh_schreiben(function (array $s) use ($fuer, $text) {
        $s = jh_logzeile($s, 'persona', "hochgeladen: $fuer (" . mb_strlen($text) . ' Zeichen)');
        return [$s, ['ok' => true, 'fuer' => $fuer, 'zeichen' => mb_strlen($text)]];
    }));

default:
    jh_fehler('unbekannt: w=' . jh_text($was, 40) . ' (stand, puls, stapel, punkt, auftrag, auftraege, nimm, ergebnis, log, spiegel, stapelstand, stopp, rueckfragen, rueckfrage, rueckfrage-antwort, freigabe, freigaben, gedaechtnis, persona)', 400);
}

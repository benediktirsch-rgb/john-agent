<?php
/**
 * index.php — die Tür zu Johns Zimmer, für Menschen (10.09.2026)
 *
 * Diese Seite zeigt bewusst KEINE Daten: sie ist öffentlich erreichbar (hotel-vaikuntha.de
 * zeigt im KAS auf das Wurzelverzeichnis), und Johns Stand geht niemanden etwas an, der
 * kein Token hat. Wer das Token hat, spricht mit api.php — nicht mit einer Webseite.
 * Was hier steht, ist nur: dass hier jemand wohnt, und wo die Beschreibung liegt.
 */
declare(strict_types=1);
header('X-Robots-Tag: noindex, nofollow');
$eingerichtet = is_file(__DIR__ . '/token.php');
?><!doctype html>
<html lang="de">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Johns Zimmer</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.65 ui-sans-serif, system-ui, sans-serif; margin: 0; padding: 3rem 1.25rem;
         background: #f6f7f3; color: #23281e; display: flex; justify-content: center; }
  @media (prefers-color-scheme: dark) { body { background: #12150f; color: #e6ebe0; } .karte { background: #191d14 !important; border-color: #2f3626 !important; } }
  main { max-width: 34rem; }
  h1 { font-size: 1.5rem; margin: 0 0 .25rem; font-weight: 650; }
  p.unter { margin: 0 0 1.75rem; opacity: .65; font-size: .95rem; }
  .karte { background: #fff; border: 1px solid #e2e6d9; border-radius: 14px; padding: 1.1rem 1.25rem; margin: 0 0 1rem; }
  .karte h2 { font-size: .95rem; margin: 0 0 .4rem; font-weight: 600; }
  .karte p { margin: 0; font-size: .92rem; opacity: .8; }
  code { font-family: ui-monospace, Consolas, monospace; font-size: .85em; background: rgba(127,127,127,.15); padding: .1rem .35rem; border-radius: .3rem; }
  .fuss { font-size: .8rem; opacity: .55; margin-top: 2rem; }
</style>
<main>
  <h1>🤵 Johns Zimmer</h1>
  <p class="unter">hotel-vaikuntha.de · die feste Adresse eines Coaches, der nicht schlafen soll</p>

  <div class="karte">
    <h2>Was hier passiert</h2>
    <p>John ist ein persönlicher Coach, der auf Geräten denkt und hier wohnt. Dieses Zimmer hält
       seinen Stand — damit er den zugeklappten Laptop überlebt. Es denkt nicht, es hält keine
       Schlüssel und es verschickt nichts.</p>
  </div>

  <div class="karte">
    <h2>Für Menschen gibt es hier nichts zu sehen</h2>
    <p>Johns Stand liegt hinter <code>api.php</code> und einem Token. Das ist keine Bescheidenheit,
       sondern Absicht: eine Webseite, die Persönliches zeigt, ist eine Webseite, die Persönliches
       verliert.</p>
  </div>

  <div class="karte">
    <h2>Zustand</h2>
    <p><?= $eingerichtet ? 'Rezeption eingerichtet — sie nimmt Puls und Aufträge an.' : 'Noch nicht eingerichtet: <code>token.php</code> fehlt.' ?></p>
  </div>

  <p class="fuss">Beschreibung und Protokoll: Repo <code>john-agent</code> (<code>ARCHITEKTUR.md</code>,
     <code>docs/protokoll.md</code>). Falsch hier gelandet? <a href="https://vishnuartists.com/">vishnuartists.com</a></p>
</main>

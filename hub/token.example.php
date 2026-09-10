<?php
/**
 * token.example.php — Vorlage. Die echte Datei heißt token.php, liegt NUR auf dem Server
 * und steht in .gitignore.
 *
 * Angelegt wird sie von hub-deploy.ps1 aus der User-Umgebungsvariable JOHN_HUB_TOKEN:
 * gespeichert wird nie das Token selbst, sondern sein SHA-256. Wer die Datei liest, kann
 * damit nichts anfangen; wer das Token hat, kommt durch.
 *
 * Von Hand:
 *   PowerShell:  $t='<das-token>'; ($sha=[Security.Cryptography.SHA256]::Create()).
 *                ComputeHash([Text.Encoding]::UTF8.GetBytes($t)) |
 *                ForEach-Object { $_.ToString('x2') } | Join-String
 */
return [
    'hash' => 'HIER_DER_SHA256_DES_TOKENS',
];

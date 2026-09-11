<#
  hub-deploy.ps1 — Johns Rezeption ins WWW bringen (10.09.2026)

  Lädt hub\ per FTPS (explizit, AUTH TLS) auf den KAS-Webspace. Dasselbe Muster wie
  publish-compass.ps1: Zugang ausschließlich aus User-Umgebungsvariablen, nie aus einer
  Datei und nie über die Kommandozeile.

  Wohin
    Standard ist /john/ im WURZELVERZEICHNIS des Webspace. Das ist kein Zufall: die Domain
    hotel-vaikuntha.de zeigt im KAS auf genau dieses Verzeichnis (kein eigenes Dokumenten-
    verzeichnis, kein Zertifikat — Stand 10.09.2026). Damit ist die Rezeption ab der ersten
    Sekunde erreichbar unter
        https://naturnah-lernen.de/john/     (hat ein Zertifikat, geht sofort)
        http://hotel-vaikuntha.de/john/      (dieselben Dateien, noch ohne TLS)
    Sobald Bene der Domain im KAS ein eigenes Dokumentenverzeichnis und ein Let's-Encrypt-
    Zertifikat gibt (docs\kas-schritte.md), zeigt -Ziel dorthin und JOHN_HUB_URL wandert mit.

  Zugänge (User-Umgebungsvariablen)
    VA_FTP_HOST / VA_FTP_USER / VA_FTP_PASS   FTPS-Zugang zum KAS
    JOHN_HUB_TOKEN                            Johns Token; -TokenErzeugen legt eines an

  Aufruf
    hub-deploy.ps1                 hochladen und danach wirklich abfragen
    hub-deploy.ps1 -TokenErzeugen  neues Token würfeln, als User-Variable setzen, hochladen
    hub-deploy.ps1 -NurPruefen     nichts hochladen, nur die Live-Adresse abfragen
    hub-deploy.ps1 -Ziel '/hotel-vaikuntha.de'   eigenes Dokumentenverzeichnis (später)
#>
param(
  [string]$Ziel = '/john',
  [string]$Adresse = '',
  [switch]$TokenErzeugen,
  [switch]$NurPruefen
)
$ErrorActionPreference = 'Stop'
$Hier = Split-Path -Parent $MyInvocation.MyCommand.Path
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

function LiesEnv([string]$n) {
  foreach ($s in @('Process','User')) { $v = [Environment]::GetEnvironmentVariable($n, $s); if ($v -and $v.Trim()) { return $v.Trim() } }
  return $null
}
function Sag($m, $f = 'Gray') { Write-Host $m -ForegroundColor $f }

# ── Token ────────────────────────────────────────────────────────────────────────────────
# Gespeichert wird auf dem Server nur der SHA-256. Das Token selbst lebt in Benes
# Benutzerumgebung und in keiner Datei dieses Repos.
$token = LiesEnv 'JOHN_HUB_TOKEN'
if ($TokenErzeugen) {
  $roh = New-Object byte[] 32
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($roh)
  $token = ([BitConverter]::ToString($roh) -replace '-','').ToLower()
  [Environment]::SetEnvironmentVariable('JOHN_HUB_TOKEN', $token, 'User')
  $env:JOHN_HUB_TOKEN = $token
  Sag 'Neues Token erzeugt und als Benutzer-Umgebungsvariable JOHN_HUB_TOKEN gesetzt.' 'Green'
  Sag '  Wirksam in neuen Prozessen — laufender Worker bekommt es beim nächsten Start.' 'DarkGray'
}
if (-not $token) {
  Sag 'JOHN_HUB_TOKEN fehlt. Einmalig: hub-deploy.ps1 -TokenErzeugen' 'Red'
  return
}
function Hash256([string]$s) {
  $sha = [Security.Cryptography.SHA256]::Create()
  return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($s))) -replace '-','').ToLower()
}
$hash = Hash256 $token

# Zweiter Schluessel fuer den Browser (11.09.2026, Madeleines Einwand): die Lobby braucht nur
# nachsehen, abraeumen, fragen. Bekaeme sie den Geraeteschluessel, waere ein Leck im Browser ein
# Leck fuer alles. Dieser hier laesst sich einzeln neu wuerfeln, ohne ein Geraet anzuhalten.
$browser = LiesEnv 'JOHN_HUB_TOKEN_BROWSER'
if ($TokenErzeugen -or -not $browser) {
  $roh2 = New-Object byte[] 32
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($roh2)
  $browser = ([BitConverter]::ToString($roh2) -replace '-','').ToLower()
  [Environment]::SetEnvironmentVariable('JOHN_HUB_TOKEN_BROWSER', $browser, 'User')
  $env:JOHN_HUB_TOKEN_BROWSER = $browser
  Sag 'Browser-Schluessel erzeugt (JOHN_HUB_TOKEN_BROWSER). Compass danach neu bauen.' 'Green'
}
$hashBrowser = Hash256 $browser

if (-not $Adresse) {
  $Adresse = if ($Ziel -eq '/john') { 'https://hotel-vaikuntha.de/john' } else { 'https://hotel-vaikuntha.de' }
}
$Adresse = $Adresse.TrimEnd('/')

# ── Prüfen: antwortet die Rezeption wirklich? ────────────────────────────────────────────
function Pruefe {
  try {
    $req = [Net.HttpWebRequest]::Create("$Adresse/api.php?w=stand")
    $req.Method = 'GET'; $req.Timeout = 20000; $req.Headers['X-John-Token'] = $token
    $req.UserAgent = 'john-hub-deploy'
    $res = $req.GetResponse()
    $sr = New-Object IO.StreamReader($res.GetResponseStream(), [Text.Encoding]::UTF8)
    $txt = $sr.ReadToEnd(); $sr.Close(); $res.Close()
    $d = $txt | ConvertFrom-Json
    if ($d.ok) {
      Sag "Rezeption antwortet: $Adresse/api.php" 'Green'
      Sag ("  Geräte: " + $(if (@($d.geraete).Count) { (@($d.geraete | ForEach-Object { $_.name + $(if ($_.wach) { ' (wach)' } else { ' (schläft)' }) }) -join ', ') } else { 'noch keines' }))
      Sag ("  Stapel: " + @($d.stapel.punkte).Count + " Punkt(e), Stand " + $(if ($d.stapel.stand) { $d.stapel.stand } else { '—' }))
      return $true
    }
    Sag "Rezeption antwortet, aber nicht ok: $txt" 'Yellow'; return $false
  } catch {
    $code = ''
    try { if ($_.Exception.Response) { $code = ' (HTTP ' + [int]$_.Exception.Response.StatusCode + ')' } } catch { }
    Sag "Rezeption antwortet nicht$code : $($_.Exception.Message)" 'Red'
    return $false
  }
}

if ($NurPruefen) { Pruefe | Out-Null; return }

# ── FTPS ─────────────────────────────────────────────────────────────────────────────────
$zugang = @{}
foreach ($k in 'VA_FTP_HOST','VA_FTP_USER','VA_FTP_PASS') {
  $v = LiesEnv $k
  if (-not $v) { Sag "$k fehlt — ohne FTPS-Zugang kann ich nichts hochladen." 'Red'; return }
  $zugang[$k] = $v
}
function NeuAnfrage([string]$fern, [string]$methode) {
  $a = [Net.FtpWebRequest]::Create('ftp://' + $zugang.VA_FTP_HOST + $fern)
  $a.Credentials = New-Object Net.NetworkCredential($zugang.VA_FTP_USER, $zugang.VA_FTP_PASS)
  $a.EnableSsl = $true; $a.UsePassive = $true; $a.UseBinary = $true; $a.KeepAlive = $false
  $a.Timeout = 30000; $a.ReadWriteTimeout = 60000; $a.Method = $methode
  return $a
}
function SichereOrdner([string]$fern) {
  try { $r = (NeuAnfrage $fern ([Net.WebRequestMethods+Ftp]::MakeDirectory)).GetResponse(); $r.Close(); Sag "  Ordner angelegt: $fern" }
  catch { if ("$($_.Exception.Message)" -notmatch '550') { throw } }
}
function LadeText([string]$text, [string]$fern) {
  $bytes = $Utf8NoBom.GetBytes($text.Replace("`r`n", "`n"))
  $a = NeuAnfrage $fern ([Net.WebRequestMethods+Ftp]::UploadFile)
  $a.ContentLength = $bytes.Length
  $s = $a.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
  $r = $a.GetResponse(); $r.Close()
  Sag ("  hoch: {0,-22} {1,7:n0} B" -f ([IO.Path]::GetFileName($fern)), $bytes.Length)
}

Sag "Johns Rezeption -> $($zugang.VA_FTP_HOST)$Ziel/" 'Cyan'
SichereOrdner $Ziel
SichereOrdner "$Ziel/daten"

foreach ($d in @('api.php','index.php','.htaccess')) {
  $lokal = Join-Path $Hier $d
  if (-not (Test-Path $lokal)) { Sag "  fehlt lokal: $d" 'Yellow'; continue }
  LadeText ([IO.File]::ReadAllText($lokal, [Text.Encoding]::UTF8)) "$Ziel/$d"
}
LadeText ([IO.File]::ReadAllText((Join-Path $Hier 'daten\.htaccess'), [Text.Encoding]::UTF8)) "$Ziel/daten/.htaccess"

# token.php entsteht hier und liegt nur auf dem Server — nie im Repo (.gitignore).
$tokenPhp = @"
<?php
/* Erzeugt von hub-deploy.ps1 am $(Get-Date -Format 'dd.MM.yyyy HH:mm'). Enthaelt nur den
   SHA-256 des Tokens, nie das Token selbst. Nicht von Hand aendern - beim naechsten
   Deploy wird die Datei ueberschrieben. */
return [
    'hash'         => '$hash',          /* Geraete: alles */
    'hash_browser' => '$hashBrowser',   /* Browser: stand, punkt, auftrag */
];
"@
LadeText $tokenPhp "$Ziel/token.php"

Sag ''
Sag 'Hochgeladen. Jetzt die Probe aufs Exempel:' 'Cyan'
$ok = Pruefe
Sag ''
if ($ok) {
  Sag "Adresse für den Worker:  JOHN_HUB_URL = $Adresse" 'Green'
  $ist = LiesEnv 'JOHN_HUB_URL'
  if ($ist -ne $Adresse) {
    [Environment]::SetEnvironmentVariable('JOHN_HUB_URL', $Adresse, 'User')
    Sag "  (als Benutzer-Umgebungsvariable gesetzt — Worker beim nächsten Start neu einlesen lassen)" 'DarkGray'
  }
} else {
  Sag 'Wenn die Adresse 404 sagt: zeigt die Domain im KAS wirklich auf dieses Verzeichnis?' 'Yellow'
  Sag 'Wenn sie 500 sagt: PHP-Version im KAS prüfen (8.0+) und Schreibrechte auf daten/.' 'Yellow'
  Sag 'docs\kas-schritte.md hat die Reihenfolge.' 'Yellow'
}

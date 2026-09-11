<#
  john-worker.ps1 — Johns Hände auf diesem Gerät (10.09.2026)

  Warum es diesen Prozess gibt
    Bis heute war John dasselbe wie der Cockpit-Server: ein PowerShell-Prozess mit einer
    seriellen HttpListener-Schleife, der den Compass ausliefert UND für John denkt. Ein
    Denkvorgang dauert 60–90 s; solange antwortete der Server auf nichts. Im Browser stand
    dann „John-Server nicht erreichbar" — derselbe Satz wie bei einem toten Server. Bene
    konnte „belegt", „hängt" und „aus" nicht unterscheiden, und ein Watchdog mehr hätte daran
    nichts geändert.

  Was dieser Prozess tut — drei Dinge, keines davon langsam
    1) TÜR  (HTTP auf Port 8788): /stand antwortet in Millisekunden, immer. Sie ist die
       einzige Stelle, die die Wahrheit über den großen Server sagen kann, weil sie NEBEN
       ihm lebt und nicht in ihm. /wecken startet ihn — deshalb kann der Knopf in Johns
       Lobby wirklich starten und braucht keinen Protokoll-Handler in der Registry.
    2) TAKT: Johns eigener Rhythmus. Er schaut in seinem Arbeitsfenster von selbst nach,
       ob etwas eine Handlung braucht, statt auf eine Frage zu warten. Das ist der
       Unterschied zwischen einem Endpunkt und einem Agenten.
    3) PULS an die Rezeption (hotel-vaikuntha.de/john/): damit Johns Stand den Laptopdeckel
       überlebt und das Handy weiß, wie es ihm geht.

  Die eiserne Regel dieses Skripts: NICHTS in dieser Schleife wartet auf ein Modell, auf eine
  Website oder auf eine Datei im Netz. Jede Prüfung ist ein Task, dessen Ergebnis in einem
  späteren Durchlauf abgeholt wird; jede Denkarbeit ist ein abgekoppelter Kindprozess
  (john-auftrag.ps1). Wer hier ein synchrones Invoke-WebRequest einbaut, baut das Problem
  wieder ein, das dieser Prozess löst.

  Bedienung
    -Status        einmal nachsehen und berichten, nichts starten
    -Einmal        einen Takt sofort laufen lassen (im Vordergrund), dann Ende
    -Port 8788     Tür (Standard 8788)
    -TaktMinuten   Abstand zwischen zwei Takten (Standard 30)
    -OhneTakt      nur Tür und Puls, kein eigener Rhythmus
    -OhneHub       nicht mit der Rezeption reden (lokal testen)

  Aufgaben einrichten: john-aufgaben.ps1 -Register
#>
param(
  [int]$Port = 8788,
  [int]$ServerPort = 8787,
  [int]$TaktMinuten = 30,
  [string]$Hub,
  [string]$Geraet,
  [switch]$Status,
  [switch]$Einmal,
  [switch]$OhneTakt,
  [switch]$OhneHub
)
$ErrorActionPreference = 'Stop'
$VERSION = '1.1.0'   # 1.1: Spiegel fuer Johns Kachel auf allen Geraeten

Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

$Utf8NoBom  = New-Object Text.UTF8Encoding($false)
$Hier       = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoWurzel = Split-Path -Parent $Hier
$Compass    = 'C:\dev\persoenliches-dashboard'
$JohnDir    = 'C:\dev\john'
$LogDatei   = Join-Path $Hier 'john-worker.log'
$StandDatei = Join-Path $Hier 'worker-stand.json'
$AuftragPs1 = Join-Path $Hier 'john-auftrag.ps1'

function LiesEnv([string]$name, $std) {
  foreach ($scope in @('Process','User')) {
    $v = [Environment]::GetEnvironmentVariable($name, $scope)
    if ($v -and $v.Trim()) { return $v.Trim() }
  }
  return $std
}
if (-not $Geraet) { $Geraet = LiesEnv 'JOHN_GERAET' ($env:COMPUTERNAME.ToLower()) }
if (-not $Hub)    { $Hub    = LiesEnv 'JOHN_HUB_URL' 'https://hotel-vaikuntha.de/john' }
$HubToken = LiesEnv 'JOHN_HUB_TOKEN' ''
$Hub = ([string]$Hub).TrimEnd('/')
if (-not $HubToken) { $OhneHub = $true }

function Log([string]$m, [string]$farbe = 'Gray') {
  $zeile = "{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $m
  try {
    # Log kappen: erst vollständig lesen, DANN schreiben — ein offener Lesestrom beim
    # Schreiben hat schon einen anderen Lauf stillschweigend getötet.
    if (Test-Path $LogDatei) {
      $alt = @([IO.File]::ReadAllLines($LogDatei, [Text.Encoding]::UTF8))
      if ($alt.Count -gt 600) { [IO.File]::WriteAllLines($LogDatei, $alt[-300..-1], $Utf8NoBom) }
    }
    Add-Content -Path $LogDatei -Value $zeile -Encoding UTF8
  } catch { }
  Write-Host $zeile -ForegroundColor $farbe
}

# ── Der große Server: läuft er? antwortet er? ────────────────────────────────────────────
# Der Prozessfilter muss scharf sein (dieselbe Falle wie in john-server-aufgabe.ps1): mit
# -File gestartet, nicht mit -Command, und nie der eigene Prozess. Sonst zählt jede Konsole
# mit, in deren Befehlszeile der Dateiname zufällig vorkommt.
$script:ProzCache = $null; $script:ProzZeit = [datetime]::MinValue
function ServerProzesse([int]$maxAlterSek = 5) {
  if ($script:ProzCache -ne $null -and ((Get-Date) - $script:ProzZeit).TotalSeconds -lt $maxAlterSek) { return $script:ProzCache }
  $treffer = @()
  try {
    $treffer = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
      Where-Object {
        $_.CommandLine -and $_.ProcessId -ne $PID -and
        $_.CommandLine -notlike '*-Command*' -and $_.CommandLine -like '*-File*' -and
        $_.CommandLine -like '*john-server.ps1*'
      })
  } catch { }
  $script:ProzCache = $treffer; $script:ProzZeit = Get-Date
  return $treffer
}

$script:Http = New-Object System.Net.Http.HttpClient
$script:Http.Timeout = [TimeSpan]::FromSeconds(8)
$script:ProbeTask = $null; $script:ProbeStart = [datetime]::MinValue
$script:ServerAntwortet = $null      # $null = noch nie geprüft; sonst: dreht sich die Schleife?
$script:ServerOk = $null             # $null = noch nie geprüft; sonst: taugt die Antwort auch?
$script:ServerCode = 0
$script:ServerAntwortZeit = [datetime]::MinValue
$script:ProbeFehlschlaege = 0

# Gefragt wird „localhost", nicht „127.0.0.1": der Cockpit-Server meldet bei http.sys das
# Präfix http://localhost:8787/ an, und http.sys prüft den Host-Kopf. Über die IP kommt
# darum ein 400 zurück — eine Antwort, aber keine brauchbare. Genau diese Unterscheidung
# braucht die Lobby, um „läuft, aber diese Seite erreicht ihn nicht" sagen zu können.
function ProbeStarten {
  if ($script:ProbeTask) { return }
  try {
    $script:ProbeTask = $script:Http.GetAsync("http://localhost:$ServerPort/api/john/status")
    $script:ProbeStart = Get-Date
  } catch { $script:ProbeTask = $null }
}
function ProbeAbholen {
  if (-not $script:ProbeTask) { return }
  if (-not $script:ProbeTask.IsCompleted) {
    # 12 s ohne Antwort gelten als Hänger-Verdacht; das Ergebnis holen wir trotzdem später ab.
    if (((Get-Date) - $script:ProbeStart).TotalSeconds -gt 12 -and $script:ServerAntwortet -ne $false) {
      $script:ServerAntwortet = $false
    }
    return
  }
  $antwort = $false; $gut = $false; $code = 0
  try {
    if ($script:ProbeTask.Status -eq 'RanToCompletion') {
      $antwort = $true
      $r = $script:ProbeTask.Result
      $code = [int]$r.StatusCode
      $gut = $r.IsSuccessStatusCode
      $r.Dispose()
    }
  } catch { }
  $script:ProbeTask = $null
  $script:ServerCode = $code
  if ($antwort) {
    # Eine HTTP-Fehlerantwort beweist, dass die Schleife sich dreht — das ist kein Hänger.
    # Ob die Antwort auch taugt, ist eine zweite Frage und wird getrennt geführt.
    $script:ServerAntwortet = $true; $script:ServerOk = $gut
    if ($gut) { $script:ServerAntwortZeit = Get-Date; $script:ProbeFehlschlaege = 0 }
  } else {
    $script:ServerAntwortet = $false; $script:ServerOk = $false; $script:ProbeFehlschlaege++
  }
}

# ── Wecken: den Cockpit-Server zurückholen ───────────────────────────────────────────────
# Reihenfolge mit Bedacht: einen HÄNGER (Prozess da, keine Antwort) erst beenden, sonst
# verwirft die geplante Aufgabe den Start (MultipleInstances=IgnoreNew sieht ihn als „läuft").
# Danach die Aufgabe anstoßen; nur wenn es die Aufgabe nicht gibt, selbst starten.
function Wecken([switch]$Erzwingen) {
  $getan = @()
  $proz = @(ServerProzesse 0)
  if ($proz.Count -and ($script:ServerAntwortet -eq $false -or $Erzwingen)) {
    foreach ($p in $proz) {
      try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; $getan += "Hänger beendet (PID $($p.ProcessId))" }
      catch { $getan += "PID $($p.ProcessId) liess sich nicht beenden: $($_.Exception.Message)" }
    }
    Start-Sleep -Milliseconds 400
    $script:ProzCache = $null
  } elseif ($proz.Count) {
    return @{ ok = $true; getan = @('Server läuft und antwortet — nichts zu tun'); gestartet = $false }
  }
  $aufgabe = $null
  try { $aufgabe = Get-ScheduledTask -TaskName 'John Server' -ErrorAction SilentlyContinue } catch { }
  if ($aufgabe) {
    try {
      Start-ScheduledTask -TaskName 'John Server' -ErrorAction Stop
      $getan += 'Aufgabe „John Server" angestoßen'
      return @{ ok = $true; getan = $getan; gestartet = $true }
    } catch { $getan += "Aufgabe liess sich nicht starten: $($_.Exception.Message)" }
  }
  $cmd = Join-Path $Compass 'john-server.cmd'
  if (Test-Path $cmd) {
    try {
      Start-Process -FilePath $cmd -WorkingDirectory $Compass -WindowStyle Minimized | Out-Null
      $getan += 'john-server.cmd gestartet'
      return @{ ok = $true; getan = $getan; gestartet = $true }
    } catch { $getan += "john-server.cmd: $($_.Exception.Message)" }
  }
  return @{ ok = $false; getan = $getan; gestartet = $false }
}

# ── Rezeption: Puls und Aufträge ─────────────────────────────────────────────────────────
$script:HubTask = $null; $script:HubWas = ''
$script:HubOffen = 0; $script:HubZeit = [datetime]::MinValue; $script:HubFehler = ''; $script:HubCompassTs = ''
function HubSenden([string]$was, $koerper) {
  if ($OhneHub) { return $null }
  try {
    $req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Post, "$Hub/api.php?w=$was")
    $req.Headers.TryAddWithoutValidation('X-John-Token', $HubToken) | Out-Null
    $json = ($koerper | ConvertTo-Json -Depth 12 -Compress)
    $req.Content = New-Object System.Net.Http.StringContent ($json, [Text.Encoding]::UTF8, 'application/json')
    return $script:Http.SendAsync($req)
  } catch { $script:HubFehler = $_.Exception.Message; return $null }
}
function PulsSenden {
  if ($script:HubTask) { return }
  $proz = @(ServerProzesse)
  # Vier Zustände, vier Sätze — auch hier gilt: „noch nicht geprüft" ist nicht dasselbe
  # wie „antwortet nicht".
  $notiz = if (-not $proz.Count) { 'Cockpit-Server aus' }
           elseif ($null -eq $script:ServerAntwortet) { 'Cockpit-Server läuft, noch nicht geprüft' }
           elseif ($script:ServerOk) { 'Cockpit-Server läuft und antwortet' }
           elseif ($script:ServerAntwortet) { 'Cockpit-Server läuft, antwortet aber mit ' + $script:ServerCode }
           else { 'Cockpit-Server läuft, antwortet gerade nicht' }
  $script:HubWas = 'puls'
  $script:HubTask = HubSenden 'puls' @{
    geraet = $Geraet; version = $VERSION; kann = @('takt','stapel','wecken')
    notiz = $notiz; takt = $(if ($script:LetzterTakt -gt [datetime]::MinValue) { $script:LetzterTakt.ToString('o') } else { $null })
  }
}
function HubAbholen {
  if (-not $script:HubTask -or -not $script:HubTask.IsCompleted) { return }
  $t = $script:HubTask; $script:HubTask = $null
  try {
    if ($t.Status -ne 'RanToCompletion') { $script:HubFehler = 'Rezeption nicht erreichbar'; return }
    $res = $t.Result
    $txt = $res.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if (-not $res.IsSuccessStatusCode) { $script:HubFehler = "Rezeption HTTP $([int]$res.StatusCode)"; return }
    $script:HubFehler = ''; $script:HubZeit = Get-Date
    $d = $txt | ConvertFrom-Json
    if ($script:HubWas -eq 'puls' -and $d.ok) { $script:HubOffen = [int]$d.auftraege; $script:HubCompassTs = [string]$d.compassTs }
  } catch { $script:HubFehler = $_.Exception.Message }
}

# ── Kindprozesse: hier passiert das Denken ───────────────────────────────────────────────
$script:Kinder = @()
function KindStarten([string]$art, [string]$text) {
  if (-not (Test-Path $AuftragPs1)) { Log "john-auftrag.ps1 fehlt — kein Denken möglich ($AuftragPs1)" 'Red'; return $null }
  # Höchstens einer denkt — John hat einen Kopf. Der Spiegel denkt nicht (kein Claude, Sekunden)
  # und bekommt einen eigenen Platz, sonst wartete ein OK vom Handy auf einen 90-s-Gedanken.
  $spiegelnd = @($script:Kinder | Where-Object { $_.art -eq 'spiegel' }).Count
  $denkend   = @($script:Kinder | Where-Object { $_.art -ne 'spiegel' }).Count
  if ($art -eq 'spiegel') { if ($spiegelnd) { return $null } } elseif ($denkend) { return $null }
  $argv = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-WindowStyle','Hidden',
            '-File', $AuftragPs1, '-Art', $art, '-Geraet', $Geraet)
  if ($text) { $argv += @('-Text', $text) }
  try {
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argv -WindowStyle Hidden -PassThru
    $script:Kinder += @{ p = $p; art = $art; start = Get-Date }
    if ($art -ne 'spiegel') { Log "Auftrag $art gestartet (PID $($p.Id))" 'Cyan' }
    return $p
  } catch { Log "Auftrag $art liess sich nicht starten: $($_.Exception.Message)" 'Red'; return $null }
}
function KinderPflegen {
  if (-not @($script:Kinder).Count) { return }
  $bleibt = @()
  foreach ($k in $script:Kinder) {
    $lebt = $false
    try { $lebt = -not $k.p.HasExited } catch { $lebt = $false }
    if (-not $lebt) {
      $dauer = [int]((Get-Date) - $k.start).TotalSeconds
      if ($k.art -ne 'spiegel') { Log "Auftrag $($k.art) fertig nach $dauer s (Code $(try { $k.p.ExitCode } catch { '?' }))" }
      continue
    }
    if (((Get-Date) - $k.start).TotalMinutes -gt 12) {
      Log "Auftrag $($k.art) hängt seit 12 Min — beende PID $($k.p.Id)" 'Yellow'
      try { $k.p.Kill() } catch { }
      continue
    }
    $bleibt += $k
  }
  $script:Kinder = $bleibt
}
function DenktGerade { return (@($script:Kinder | Where-Object { $_.art -ne 'spiegel' }).Count -gt 0) }

# ── Takt: Johns eigener Rhythmus ─────────────────────────────────────────────────────────
# Arbeitsfenster mit Absicht: Mo–Fr 6:30–21:30. Das Wochenende gehört Familie, Sport und
# Erholung — ein Coach, der sonntags um 9 einen Stapel umsortiert, ist ein Wecker, kein Coach.
# Nachts denkt er auch nicht: es gibt niemanden, der die Antwort liest, und jeder Takt kostet
# Kontingent im Abo, das Bene tagsüber selbst braucht.
$script:LetzterTakt = [datetime]::MinValue
# Nach einem Neustart nicht sofort denken: der letzte Takt steht in letzter-takt.json. Ohne das
# lief nach jedem Wecken ein Claude-Aufruf, auch wenn der letzte zwei Minuten her war.
try {
  $lt = Join-Path $Hier 'letzter-takt.json'
  if (Test-Path $lt) { $z = ([IO.File]::ReadAllText($lt, [Text.Encoding]::UTF8) | ConvertFrom-Json).zeit; if ($z) { $script:LetzterTakt = [datetime]::Parse([string]$z) } }
} catch { }
function TaktFenster([datetime]$t) {
  if ($t.DayOfWeek -eq 'Saturday' -or $t.DayOfWeek -eq 'Sunday') { return $false }
  $min = $t.Hour * 60 + $t.Minute
  return ($min -ge 390 -and $min -le 1290)
}
function TaktFaellig {
  if ($OhneTakt) { return $false }
  if (DenktGerade) { return $false }
  $jetzt = Get-Date
  if (-not (TaktFenster $jetzt)) { return $false }
  if ($script:LetzterTakt -gt [datetime]::MinValue -and ($jetzt - $script:LetzterTakt).TotalMinutes -lt $TaktMinuten) { return $false }
  return $true
}

# ── Stand: das, was die Lobby liest ──────────────────────────────────────────────────────
function StandObjekt {
  $proz = @(ServerProzesse)
  $kind = @($script:Kinder | Where-Object { $_.art -ne 'spiegel' })[0]
  return @{
    ok = $true
    geraet = $Geraet; version = $VERSION
    jetzt = (Get-Date).ToString('o')
    serverLaeuft = [bool]$proz.Count
    serverPid = @($proz | ForEach-Object { $_.ProcessId })
    serverAntwortet = $script:ServerAntwortet
    serverOk = $script:ServerOk
    serverCode = $script:ServerCode
    serverAntwortZeit = $(if ($script:ServerAntwortZeit -gt [datetime]::MinValue) { $script:ServerAntwortZeit.ToString('o') } else { $null })
    denkt = (DenktGerade)
    denktSeit = $(if ($kind) { $kind.start.ToString('o') } else { $null })
    denktAn = $(if ($kind) { $kind.art } else { $null })
    takt = @{ letzter = $(if ($script:LetzterTakt -gt [datetime]::MinValue) { $script:LetzterTakt.ToString('o') } else { $null })
              minuten = $TaktMinuten; imFenster = (TaktFenster (Get-Date)); aus = [bool]$OhneTakt }
    hub = @{ adresse = $(if ($OhneHub) { $null } else { $Hub }); offen = $script:HubOffen
             stand = $(if ($script:HubZeit -gt [datetime]::MinValue) { $script:HubZeit.ToString('o') } else { $null })
             fehler = $script:HubFehler }
  }
}
function StandSchreiben {
  try { [IO.File]::WriteAllText($StandDatei, ((StandObjekt) | ConvertTo-Json -Depth 8), $Utf8NoBom) } catch { }
}

# ── -Status / -Einmal ────────────────────────────────────────────────────────────────────
if ($Status) {
  ProbeStarten
  $bis = (Get-Date).AddSeconds(9)
  while ((Get-Date) -lt $bis -and $script:ProbeTask) { Start-Sleep -Milliseconds 200; ProbeAbholen }
  $s = StandObjekt
  "Gerät        : $($s.geraet) (Worker $VERSION)"
  "Cockpit :8787: " + $(if ($s.serverLaeuft) { "läuft (PID $($s.serverPid -join ', '))" } else { 'läuft nicht' }) +
    $(if ($s.serverAntwortet -eq $true) { ', antwortet' } elseif ($s.serverAntwortet -eq $false) { ', ANTWORTET NICHT' } else { '' })
  "Tür   :$Port : " + $(try { $c = New-Object Net.Sockets.TcpClient; $a = $c.BeginConnect('127.0.0.1',$Port,$null,$null)
      $r = $a.AsyncWaitHandle.WaitOne(800); $c.Close(); $(if ($r) { 'antwortet (ein Worker läuft schon)' } else { 'kein Worker' }) } catch { 'kein Worker' })
  "Takt         : alle $TaktMinuten Min, Fenster jetzt " + $(if ($s.takt.imFenster) { 'offen' } else { 'zu (Mo-Fr 6:30-21:30)' })
  "Rezeption    : " + $(if ($OhneHub) { 'nicht angebunden (JOHN_HUB_TOKEN fehlt)' } else { $Hub })
  return
}
if ($Einmal) {
  Log "Einzelner Takt von Hand ($Geraet)" 'Cyan'
  & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $AuftragPs1 -Art 'takt' -Geraet $Geraet
  return
}

# ── Tür öffnen ───────────────────────────────────────────────────────────────────────────
# Beide Schreibweisen anmelden: der Browser fragt 127.0.0.1 (localhost wäre ein anderer
# Ursprung und http.sys prüft den Host-Kopf). Das 127er-Präfix kann ohne Rechte scheitern —
# dann bleibt localhost, und die Lobby sagt es.
$listener = New-Object System.Net.HttpListener
$angemeldet = @()
foreach ($pfx in @("http://127.0.0.1:$Port/", "http://localhost:$Port/")) {
  try { $listener.Prefixes.Add($pfx); $angemeldet += $pfx } catch { }
}
try { $listener.Start() }
catch {
  # Zweiter Worker? Dann ist alles gut — einer reicht, und der andere lebt.
  Log "Tür $Port liess sich nicht öffnen: $($_.Exception.Message)" 'Red'
  Log 'Läuft hier schon ein Worker? john-worker.ps1 -Status sagt es. Ende.' 'Yellow'
  return
}
Log "Johns Hände sind wach — Gerät $Geraet, Worker $VERSION" 'Green'
Log ("  Tür:       " + ($angemeldet -join ' '))
Log ("  Cockpit:   http://127.0.0.1:$ServerPort/  (wird bewacht, nicht bedient)")
Log ("  Takt:      " + $(if ($OhneTakt) { 'aus' } else { "alle $TaktMinuten Min, Mo-Fr 6:30-21:30" }))
Log ("  Rezeption: " + $(if ($OhneHub) { 'nicht angebunden (JOHN_HUB_TOKEN fehlt) — Johns Stand bleibt auf diesem Rechner' } else { $Hub }))

function SendJson($ctx, $obj, [int]$code = 200) {
  $b = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Depth 10))
  $ctx.Response.StatusCode = $code
  $ctx.Response.ContentType = 'application/json; charset=utf-8'
  $ctx.Response.ContentLength64 = $b.Length
  $ctx.Response.OutputStream.Write($b, 0, $b.Length)
  $ctx.Response.Close()
}

$script:Ende = $false
$aufgabe = $listener.GetContextAsync()
$letztePflege = [datetime]::MinValue
$letzterPuls  = [datetime]::MinValue
$letzteProbe  = [datetime]::MinValue
$script:SpiegelMt = -1; $script:SpiegelTs = '-'; $script:SpiegelZeit = [datetime]::MinValue

try {
  while ($listener.IsListening -and -not $script:Ende) {

    # ---- 1. Anfragen bedienen (nie länger als ein Wimpernschlag) ----
    if ($aufgabe.Wait(400)) {
      $ctx = $null
      try { $ctx = $aufgabe.Result } catch { }
      $aufgabe = $listener.GetContextAsync()
      if ($ctx) {
        try {
          $res = $ctx.Response
          $res.Headers['Access-Control-Allow-Origin'] = '*'
          $res.Headers['Access-Control-Allow-Headers'] = 'Content-Type'
          $res.Headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
          # Chrome verlangt das für Anfragen aus dem Netz an eine lokale Adresse.
          $res.Headers['Access-Control-Allow-Private-Network'] = 'true'
          $res.Headers['Cache-Control'] = 'no-store'
          $pfad = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimEnd('/')
          if ($pfad -eq '') { $pfad = '/' }
          if ($ctx.Request.HttpMethod -eq 'OPTIONS') { $res.StatusCode = 204; $res.Close() }
          elseif ($pfad -eq '/stand') { ProbeStarten; SendJson $ctx (StandObjekt) }
          elseif ($pfad -eq '/wecken') {
            $r = Wecken
            Log ('Wecken über die Tür: ' + ($r.getan -join ' · ')) 'Cyan'
            SendJson $ctx @{ ok = $r.ok; gestartet = $r.gestartet; getan = $r.getan } $(if ($r.ok) { 200 } else { 503 })
          }
          elseif ($pfad -eq '/takt') {
            if (DenktGerade) { SendJson $ctx @{ ok = $false; fehler = 'John denkt schon' } 409 }
            else { $p = KindStarten 'takt' $null; $script:LetzterTakt = Get-Date; SendJson $ctx @{ ok = [bool]$p } }
          }
          elseif ($pfad -eq '/__stop') { Log 'Tür schließt (per /__stop)' 'Yellow'; SendJson $ctx @{ ok = $true; msg = 'bye' }; $script:Ende = $true }
          elseif ($pfad -eq '/') {
            $s = StandObjekt
            $html = '<!doctype html><meta charset="utf-8"><title>Johns Hände</title>' +
              '<style>body{font:14px/1.6 system-ui;margin:2rem;max-width:44rem;color:#1b1f18}code{background:#eee;padding:1px 5px;border-radius:4px}</style>' +
              '<h1>Johns Hände sind wach</h1><p>Gerät <b>' + $s.geraet + '</b>, Worker ' + $VERSION + '.</p>' +
              '<p>Cockpit-Server: ' + $(if ($s.serverLaeuft) { 'läuft' } else { 'aus' }) + ' · denkt gerade: ' + $(if ($s.denkt) { 'ja (' + $s.denktAn + ')' } else { 'nein' }) + '</p>' +
              '<p>Diese Tür ist für die Lobby im Compass da: <code>/stand</code>, <code>/wecken</code>, <code>/takt</code>.</p>'
            $b = [Text.Encoding]::UTF8.GetBytes($html)
            $res.StatusCode = 200; $res.ContentType = 'text/html; charset=utf-8'
            $res.ContentLength64 = $b.Length; $res.OutputStream.Write($b, 0, $b.Length); $res.Close()
          }
          else { SendJson $ctx @{ ok = $false; fehler = "unbekannt: $pfad" } 404 }
        } catch {
          try { SendJson $ctx @{ ok = $false; fehler = $_.Exception.Message } 500 } catch { }
        }
      }
      continue   # sofort zurück an die Tür — Buchhaltung kann warten
    }

    # ---- 2. Buchhaltung (nur Millisekunden, nie Netz) ----
    $jetzt = Get-Date
    ProbeAbholen
    HubAbholen
    if (($jetzt - $letztePflege).TotalSeconds -ge 3) { KinderPflegen; $letztePflege = $jetzt }
    if (($jetzt - $letzteProbe).TotalSeconds -ge 20) { ProbeStarten; $letzteProbe = $jetzt; StandSchreiben }
    if (($jetzt - $letzterPuls).TotalSeconds -ge 60) { PulsSenden; $letzterPuls = $jetzt }

    # ---- 2b. Spiegel: Johns Kachel auf allen Geraeten ----
    # Ausloeser: der Server hat seinen Stapel geschrieben (Datei neuer), ein anderes Geraet hat
    # etwas abgeraeumt (compassTs aus dem Puls neuer), oder zehn Minuten Ruhe als Sicherheitsnetz.
    if (-not $OhneHub) {
      $sd = Join-Path $Compass 'john-stapel.json'
      $mt = if (Test-Path $sd) { (Get-Item $sd).LastWriteTimeUtc.Ticks } else { 0 }
      if ($mt -ne $script:SpiegelMt -or $script:HubCompassTs -ne $script:SpiegelTs -or ($jetzt - $script:SpiegelZeit).TotalMinutes -ge 10) {
        if (KindStarten 'spiegel' $null) { $script:SpiegelMt = $mt; $script:SpiegelTs = $script:HubCompassTs; $script:SpiegelZeit = $jetzt }
      }
    }

    # ---- 3. Johns eigener Rhythmus ----
    if (TaktFaellig) {
      $script:LetzterTakt = $jetzt
      Log 'Takt fällig — John sieht nach, was jetzt zählt' 'Cyan'
      KindStarten 'takt' $null | Out-Null
    }

    # ---- 4. Aufträge von der Rezeption ----
    if ($script:HubOffen -gt 0 -and -not (DenktGerade)) {
      Log "Rezeption meldet $($script:HubOffen) offene(n) Auftrag — hole ihn" 'Cyan'
      $script:HubOffen = 0
      KindStarten 'hub' $null | Out-Null
    }
  }
} finally {
  try { $listener.Stop(); $listener.Close() } catch { }
  Log 'Johns Hände schlafen (Worker beendet).' 'Yellow'
}

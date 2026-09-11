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
$VERSION = '1.2.0'   # 1.1: Spiegel fuer Johns Kachel auf allen Geraeten · 1.2: Gespraechsraum an der Tuer

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
    geraet = $Geraet; version = $VERSION; kann = @('takt','stapel','wecken','raum')
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
    if ($script:HubWas -eq 'puls' -and $d.ok) {
      $script:HubOffen = [int]$d.auftraege; $script:HubCompassTs = [string]$d.compassTs
      # Stopp vom Handy: die Rezeption nennt die Auftrags-IDs, der Raum steht in der .lauf-Datei.
      $ids = @($d.stopp | Where-Object { $_ })
      if ($ids.Count -and (Test-Path $script:LaufOrdner)) {
        foreach ($lf in @(Get-ChildItem $script:LaufOrdner -Filter '*.lauf' -File)) {
          $raum = [IO.Path]::GetFileNameWithoutExtension($lf.Name)
          $l = RaumLauf $raum
          if ($l -and $l.jobId -and ($ids -contains [string]$l.jobId)) { RaumStoppen $raum 'handy' -OhneMelden | Out-Null }
        }
      }
    }
  } catch { $script:HubFehler = $_.Exception.Message }
}

# ── Kindprozesse: hier passiert das Denken ───────────────────────────────────────────────
$script:Kinder = @()
function KindStarten([string]$art, [string]$text, [string]$raum = '', [string]$an = '') {
  if (-not (Test-Path $AuftragPs1)) { Log "john-auftrag.ps1 fehlt — kein Denken möglich ($AuftragPs1)" 'Red'; return $null }
  # Höchstens einer denkt — John hat einen Kopf. Der Spiegel denkt nicht (kein Claude, Sekunden)
  # und bekommt einen eigenen Platz, sonst wartete ein OK vom Handy auf einen 90-s-Gedanken.
  $spiegelnd = @($script:Kinder | Where-Object { $_.art -eq 'spiegel' }).Count
  $denkend   = @($script:Kinder | Where-Object { $_.art -ne 'spiegel' }).Count
  if ($art -eq 'spiegel') { if ($spiegelnd) { return $null } } elseif ($denkend) { return $null }
  $argv = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-WindowStyle','Hidden',
            '-File', $AuftragPs1, '-Art', $art, '-Geraet', $Geraet)
  if ($text) { $argv += @('-Text', $text) }
  if ($raum) { $argv += @('-Raum', $raum, '-An', $an) }
  try {
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argv -WindowStyle Hidden -PassThru
    $script:Kinder += @{ p = $p; art = $art; start = Get-Date; raum = $raum; an = $an }
    if ($art -ne 'spiegel') { Log ("Auftrag $art gestartet (PID $($p.Id))" + $(if ($raum) { " — Raum $raum, an $an" } else { '' })) 'Cyan' }
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
      # Ein abgestürzter Raum-Lauf räumt seine .lauf-Datei nicht selbst weg.
      if ($k.raum) { Remove-Item (Join-Path $script:LaufOrdner "$($k.raum).lauf") -Force -ErrorAction SilentlyContinue }
      continue
    }
    # „beide" im Raum sind zwei Modellaufrufe hintereinander (je bis 7 Min) — deshalb mehr Luft.
    $grenze = if ($k.art -eq 'raum') { 16 } else { 12 }
    if (((Get-Date) - $k.start).TotalMinutes -gt $grenze) {
      Log "Auftrag $($k.art) hängt seit $grenze Min — beende PID $($k.p.Id) samt Kindern" 'Yellow'
      BaumBeenden $k.p
      if ($k.raum) {
        Remove-Item (Join-Path $script:LaufOrdner "$($k.raum).lauf") -Force -ErrorAction SilentlyContinue
        try { RaumZeileDazu $k.raum 'system' "Abgebrochen: nach $grenze Minuten keine Antwort." | Out-Null } catch { }
      }
      continue
    }
    $bleibt += $k
  }
  $script:Kinder = $bleibt
}
function DenktGerade { return (@($script:Kinder | Where-Object { $_.art -ne 'spiegel' }).Count -gt 0) }

# Kindprozesse samt ihren Kindern beenden: claude.exe bzw. codex.exe hängen unter powershell.exe
# und überlebten ein bloßes Kill(). Der Zug liefe weiter und schriebe nach dem Stopp noch in den
# Raum. cmd /c schluckt die Ausgabe von taskkill; ein 2>&1 in PowerShell 5.1 würde bei
# ErrorActionPreference Stop schon an der ersten stderr-Zeile werfen.
function BaumBeenden($p) {
  try { $null = & cmd.exe /c "taskkill /PID $($p.Id) /T /F >nul 2>&1" } catch { }
  try { if (-not $p.HasExited) { $p.Kill() } } catch { }
}

# ── Gesprächsraum an der Tür (11.09.2026) ────────────────────────────────────────────────
# Ein Raum ist eine Datei in Johns lokalem Ordner: C:\dev\john\coaching\raum\<id>.jsonl. Die Tür
# liest und schreibt nur Zeilen. Das dauert Millisekunden, und sie ruft nie ein Modell. Gedacht
# wird im Kindprozess (john-auftrag.ps1 -Art raum); der gibt auch das Signal an die Rezeption.
# Vertrag: docs/protokoll.md › Gesprächsraum.
$script:RaumOrdner = Join-Path $JohnDir 'coaching\raum'
$script:LaufOrdner = Join-Path $Hier '.auftraege'
$script:RaumWarte  = New-Object System.Collections.ArrayList   # @{raum; an; seit}

function RaumPfad([string]$id) { return (Join-Path $script:RaumOrdner "$id.jsonl") }
function RaumGueltig([string]$id) { return ($id -match '^[a-z0-9-]{1,40}$') }
# Derselbe Mutex-Name wie in john-auftrag.ps1 › RaumAnhaengen.
function RaumSperre([string]$id, [scriptblock]$tun) {
  $m = New-Object Threading.Mutex($false, "Local\john-raum-$id")
  $hat = $false
  try {
    try { $hat = $m.WaitOne(2000) } catch [Threading.AbandonedMutexException] { $hat = $true }
    return (& $tun)
  } finally { if ($hat) { $m.ReleaseMutex() }; $m.Dispose() }
}
function RaumZeilen([string]$id) {
  $thema = ''; $erstellt = ''; $zuege = New-Object System.Collections.Generic.List[object]
  $f = RaumPfad $id
  if (Test-Path $f) {
    foreach ($z in [IO.File]::ReadAllLines($f, [Text.Encoding]::UTF8)) {
      if (-not $z.Trim()) { continue }
      try { $o = $z | ConvertFrom-Json } catch { continue }
      if ($o.meta) { $thema = [string]$o.thema; $erstellt = [string]$o.erstellt; continue }
      $zuege.Add($o)
    }
  }
  return @{ thema = $thema; erstellt = $erstellt; zuege = $zuege.ToArray() }
}
function RaumZeileDazu([string]$id, [string]$wer, [string]$text) {
  return (RaumSperre $id {
    $r = RaumZeilen $id
    $max = 0; foreach ($z in $r.zuege) { if ([int]$z.zug -gt $max) { $max = [int]$z.zug } }
    $n = $max + 1
    $zeile = (@{ zug = $n; wer = $wer; zeit = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz'); text = $text; weitergeben = $true } | ConvertTo-Json -Compress -Depth 3)
    [IO.File]::AppendAllText((RaumPfad $id), $zeile + "`n", $Utf8NoBom)
    $n
  })
}
function RaumNeu([string]$thema) {
  if (-not (Test-Path $script:RaumOrdner)) { New-Item -ItemType Directory -Force $script:RaumOrdner | Out-Null }
  $s = $thema.ToLower().Replace('ä','ae').Replace('ö','oe').Replace('ü','ue').Replace('ß','ss')
  $s = ($s -replace '[^a-z0-9]+', '-').Trim('-')
  if ($s.Length -gt 22) { $s = $s.Substring(0, 22).Trim('-') }
  if (-not $s) { $s = 'raum' }
  $id = "$s-" + (Get-Date).ToString('MMdd-HHmm')
  $i = 2; $basis = $id
  while (Test-Path (RaumPfad $id)) { $id = "$basis-$i"; $i++ }
  $meta = (@{ meta = $true; thema = $thema; erstellt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz') } | ConvertTo-Json -Compress)
  [IO.File]::WriteAllText((RaumPfad $id), $meta + "`n", $Utf8NoBom)
  return $id
}
function RaumKind([string]$id) { return @($script:Kinder | Where-Object { $_.art -eq 'raum' -and $_.raum -eq $id })[0] }
function RaumLauf([string]$id) {
  $f = Join-Path $script:LaufOrdner "$id.lauf"
  if (-not (Test-Path $f)) { return $null }
  try { return ([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) | ConvertFrom-Json) } catch { return $null }
}
# Wer gerade spricht: der Kindprozess ist die Wahrheit, die .lauf-Datei sagt nur, WER von beiden.
# Eine .lauf-Datei ohne lebendes Kind stammt aus einem abgestürzten Lauf und zählt nicht.
function RaumLaeuft([string]$id) {
  $k = RaumKind $id
  if (-not $k) { return $null }
  $l = RaumLauf $id
  return @{ an = $(if ($l -and $l.an) { [string]$l.an } else { $k.an }); seit = $(if ($l -and $l.seit) { [string]$l.seit } else { $k.start.ToString('o') }) }
}
function RaumWartet([string]$id) { return @($script:RaumWarte | Where-Object { $_.raum -eq $id } | ForEach-Object { $_.an }) }
function RaumListe {
  if (-not (Test-Path $script:RaumOrdner)) { return @() }
  $liste = @()
  foreach ($f in @(Get-ChildItem $script:RaumOrdner -Filter '*.jsonl' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 50)) {
    $id = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $r = RaumZeilen $id
    $liste += @{ id = $id; thema = $r.thema; zuege = $r.zuege.Count
                 zuletzt = $(if ($r.zuege.Count) { [string]$r.zuege[-1].zeit } else { $r.erstellt })
                 laeuft = [bool](RaumKind $id); wartet = @(RaumWartet $id) }
  }
  return $liste
}
# Einreihen: schreibt Bene zweimal, bevor jemand geantwortet hat, entsteht kein zweiter Lauf.
# Der wartende Eintrag wird erweitert (john + madeleine = beide).
function RaumEinreihen([string]$id, [string]$an) {
  $da = @($script:RaumWarte | Where-Object { $_.raum -eq $id })[0]
  if ($da) { if ($da.an -ne $an) { $da.an = 'beide' }; return }
  [void]$script:RaumWarte.Add(@{ raum = $id; an = $an; seit = Get-Date })
}
# Stoppen: Warteschlange des Raums leeren, laufenden Zug samt Modellprozess beenden, eine
# Hinweiszeile in den Raum, der Rezeption Bescheid geben. Kommt der Stopp VON der Rezeption
# (Handy, über den Puls), wird sie nicht noch einmal benachrichtigt.
function RaumStoppen([string]$id, [string]$wer, [switch]$OhneMelden) {
  $weg = @($script:RaumWarte | Where-Object { $_.raum -eq $id })
  foreach ($w in $weg) { $script:RaumWarte.Remove($w) }
  $lauf = RaumLauf $id
  $kind = RaumKind $id
  if ($kind) { BaumBeenden $kind.p }
  if (-not $OhneMelden -and $lauf -and $lauf.jobId) { HubSenden 'stopp' @{ id = [string]$lauf.jobId; wer = $wer } | Out-Null }
  Remove-Item (Join-Path $script:LaufOrdner "$id.lauf") -Force -ErrorAction SilentlyContinue
  $gestoppt = [bool]$kind -or $weg.Count -gt 0
  if ($gestoppt) {
    $wen = if ($kind -and $lauf -and $lauf.an) { @{ john = 'John'; madeleine = 'Madeleine' }[[string]$lauf.an] } else { $null }
    $satz = 'Gestoppt' + $(if ($wer -eq 'handy') { ' von einem anderen Gerät' } else { '' }) + $(if ($wen) { " — $wen hatte noch nicht geantwortet" } else { '' }) + '.'
    RaumZeileDazu $id 'system' $satz | Out-Null
    Log "Raum $id gestoppt ($wer)" 'Yellow'
  }
  return $gestoppt
}
function LiesKoerper($ctx) {
  try {
    $sr = New-Object IO.StreamReader($ctx.Request.InputStream, [Text.Encoding]::UTF8)
    $roh = $sr.ReadToEnd(); $sr.Close()
    if (-not $roh.Trim()) { return $null }
    return ($roh | ConvertFrom-Json)
  } catch { return $null }
}

# Seit dem Gesprächsraum beantwortet die Tür Privates. Deshalb gibt es kein
# Access-Control-Allow-Origin: * mehr: jede fremde Seite in Benes Browser könnte sonst seine
# Gespräche lesen oder einen Zug auslösen. Erlaubt sind die eigene Compass-Instanz und lokale
# Seiten. Anfragen ohne Origin (PowerShell, curl, Aufgaben) kommen nicht aus einer fremden
# Webseite und bleiben erlaubt. Handlungen gehen nur per POST — ein <img src=…/wecken> einer
# fremden Seite schickt keinen Origin und darf deshalb nichts auslösen.
$script:TuerErlaubt = @('https://bene.vishnuartists.com')
$extra = LiesEnv 'JOHN_TUER_ORIGINS' ''
if ($extra) { $script:TuerErlaubt += @($extra -split '[,\s]+' | Where-Object { $_ }) }
function UrsprungOk([string]$o) {
  if (-not $o) { return $true }
  if ($script:TuerErlaubt -contains $o) { return $true }
  return ($o -match '^https?://(localhost|127\.0\.0\.1)(:\d+)?$')
}

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
    denktRaum = $(if ($kind -and $kind.raum) { $kind.raum } else { $null })
    raumWarte = $script:RaumWarte.Count
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
          $herkunft = [string]$ctx.Request.Headers['Origin']
          $methode = $ctx.Request.HttpMethod
          $res.Headers['Cache-Control'] = 'no-store'
          $res.Headers['Vary'] = 'Origin'
          if ($herkunft -and (UrsprungOk $herkunft)) {
            $res.Headers['Access-Control-Allow-Origin'] = $herkunft
            $res.Headers['Access-Control-Allow-Headers'] = 'Content-Type'
            $res.Headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
            # Chrome verlangt das für Anfragen aus dem Netz an eine lokale Adresse.
            $res.Headers['Access-Control-Allow-Private-Network'] = 'true'
          }
          $pfad = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimEnd('/')
          if ($pfad -eq '') { $pfad = '/' }
          $handlung = $pfad -in @('/wecken', '/takt', '/stopp', '/raum/weitergeben', '/__stop') -or ($pfad -eq '/raum' -and $methode -ne 'GET')
          if (-not (UrsprungOk $herkunft)) {
            Log "Tür: fremde Herkunft abgewiesen ($herkunft → $pfad)" 'Yellow'
            SendJson $ctx @{ ok = $false; fehler = 'Diese Tür antwortet nur Benes eigenen Seiten.' } 403
          }
          elseif ($methode -eq 'OPTIONS') { $res.StatusCode = 204; $res.Close() }
          elseif ($handlung -and $methode -ne 'POST') { SendJson $ctx @{ ok = $false; fehler = "$pfad nur per POST" } 405 }
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
          # ---- Gesprächsraum ----
          elseif ($pfad -eq '/raeume') { SendJson $ctx @{ ok = $true; raeume = @(RaumListe) } }
          elseif ($pfad -eq '/raum' -and $methode -eq 'GET') {
            $id = [string]$ctx.Request.QueryString['id']
            $seit = 0; [void][int]::TryParse([string]$ctx.Request.QueryString['seit'], [ref]$seit)
            if (-not (RaumGueltig $id)) { SendJson $ctx @{ ok = $false; fehler = 'id fehlt oder ist ungültig' } 400 }
            elseif (-not (Test-Path (RaumPfad $id))) { SendJson $ctx @{ ok = $false; fehler = "Raum $id gibt es nicht" } 404 }
            else {
              $r = RaumZeilen $id
              SendJson $ctx @{ ok = $true; id = $id; thema = $r.thema; zuege = @($r.zuege | Where-Object { [int]$_.zug -gt $seit })
                               laeuft = (RaumLaeuft $id); wartet = @(RaumWartet $id) }
            }
          }
          elseif ($pfad -eq '/raum') {
            $k = LiesKoerper $ctx
            $text = if ($k) { ([string]$k.text).Trim() } else { '' }
            $an = if ($k) { [string]$k.an } else { '' }
            $id = if ($k -and $k.id) { [string]$k.id } else { '' }
            if (-not $text) { SendJson $ctx @{ ok = $false; fehler = 'text fehlt' } 400 }
            elseif ($text.Length -gt 8000) { SendJson $ctx @{ ok = $false; fehler = 'text zu lang (höchstens 8000 Zeichen)' } 413 }
            elseif ($an -notin @('john', 'madeleine', 'beide')) { SendJson $ctx @{ ok = $false; fehler = 'an muss john, madeleine oder beide sein' } 400 }
            elseif ($id -and -not (RaumGueltig $id)) { SendJson $ctx @{ ok = $false; fehler = 'id ist ungültig' } 400 }
            elseif ($id -and -not (Test-Path (RaumPfad $id))) { SendJson $ctx @{ ok = $false; fehler = "Raum $id gibt es nicht" } 404 }
            else {
              if (-not $id) {
                $thema = if ($k.thema) { ([string]$k.thema).Trim() } else { '' }
                if (-not $thema) { $thema = ($text -split "`r?`n")[0]; if ($thema.Length -gt 60) { $thema = $thema.Substring(0, 60).TrimEnd() + '…' } }
                $id = RaumNeu $thema
              }
              $n = RaumZeileDazu $id 'bene' $text
              RaumEinreihen $id $an
              # wartet: jemand anderes denkt gerade, oder ein anderer Raum steht vorn in der Schlange.
              $vorn = @($script:RaumWarte)[0]
              $wartet = (DenktGerade) -or ($vorn -and $vorn.raum -ne $id)
              Log ("Raum $id : Bene hat Zug $n geschrieben ($($text.Length) Zeichen), an $an" + $(if ($wartet) { ' — wartet' } else { '' }))
              SendJson $ctx @{ ok = $true; id = $id; zug = $n; wartet = [bool]$wartet }
            }
          }
          elseif ($pfad -eq '/raum/weitergeben') {
            $k = LiesKoerper $ctx
            $id = if ($k) { [string]$k.id } else { '' }
            $zug = 0; if ($k) { [void][int]::TryParse([string]$k.zug, [ref]$zug) }
            if (-not (RaumGueltig $id) -or $zug -lt 1) { SendJson $ctx @{ ok = $false; fehler = 'id und zug nötig' } 400 }
            elseif (-not (Test-Path (RaumPfad $id))) { SendJson $ctx @{ ok = $false; fehler = "Raum $id gibt es nicht" } 404 }
            else {
              $wert = -not ($k.PSObject.Properties['weitergeben'] -and $k.weitergeben -eq $false)
              $gefunden = RaumSperre $id {
                $f = RaumPfad $id; $treffer = $false
                $zeilen = @([IO.File]::ReadAllLines($f, [Text.Encoding]::UTF8) | Where-Object { $_.Trim() })
                for ($i = 0; $i -lt $zeilen.Count; $i++) {
                  try { $o = $zeilen[$i] | ConvertFrom-Json } catch { continue }
                  if (-not $o.meta -and [int]$o.zug -eq $zug) {
                    $o | Add-Member -NotePropertyName weitergeben -NotePropertyValue $wert -Force
                    $zeilen[$i] = ($o | ConvertTo-Json -Compress -Depth 3); $treffer = $true
                  }
                }
                if ($treffer) { [IO.File]::WriteAllText($f, (($zeilen -join "`n") + "`n"), $Utf8NoBom) }
                $treffer
              }
              if ($gefunden) { SendJson $ctx @{ ok = $true; id = $id; zug = $zug; weitergeben = $wert } }
              else { SendJson $ctx @{ ok = $false; fehler = "Zug $zug gibt es in $id nicht" } 404 }
            }
          }
          elseif ($pfad -eq '/stopp') {
            $k = LiesKoerper $ctx
            $id = if ($k) { [string]$k.id } else { '' }
            if (-not (RaumGueltig $id)) { SendJson $ctx @{ ok = $false; fehler = 'id fehlt oder ist ungültig' } 400 }
            else { SendJson $ctx @{ ok = $true; gestoppt = [bool](RaumStoppen $id 'bene') } }
          }
          elseif ($pfad -eq '/__stop') { Log 'Tür schließt (per /__stop)' 'Yellow'; SendJson $ctx @{ ok = $true; msg = 'bye' }; $script:Ende = $true }
          elseif ($pfad -eq '/') {
            $s = StandObjekt
            $html = '<!doctype html><meta charset="utf-8"><title>Johns Hände</title>' +
              '<style>body{font:14px/1.6 system-ui;margin:2rem;max-width:44rem;color:#1b1f18}code{background:#eee;padding:1px 5px;border-radius:4px}</style>' +
              '<h1>Johns Hände sind wach</h1><p>Gerät <b>' + $s.geraet + '</b>, Worker ' + $VERSION + '.</p>' +
              '<p>Cockpit-Server: ' + $(if ($s.serverLaeuft) { 'läuft' } else { 'aus' }) + ' · denkt gerade: ' + $(if ($s.denkt) { 'ja (' + $s.denktAn + ')' } else { 'nein' }) + '</p>' +
              '<p>Diese Tür ist für die Lobby im Compass da: <code>/stand</code>, <code>/wecken</code>, <code>/takt</code>, ' +
              'dazu der Gesprächsraum: <code>/raeume</code>, <code>/raum</code>, <code>/stopp</code>. Handlungen nur per POST.</p>'
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
    # Solange im Raum gesprochen wird, alle 10 s: ein Stopp vom Handy kommt nur über den Puls an.
    $pulsAbstand = if (@($script:Kinder | Where-Object { $_.art -eq 'raum' }).Count) { 10 } else { 60 }
    if (($jetzt - $letzterPuls).TotalSeconds -ge $pulsAbstand) { PulsSenden; $letzterPuls = $jetzt }

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

    # ---- 3. Gesprächsraum vor dem Takt: dort wartet ein Mensch auf eine Antwort ----
    if ($script:RaumWarte.Count -and -not (DenktGerade)) {
      $w = $script:RaumWarte[0]; $script:RaumWarte.RemoveAt(0)
      if (Test-Path (RaumPfad $w.raum)) { KindStarten 'raum' $null $w.raum $w.an | Out-Null }
    }

    # ---- 3b. Johns eigener Rhythmus ----
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

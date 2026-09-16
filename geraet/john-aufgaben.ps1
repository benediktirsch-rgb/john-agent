<#
  john-aufgaben.ps1 — John bleibt von selbst wach (10.09.2026)

  Drei geplante Aufgaben halten John auf diesem Gerät am Leben. Jede hat genau eine Aufgabe;
  keine von ihnen weiß etwas über die anderen:

    „John Server"        startet den Cockpit-Server (Port 8787), wenn er nicht läuft.
                         Bisher alle 5 Minuten — jetzt jede Minute. Das ist die Zahl, die in
                         Johns Lobby steht („versucht es jede Minute"); wer sie hier ändert,
                         macht die Lobby zur Lügnerin.
    „John Server Wacht"  erkennt einen BLOCKIERTEN Server (Port offen, keine Antwort) und
                         beendet ihn, damit die erste Aufgabe ihn neu starten kann.
    „John Worker"        hält Johns Hände wach (john-worker.ps1): Tür auf 8788, eigener Takt,
                         Puls an die Rezeption. Das ist der Teil, der John zum Agenten macht.

  Warum die Aufgaben interaktiv laufen (nur bei angemeldetem Benutzer): sie brauchen die
  User-Umgebungsvariablen (JOHN_HUB_TOKEN, ANTHROPIC_*, TRELLO_*) und die Anmeldung von
  Claude Code. In Sitzung 0 gäbe es beides nicht — John liefe halb blind. Der Preis: schläft
  der Rechner, schlafen Johns Hände. Genau dafür gibt es die Rezeption im WWW, die weiterlebt.

  Bedienung
    -Register     alle drei Aufgaben einrichten/erneuern und die Lobby in den Compass kopieren
    -Status       was läuft gerade, was antwortet
    -Unregister   nur die Worker-Aufgabe entfernen (Server und Wacht bleiben)
    -Sync         nur die Lobby-Datei nach flow-compass kopieren
    -TaktMinuten  Abstand zwischen zwei Takten (Standard 30)
#>
param(
  [switch]$Register,
  [switch]$Unregister,
  [switch]$Status,
  [switch]$Sync,
  [int]$TaktMinuten = 30,
  [int]$Port = 8788,
  [int]$ServerMinuten = 1
)
$ErrorActionPreference = 'Stop'

$Hier        = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo        = Split-Path -Parent $Hier
$Worker      = Join-Path $Hier 'john-worker.ps1'
$Compass     = 'C:\dev\persoenliches-dashboard'
$ServerTask  = 'John Server'
$WachtTask   = 'John Server Wacht'
$WorkerTask  = 'John Worker'
$ServerSkript = Join-Path $Compass 'john-server-aufgabe.ps1'
# Dateien, die hier gepflegt und in den Compass kopiert werden (Lobby 10.09., Gesprächsraum 11.09. von Astra)
$CompassDateien = @('compass-john-lobby.js', 'compass-gespraechsraum.js', 'compass-fragen-rezeption.js', 'holodeck-engine/scenes.js', 'holodeck-engine/production.js', 'holodeck-engine/cinema.js', 'holodeck-engine/cinema.css', 'holodeck-engine/studio-audio.js', 'holodeck-engine/studio-direction.js', 'holodeck-engine/sternenszenen.js', 'holodeck-engine/experience.js', 'holodeck-engine/experience.css', 'holodeck-engine/coach-door.js')

function Da([string]$n) { return (Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue) }
function PortAntwortet([int]$p) {
  $c = New-Object Net.Sockets.TcpClient
  try { $a = $c.BeginConnect('127.0.0.1', $p, $null, $null); if (-not $a.AsyncWaitHandle.WaitOne(1200)) { return $false }; $c.EndConnect($a); return $true }
  catch { return $false } finally { $c.Close() }
}

# ── Lobby in den Compass kopieren ────────────────────────────────────────────────────────
# Die Datei wird hier gepflegt (john-agent ist das Architektur-Repo), gebraucht wird sie im
# Compass. Kopieren statt Verlinken: der Compass-Build liest den Ordner, und eine Verknüpfung
# über zwei Repos hinweg wäre genau die Art Magie, die nach drei Monaten niemand mehr versteht.
function LobbySync {
  $ok = $true; $kopiert = $false
  foreach ($datei in $CompassDateien) {
    $quelle = Join-Path $Repo "compass\$datei"; $ziel = Join-Path $Compass $datei
    if (-not (Test-Path $quelle)) { Write-Host "Quelle fehlt: $quelle" -ForegroundColor Red; $ok = $false; continue }
    $neu = [IO.File]::ReadAllText($quelle, [Text.Encoding]::UTF8).Replace("`r`n", "`n")
    $alt = if (Test-Path $ziel) { [IO.File]::ReadAllText($ziel, [Text.Encoding]::UTF8) } else { '' }
    if ($alt -eq $neu) { Write-Host "${datei}: unveraendert"; continue }
    [IO.Directory]::CreateDirectory((Split-Path -Parent $ziel)) | Out-Null
    [IO.File]::WriteAllText($ziel, $neu, (New-Object Text.UTF8Encoding($false)))
    Write-Host "$datei kopiert -> $ziel  ($($neu.Length) Zeichen)" -ForegroundColor Green; $kopiert = $true
  }
  if ($kopiert) { Write-Host "  Danach: build-compass.ps1 (oder die Aufgabe 'Vishnu Flow Compass publish' abwarten)." }
  return $ok
}

if ($Sync) { LobbySync | Out-Null; return }

if ($Unregister) {
  if (Da $WorkerTask) {
    try { Stop-ScheduledTask -TaskName $WorkerTask -ErrorAction SilentlyContinue } catch { }
    Unregister-ScheduledTask -TaskName $WorkerTask -Confirm:$false
    "Aufgabe '$WorkerTask' entfernt. Der laufende Worker beendet sich beim nächsten /__stop oder Neustart."
  } else { "Aufgabe '$WorkerTask' war nicht eingerichtet." }
  "Server und Wacht bleiben unangetastet."
  return
}

if ($Status) {
  "Johns Gerät: $($env:COMPUTERNAME.ToLower())"
  ''
  foreach ($n in @($ServerTask, $WachtTask, $WorkerTask)) {
    $t = Da $n
    if (-not $t) { "{0,-20} nicht eingerichtet" -f $n; continue }
    $i = Get-ScheduledTaskInfo -TaskName $n
    $wdh = ''
    foreach ($tr in $t.Triggers) { if ($tr.Repetition -and $tr.Repetition.Interval) { $wdh = $tr.Repetition.Interval } }
    "{0,-20} {1,-9} Wiederholung {2,-6} letzter Lauf {3}" -f $n, $t.State, $(if ($wdh) { $wdh } else { '—' }), $i.LastRunTime
  }
  ''
  "Port 8787 (Cockpit): " + $(if (PortAntwortet 8787) { 'antwortet' } else { 'keine Antwort' })
  "Port $Port (Tür)   : " + $(if (PortAntwortet $Port) { 'antwortet' } else { 'keine Antwort' })
  ''
  if (Test-Path $Worker) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Worker -Status }
  return
}

if (-not $Register) {
  "Nichts zu tun. -Register richtet ein, -Status zeigt den Stand, -Sync kopiert nur die Lobby."
  return
}

# ── 1. Lobby ─────────────────────────────────────────────────────────────────────────────
LobbySync | Out-Null
''

# ── 2. „John Server": von 5 auf 1 Minute ─────────────────────────────────────────────────
# Bewusst NICHT über -Register des anderen Skripts: das entfernt die Aufgabe zuerst und würde
# den gerade laufenden Server mit abräumen. Set-ScheduledTask ändert nur den Auslöser und
# lässt die laufende Instanz in Ruhe.
$st = Da $ServerTask
if (-not $st) {
  if (Test-Path $ServerSkript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ServerSkript -Register -AlleMinuten $ServerMinuten
  } else { "WARNUNG: '$ServerTask' fehlt und $ServerSkript ist nicht da." }
} else {
  $soll = [TimeSpan]::FromMinutes($ServerMinuten)
  $geaendert = $false
  foreach ($tr in $st.Triggers) {
    if ($tr.Repetition -and $tr.Repetition.Interval) {
      $ist = $null
      try { $ist = [Xml.XmlConvert]::ToTimeSpan($tr.Repetition.Interval) } catch { }
      if ($ist -ne $soll) { $tr.Repetition.Interval = [Xml.XmlConvert]::ToString($soll); $geaendert = $true }
    }
  }
  if ($geaendert) {
    Set-ScheduledTask -TaskName $ServerTask -Trigger $st.Triggers | Out-Null
    "Aufgabe '$ServerTask': Wiederholung auf $ServerMinuten Minute(n) gestellt (vorher 5)."
  } else { "Aufgabe '$ServerTask': steht schon auf $ServerMinuten Minute(n)." }
}

# ── 3. „John Server Wacht" ───────────────────────────────────────────────────────────────
if (-not (Da $WachtTask)) {
  if (Test-Path $ServerSkript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ServerSkript -RegisterWacht
  }
} else { "Aufgabe '$WachtTask': vorhanden." }

# ── 4. „John Worker" ─────────────────────────────────────────────────────────────────────
# Dieselben zwei Regeln wie beim Server, aus demselben Grund:
#   ExecutionTimeLimit = 0  — mit Zeitlimit würde der Planer den Worker abschießen, den er
#                             bewachen soll (er läuft absichtlich für immer).
#   LogonType Interactive   — er braucht die User-Umgebung und die Claude-Anmeldung.
# Wiederholung alle 2 Minuten mit IgnoreNew: läuft er, passiert nichts; ist er weg, kommt er
# binnen zwei Minuten zurück. Einen zweiten Worker kann es dadurch nie geben — und selbst
# wenn: der zweite fände die Tür belegt, sagte das ins Log und beendete sich.
$aktion = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Worker`" -TaktMinuten $TaktMinuten -Port $Port" `
  -WorkingDirectory $Hier
$tLogon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$tTakt = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 2)
$tTakt.Repetition.Duration = ''
$tTakt.Repetition.StopAtDurationEnd = $false
$einst = New-ScheduledTaskSettingsSet `
  -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -StartWhenAvailable -DontStopOnIdleEnd `
  -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$prinzip = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
if (Da $WorkerTask) { Unregister-ScheduledTask -TaskName $WorkerTask -Confirm:$false }
Register-ScheduledTask -TaskName $WorkerTask -Action $aktion -Trigger @($tLogon, $tTakt) `
  -Settings $einst -Principal $prinzip `
  -Description "Johns Hände auf diesem Gerät: Tür auf Port $Port (die Lobby im Compass fragt sie), eigener Takt alle $TaktMinuten Minuten (Mo-Fr 6:30-21:30), Puls an die Rezeption. Startet bei der Anmeldung und alle 2 Minuten neu, falls er fehlt." | Out-Null
"Aufgabe '$WorkerTask' eingerichtet: Anmeldung + alle 2 Minuten, Takt alle $TaktMinuten Min."

Start-ScheduledTask -TaskName $WorkerTask
Start-Sleep -Seconds 3
"Tür $Port : " + $(if (PortAntwortet $Port) { 'antwortet — Johns Hände sind wach.' } else { 'noch keine Antwort (bis zu 2 Minuten geben, dann -Status).' })
''
"Weiter: john-aufgaben.ps1 -Status  ·  Rezeption einrichten: docs\kas-schritte.md"

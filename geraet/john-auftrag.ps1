<#
  john-auftrag.ps1 — ein einzelner Denkvorgang, abgekoppelt (10.09.2026)

  Der Worker (john-worker.ps1) startet dieses Skript als eigenen Prozess und wartet NICHT auf
  das Ergebnis. Genau darum darf hier alles langsam sein: 90 s Claude-Aufruf, ein zäher
  Netzzugriff, ein großes Lesen. Stürzt es ab oder hängt es, kostet das einen Auftrag —
  nicht Johns Erreichbarkeit. Der Worker beendet Kinder, die länger als 12 Minuten brauchen.

  Arten
    takt    Johns eigener Rhythmus: „Braucht gerade etwas eine Handlung?" (Standard)
    hub     einen Auftrag von der Rezeption holen, ausführen, Ergebnis zurückmelden
    frage   eine einzelne Frage beantworten (-Text), Antwort in die Rezeption
    stapel  Johns Stapel neu sortieren (nur mit Rezeption sinnvoll, siehe unten)

  Warum hier NICHT john-stapel.json geschrieben wird
    Diese Datei gehört dem Cockpit-Server: er hält sie in `$script:Stapel` im Speicher und
    überschreibt sie bei jeder Änderung vollständig. Ein Schreiben von außen wäre beim
    nächsten Save-Stapel lautlos verloren. Johns Erkenntnis geht deshalb zwei Wege, die
    beide gelesen werden: in die Rezeption (gilt auf allen Geräten) und in seine eigenen
    Notizen (john\coaching\), die er beim nächsten Denken selbst mitliest.

  Warum der Claude-Aufruf hier noch einmal steht
    Der Cockpit-Server hat mit Invoke-ClaudeCli denselben Weg — aber er ist 331 kB groß und
    kann nicht geladen werden, ohne den Server zu starten. Der Worker muss ohne ihn denken
    können, sonst wäre er wieder von dem Prozess abhängig, dessen Ausfall er überbrücken
    soll. Diese Doppelung ist bewusst und ist als Schuld notiert (docs\adr\0003).
#>
param(
  [ValidateSet('takt','hub','frage','stapel')][string]$Art = 'takt',
  [string]$Text = '',
  [string]$Geraet = '',
  [string]$Modell = 'claude-opus-5',
  [string]$Effort = 'medium',
  [int]$TimeoutSek = 420,
  [switch]$Trocken   # denken, aber nichts schreiben und nichts senden
)
$ErrorActionPreference = 'Stop'

$Utf8NoBom = New-Object Text.UTF8Encoding($false)
$Hier      = Split-Path -Parent $MyInvocation.MyCommand.Path
$Compass   = 'C:\dev\persoenliches-dashboard'
$JohnDir   = 'C:\dev\john'
$LogDatei  = Join-Path $Hier 'john-auftrag.log'
$HashDatei = Join-Path $Hier 'takt-hash.txt'
$ErgDatei  = Join-Path $Hier 'letzter-takt.json'

function LiesEnv([string]$n, $std) {
  foreach ($s in @('Process','User')) { $v = [Environment]::GetEnvironmentVariable($n, $s); if ($v -and $v.Trim()) { return $v.Trim() } }
  return $std
}
if (-not $Geraet) { $Geraet = LiesEnv 'JOHN_GERAET' ($env:COMPUTERNAME.ToLower()) }
$Hub      = ([string](LiesEnv 'JOHN_HUB_URL' 'https://naturnah-lernen.de/john')).TrimEnd('/')
$HubToken = LiesEnv 'JOHN_HUB_TOKEN' ''

function Log([string]$m) {
  $z = "{0:yyyy-MM-dd HH:mm:ss}  [{1}] {2}" -f (Get-Date), $Art, $m
  try {
    if (Test-Path $LogDatei) {
      $alt = @([IO.File]::ReadAllLines($LogDatei, [Text.Encoding]::UTF8))
      if ($alt.Count -gt 600) { [IO.File]::WriteAllLines($LogDatei, $alt[-300..-1], $Utf8NoBom) }
    }
    Add-Content -Path $LogDatei -Value $z -Encoding UTF8
  } catch { }
  Write-Host $z
}
function Lies([string]$pfad, [int]$maxZeichen = 4000, [int]$letzteZeilen = 0) {
  if (-not (Test-Path -LiteralPath $pfad)) { return '' }
  try {
    if ($letzteZeilen -gt 0) {
      $z = @([IO.File]::ReadAllLines($pfad, [Text.Encoding]::UTF8))
      if ($z.Count -gt $letzteZeilen) { $z = $z[($z.Count - $letzteZeilen)..($z.Count - 1)] }
      $t = ($z -join "`n")
    } else { $t = [IO.File]::ReadAllText($pfad, [Text.Encoding]::UTF8) }
    if ($t.Length -gt $maxZeichen) { $t = $t.Substring(0, $maxZeichen) + "`n… (gekürzt)" }
    return $t
  } catch { return '' }
}

# ── Claude Code im Kopflos-Modus (Benes Abo, nicht die API) ──────────────────────────────
function Quote-Arg([string]$a) { if ($a -eq '') { return '""' }; if ($a -match '[\s"]') { return '"' + ($a -replace '"', '\"') + '"' }; return $a }

function Find-ClaudeExe {
  $kand = New-Object System.Collections.Generic.List[string]
  $v = LiesEnv 'JOHN_CLAUDE_EXE' $null; if ($v) { $kand.Add($v) }
  $kand.Add((Join-Path $env:USERPROFILE '.local\bin\claude.exe'))
  $cmd = Get-Command claude -ErrorAction SilentlyContinue; if ($cmd -and $cmd.Source) { $kand.Add($cmd.Source) }
  $wurzeln = @((Join-Path $env:APPDATA 'Claude\claude-code'))
  foreach ($paket in @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue)) {
    $wurzeln += (Join-Path $paket.FullName 'LocalCache\Roaming\Claude\claude-code')
  }
  foreach ($cc in $wurzeln) {
    if (Test-Path $cc) {
      Get-ChildItem $cc -Directory -ErrorAction SilentlyContinue |
        Sort-Object { $x = $null; if ([version]::TryParse($_.Name, [ref]$x)) { $x } else { [version]'0.0' } } -Descending |
        ForEach-Object { $kand.Add((Join-Path $_.FullName 'claude.exe')) }
    }
  }
  foreach ($k in $kand) { if ($k -and (Test-Path $k)) { return $k } }
  return $null
}

# Der Aufruf selbst. Systemprompt als Datei (passt in keine Kommandozeile), Prompt über stdin,
# Antwort als JSON auf stdout. Kein API-Schlüssel in der Umgebung — sonst rechnet Claude Code
# über die API ab statt über das Abo, und genau das war am 07.09. der Fehler.
function Rufe-Claude([string]$systemText, [string]$prompt) {
  $exe = Find-ClaudeExe
  if (-not $exe) { throw 'NO_CLI: claude.exe nicht gefunden (JOHN_CLAUDE_EXE setzen)' }
  $puf = Join-Path $env:LOCALAPPDATA 'john-agent\puffer'
  if (-not (Test-Path $puf)) { New-Item -ItemType Directory -Force $puf | Out-Null }
  $cwd = Join-Path $env:LOCALAPPDATA 'john-agent\cwd'
  if (-not (Test-Path $cwd)) { New-Item -ItemType Directory -Force $cwd | Out-Null }
  $sysDatei = Join-Path $puf ("system-" + [DateTime]::Now.Ticks + ".md")
  [IO.File]::WriteAllText($sysDatei, $systemText, $Utf8NoBom)
  $argv = @('-p','--output-format','json','--system-prompt-file',$sysDatei,'--model',$Modell,
            '--effort',$Effort,'--max-turns','1','--no-session-persistence','--strict-mcp-config',
            '--setting-sources','','--permission-mode','dontAsk','--tools','')
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  $psi.Arguments = (($argv | ForEach-Object { Quote-Arg $_ }) -join ' ')
  $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
  $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = $Utf8NoBom; $psi.StandardErrorEncoding = $Utf8NoBom
  $psi.WorkingDirectory = $cwd
  foreach ($k in @($psi.EnvironmentVariables.Keys)) { if ($k -match '^(CLAUDECODE|CLAUDE_CODE_)') { $psi.EnvironmentVariables.Remove($k) } }
  foreach ($k in @('ANTHROPIC_API_KEY','ANTHROPIC_AUTH_TOKEN')) { if ($psi.EnvironmentVariables.ContainsKey($k)) { $psi.EnvironmentVariables.Remove($k) } }
  $psi.EnvironmentVariables['DISABLE_AUTOUPDATER'] = '1'
  $psi.EnvironmentVariables['CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC'] = '1'
  $t0 = Get-Date
  try {
    $p = [Diagnostics.Process]::Start($psi)
    $outT = $p.StandardOutput.ReadToEndAsync(); $errT = $p.StandardError.ReadToEndAsync()
    try {
      $b = $Utf8NoBom.GetBytes($prompt)
      $p.StandardInput.BaseStream.Write($b, 0, $b.Length); $p.StandardInput.BaseStream.Flush()
    } catch [System.IO.IOException] { } finally { try { $p.StandardInput.Close() } catch { } }
    if (-not $p.WaitForExit($TimeoutSek * 1000)) { try { $p.Kill() } catch { }; throw 'CLI_TIMEOUT' }
    $stdout = $outT.GetAwaiter().GetResult(); $stderr = $errT.GetAwaiter().GetResult()
    $zeile = ($stdout -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -Last 1)
    $j = $null; if ($zeile) { try { $j = $zeile | ConvertFrom-Json } catch { $j = $null } }
    if (-not $j) {
      $roh = (($stderr + ' ' + $stdout).Trim() -replace '\s+', ' ')
      if ($roh.Length -gt 300) { $roh = $roh.Substring(0, 300) }
      throw "CLI ($($p.ExitCode)): $roh"
    }
    if ($j.is_error) {
      $m = [string]$j.result
      if ($m -match '(?i)not logged in|/login|authentication|OAuth token') { throw 'NO_LOGIN' }
      if ($m -match '(?i)credit balance') { throw 'NO_CREDIT' }
      if ($m -match '(?i)usage limit|rate limit|limit reached|too many requests|overloaded') { throw 'LIMIT' }
      throw "CLI: $m"
    }
    Log ("Claude Code: {0:n0} s, {1} Runde(n)" -f ((Get-Date) - $t0).TotalSeconds, [int]$j.num_turns)
    return [string]$j.result
  } finally { Remove-Item $sysDatei -Force -ErrorAction SilentlyContinue }
}

# JSON aus einer Antwort schälen, die vielleicht in ```json eingepackt ist.
function SchaeleJson([string]$t) {
  if (-not $t) { return $null }
  $s = $t.Trim()
  $m = [regex]::Match($s, '(?s)\{.*\}')
  if (-not $m.Success) { return $null }
  try { return ($m.Value | ConvertFrom-Json) } catch { return $null }
}

# ── Rezeption ────────────────────────────────────────────────────────────────────────────
function HubRuf([string]$was, $koerper, [string]$methode = 'POST') {
  if (-not $HubToken) { return $null }
  try {
    $url = "$Hub/api.php?w=$was"
    $req = [Net.HttpWebRequest]::Create($url)
    $req.Method = $methode
    $req.Timeout = 20000; $req.ReadWriteTimeout = 20000
    $req.Headers['X-John-Token'] = $HubToken
    $req.UserAgent = "john-worker/$Geraet"
    if ($methode -eq 'POST') {
      $json = ($koerper | ConvertTo-Json -Depth 12 -Compress)
      $b = [Text.Encoding]::UTF8.GetBytes($json)
      $req.ContentType = 'application/json; charset=utf-8'; $req.ContentLength = $b.Length
      $s = $req.GetRequestStream(); $s.Write($b, 0, $b.Length); $s.Close()
    }
    $res = $req.GetResponse()
    $sr = New-Object IO.StreamReader($res.GetResponseStream(), [Text.Encoding]::UTF8)
    $txt = $sr.ReadToEnd(); $sr.Close(); $res.Close()
    return ($txt | ConvertFrom-Json)
  } catch { Log "Rezeption ($was): $($_.Exception.Message)"; return $null }
}

# ── Johns Kopf: Persona + Lage ───────────────────────────────────────────────────────────
function JohnSystem {
  $persona = Lies (Join-Path $JohnDir 'CLAUDE.md') 14000
  return @"
$persona

--- Auftrag dieses Aufrufs (Takt, $(Get-Date -Format 'dd.MM.yyyy HH:mm')) ---
Du läufst gerade NICHT im Chat, sondern in deinem eigenen Takt auf Benedikts Rechner. Niemand hat
dich etwas gefragt. Du siehst nach, ob etwas jetzt eine Handlung braucht — und meistens ist die
richtige Antwort „nein, nichts Neues". Ein Coach, der alle 30 Minuten etwas ruft, ist ein Wecker.

Antworte AUSSCHLIESSLICH mit einem JSON-Objekt, ohne Vorwort, ohne Code-Zaun:
{
  "handeln": true|false,
  "grund": "<ein Satz: warum jetzt handeln oder warum nicht>",
  "punkte": [ { "titel": "<Benes Sprache, eine Zeile>",
                "warum": "<ein Satz Begründung mit Datum/Frist, wenn es eine gibt>",
                "art": "entscheiden|karte|mail|termin|john|claude|link|board",
                "aktion": "<die EINE Aktion, die du wählst>" } ],
  "notiz": "<höchstens ein Satz für deine Notizen, oder leer>"
}
Regeln: höchstens drei Punkte, der wichtigste zuerst. Nichts erfinden — nur was in der Lage unten
belegt ist. Keine Frist behaupten, die dort nicht steht. Ist nichts fällig, "handeln": false und
"punkte": []. Ton wie immer: ruhig, direkt in der Sache.
"@
}

function LageText {
  $teile = @()
  $teile += "## Johns Aufgaben (john\TASKS.md)`n" + (Lies (Join-Path $JohnDir 'TASKS.md') 4500)
  $teile += "## Bewerbungs-Pipeline (Auszug)`n" + (Lies (Join-Path $JohnDir 'bewerbungen\pipeline.md') 5000)
  $teile += "## Mitglieder-Pipeline (Auszug)`n" + (Lies (Join-Path $JohnDir 'mitglieder\pipeline.md') 2500)
  $teile += "## Letzte Cockpit-Notizen (was Bene abgeräumt/entschieden hat)`n" + (Lies (Join-Path $JohnDir 'coaching\cockpit-notizen.md') 3000 60)
  $teile += "## Deine letzten Takte`n" + (Lies (Join-Path $JohnDir 'coaching\takt.md') 2000 40)
  # Der aktuelle Stapel-Stand: welche Punkte schon abgeräumt sind (Datei gehört dem Server, nur lesen!)
  $st = Join-Path $Compass 'john-stapel.json'
  if (Test-Path $st) { $teile += "## Stapel-Stand des Cockpit-Servers (nur lesen)`n" + (Lies $st 3000) }
  $checkins = Join-Path $Compass 'checkins'
  if (Test-Path $checkins) {
    $letzte = @(Get-ChildItem $checkins -Filter '*.md' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    if ($letzte.Count) { $teile += "## Letzter Checkin ($($letzte[0].Name))`n" + (Lies $letzte[0].FullName 3500) }
  }
  $teile += "## Heute`n" + (Get-Date -Format 'dddd, dd.MM.yyyy HH:mm')
  return ($teile -join "`n`n")
}

# ── Der Takt ─────────────────────────────────────────────────────────────────────────────
function TaktLauf {
  $lage = LageText
  # Kostenbremse mit Sinn: ändert sich an der Lage nichts, denkt John nicht neu. Das ist
  # dieselbe Regel wie der 4-Stunden-Puffer im Cockpit-Server — nur hier über den Inhalt.
  $hash = ''
  try {
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($lage))) -replace '-','').Substring(0, 16)
  } catch { }
  $alt = ''
  if (Test-Path $HashDatei) { try { $alt = ([IO.File]::ReadAllText($HashDatei, [Text.Encoding]::UTF8)).Trim() } catch { } }
  if ($hash -and $hash -eq $alt -and -not $Trocken) {
    Log 'Lage unverändert — kein Aufruf (Kontingent gespart).'
    return @{ ok = $true; uebersprungen = $true }
  }

  $antwort = Rufe-Claude (JohnSystem) $lage
  $d = SchaeleJson $antwort
  if (-not $d) { Log 'Antwort war kein JSON — verworfen.'; return @{ ok = $false; fehler = 'kein JSON' } }

  $punkte = @()
  if ($d.punkte) { $punkte = @($d.punkte | Where-Object { $_ -and $_.titel } | Select-Object -First 3) }
  $handeln = [bool]$d.handeln -and $punkte.Count -gt 0
  Log ("Ergebnis: " + $(if ($handeln) { "$($punkte.Count) Punkt(e) — " + [string]$d.grund } else { 'nichts zu tun — ' + [string]$d.grund }))

  if ($Trocken) { return @{ ok = $true; trocken = $true; punkte = $punkte; grund = [string]$d.grund } }

  if ($hash) { try { [IO.File]::WriteAllText($HashDatei, $hash, $Utf8NoBom) } catch { } }
  $erg = @{ zeit = (Get-Date).ToString('o'); geraet = $Geraet; handeln = $handeln
            grund = [string]$d.grund; punkte = $punkte; notiz = [string]$d.notiz }
  try { [IO.File]::WriteAllText($ErgDatei, ($erg | ConvertTo-Json -Depth 8), $Utf8NoBom) } catch { }

  # Weg 1: die Rezeption — gilt auf allen Geräten.
  if ($handeln -and $HubToken) {
    $r = HubRuf 'stapel' @{ stand = (Get-Date).ToString('o'); quelle = $Geraet
                            punkte = @($punkte | ForEach-Object { @{ id = ('takt-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
                                                                     titel = [string]$_.titel; warum = [string]$_.warum
                                                                     art = [string]$_.art; aktion = [string]$_.aktion } }) }
    if ($r -and $r.ok) { Log 'Stapel an die Rezeption übergeben.' } else { Log 'Rezeption hat den Stapel nicht angenommen.' }
    HubRuf 'log' @{ art = 'takt'; geraet = $Geraet; text = [string]$d.grund } | Out-Null
  }

  # Weg 2: Johns eigene Notizen — die liest er beim nächsten Denken selbst mit. Append-only:
  # keine fremde Zeile wird angefasst, kein Cache eines anderen Prozesses überschrieben.
  $taktDatei = Join-Path $JohnDir 'coaching\takt.md'
  $zeilen = @()
  if (-not (Test-Path $taktDatei)) {
    $zeilen += '# Johns Takt — was er von selbst gesehen hat'
    $zeilen += ''
    $zeilen += 'Angelegt am 10.09.2026 vom Worker (john-agent\geraet\john-auftrag.ps1). Eine Zeile je Takt,'
    $zeilen += 'nur wenn er etwas gefunden hat. Append-only — hier nichts umschreiben.'
    $zeilen += ''
  }
  if ($handeln) {
    $zeilen += ('- **{0:dd.MM.yyyy HH:mm}** ({1}) {2}' -f (Get-Date), $Geraet, [string]$d.grund)
    foreach ($p in $punkte) { $zeilen += ('    - {0} — {1} [{2}: {3}]' -f [string]$p.titel, [string]$p.warum, [string]$p.art, [string]$p.aktion) }
    if ($d.notiz) { $zeilen += ('    - Notiz: ' + [string]$d.notiz) }
  }
  if ($zeilen.Count) {
    try { Add-Content -Path $taktDatei -Value ($zeilen -join "`n") -Encoding UTF8 } catch { Log "takt.md: $($_.Exception.Message)" }
  }
  return @{ ok = $true; handeln = $handeln; punkte = $punkte }
}

# ── Ein Auftrag aus der Rezeption ────────────────────────────────────────────────────────
function HubLauf {
  if (-not $HubToken) { Log 'Keine Rezeption angebunden (JOHN_HUB_TOKEN fehlt).'; return @{ ok = $false } }
  $d = HubRuf 'auftraege' $null 'GET'
  if (-not $d -or -not $d.ok) { return @{ ok = $false } }
  $offen = @($d.auftraege)
  if (-not $offen.Count) { Log 'Keine offenen Aufträge.'; return @{ ok = $true } }
  $a = $offen[0]
  $nimm = HubRuf 'nimm' @{ id = $a.id; geraet = $Geraet }
  if (-not $nimm -or -not $nimm.ok) { Log "Auftrag $($a.id) ging an ein anderes Gerät."; return @{ ok = $true } }
  Log "Auftrag $($a.id) ($($a.art)) angenommen."
  try {
    $sys = (JohnSystem)
    $prompt = "Ein Auftrag aus dem Compass, Art $($a.art):`n$($a.text)`n`n--- Lage ---`n" + (LageText)
    if ($a.art -eq 'coach') {
      # Bene digital: eine Buchung aus dem Vishnu-Backend. Die Brandmauer dieses Skripts —
      # KEIN JohnSystem, KEINE LageText, nichts aus C:\dev\john. John kennt Benes Leben; die
      # Person, die hier fragt, bekommt davon nichts, auch nicht aus Versehen. Die Antwort ist ein
      # Entwurf: sichtbar wird sie erst, wenn Bene sie auf der Seite freigibt.
      $persona = Join-Path (Split-Path -Parent $Hier) 'wissen\bene-digital.md'
      if (-not (Test-Path $persona)) { throw 'bene-digital.md fehlt — ohne oeffentliche Persona keine Antwort' }
      $sys = [IO.File]::ReadAllText($persona, [Text.Encoding]::UTF8)
      $themen = @{ flow = 'Flow und Kanban'; karriere = 'Karriere und Positionierung'; ki = 'KI im Arbeitsalltag'; fuehrung = 'Fuehrung und Team' }
      $thema = if ($a.thema -and $themen.ContainsKey([string]$a.thema)) { $themen[[string]$a.thema] } else { 'offen' }
      $prompt = "Thema: $thema`n" + $(if ($a.vorname) { "Die Person heisst $($a.vorname).`n" } else { '' }) +
                $(if ($a.form -eq 'gespraech') { "Sie wuenscht sich zusaetzlich ein Gespraech; beantworte trotzdem schriftlich, was schriftlich geht, und sag, was ins Gespraech gehoert.`n" } else { '' }) +
                "`nIhre Frage:`n$($a.text)"
    }
    elseif ($a.art -eq 'frage') {
      $sys = (Lies (Join-Path $JohnDir 'CLAUDE.md') 14000) + "`n`nAntworte als John in zwei bis sechs Sätzen, ohne JSON."
      $prompt = "$($a.text)`n`n--- Lage ---`n" + (LageText)
    }
    $antwort = Rufe-Claude $sys $prompt
    HubRuf 'ergebnis' @{ id = $a.id; ok = $true; text = $antwort; notiz = $(if ($a.art -eq 'coach') { 'Entwurf - wartet auf Benes Freigabe' } else { '' }) } | Out-Null
    Log ("Auftrag $($a.id) beantwortet" + $(if ($a.art -eq 'coach') { ' (Bene digital, Entwurf)' } else { '' }) + '.')
    return @{ ok = $true }
  } catch {
    HubRuf 'ergebnis' @{ id = $a.id; ok = $false; text = $_.Exception.Message } | Out-Null
    Log "Auftrag $($a.id) gescheitert: $($_.Exception.Message)"
    return @{ ok = $false }
  }
}

# ── Los ──────────────────────────────────────────────────────────────────────────────────
try {
  switch ($Art) {
    'takt'   { $r = TaktLauf }
    'hub'    { $r = HubLauf }
    'stapel' { $r = TaktLauf }
    'frage'  {
      if (-not $Text) { throw '-Text fehlt' }
      $sys = (Lies (Join-Path $JohnDir 'CLAUDE.md') 14000) + "`n`nAntworte als John in zwei bis sechs Sätzen, ohne JSON."
      $antwort = Rufe-Claude $sys ("$Text`n`n--- Lage ---`n" + (LageText))
      Write-Output $antwort
      $r = @{ ok = $true }
    }
  }
  if ($r -and -not $r.ok) { exit 1 }
  exit 0
} catch {
  Log "Abbruch: $($_.Exception.Message)"
  if ($HubToken) { HubRuf 'log' @{ art = 'fehler'; geraet = $Geraet; text = "Auftrag $Art : $($_.Exception.Message)" } | Out-Null }
  exit 1
}

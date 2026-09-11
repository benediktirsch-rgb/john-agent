<#
  john-ki.ps1 — der eine Weg zu den Modellen, für den Worker (11.09.2026)

  Wird von john-auftrag.ps1 per Dot-Sourcing geladen und nutzt dessen Umgebung: $Utf8NoBom,
  LiesEnv, Log, Lies, $JohnDir, $Modell, $Effort, $TimeoutSek. Allein aufgerufen tut die Datei nichts.

  John   → Claude Code im Kopflos-Modus (Benes Claude-Abo)       Rufe-Claude
  Madeleine → Codex CLI (Benes ChatGPT-Abo)                        Rufe-Codex, MadeleineSystem

  Warum eine eigene Datei: der Worker muss beide rufen können, ohne dass der Cockpit-Server läuft
  (john-agent ADR 0003, madelene-agent ADR 0002). Der Server hat seine eigene Fassung noch in
  john-server.ps1 / john-madeleine.ps1 — ändert sich ein Flag oder ein Fehlerfall, beide Stellen
  nachziehen, bis der Server diese Datei ebenfalls lädt.
#>
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


# ── Codex CLI (Madeleine, ChatGPT-Abo, nicht die API) ────────────────────────────────────
# Gleicher Weg wie Invoke-CodexCli in flow-compass/john-madeleine.ps1 — dort lädt ihn nur der
# Cockpit-Server. Hier steht er, damit der Worker Madeleine rufen kann, ohne dass dieser Server
# läuft (madelene-agent ADR 0002). Anmeldung muss als Datei liegen (~\.codex\auth.json,
# cli_auth_credentials_store = "file"), sonst sieht dieser Prozess sie nicht.
function Find-CodexExe {
  $e = LiesEnv 'JOHN_CODEX_EXE' $null; if ($e -and (Test-Path $e)) { return $e }
  $c = Get-Command codex -ErrorAction SilentlyContinue; if ($c) { return $c.Source }
  $w = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\codex.exe'; if (Test-Path $w) { return $w }
  return $null
}
# Prompt über stdin, Antwort über -o in eine Datei. OPENAI_API_KEY und ANTHROPIC_* raus: sonst
# rechnet Codex doch über die API ab statt über Benes ChatGPT-Abo.
function Rufe-Codex([string]$prompt, [int]$timeoutSek = 300) {
  $exe = Find-CodexExe
  if (-not $exe) { throw 'CODEX_NO_CLI: codex nicht gefunden (winget install OpenAI.Codex, dann codex login)' }
  $puf = Join-Path $env:LOCALAPPDATA 'john-agent\puffer'
  if (-not (Test-Path $puf)) { New-Item -ItemType Directory -Force $puf | Out-Null }
  $cwd = Join-Path $env:LOCALAPPDATA 'john-agent\codex-cwd'
  if (-not (Test-Path $cwd)) { New-Item -ItemType Directory -Force $cwd | Out-Null }
  $aus = Join-Path $puf ("madeleine-" + [DateTime]::Now.Ticks + ".md")
  $argv = @('exec', '--skip-git-repo-check', '--ephemeral', '--color', 'never', '-s', 'read-only', '-C', $cwd, '-o', $aus)
  $m = LiesEnv 'JOHN_MADELEINE_MODEL' $null; if ($m) { $argv += @('-m', $m) }
  $argv += '-'
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  $psi.Arguments = (($argv | ForEach-Object { Quote-Arg $_ }) -join ' ')
  $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
  $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = $Utf8NoBom; $psi.StandardErrorEncoding = $Utf8NoBom
  $psi.WorkingDirectory = $cwd
  foreach ($k in @($psi.EnvironmentVariables.Keys)) { if ($k -match '^(CLAUDECODE|CLAUDE_CODE_)') { $psi.EnvironmentVariables.Remove($k) } }
  foreach ($k in @('OPENAI_API_KEY','OPENAI_BASE_URL','ANTHROPIC_API_KEY','ANTHROPIC_AUTH_TOKEN')) { if ($psi.EnvironmentVariables.ContainsKey($k)) { $psi.EnvironmentVariables.Remove($k) } }
  $t0 = Get-Date
  try {
    $p = [Diagnostics.Process]::Start($psi)
    $outT = $p.StandardOutput.ReadToEndAsync(); $errT = $p.StandardError.ReadToEndAsync()
    try {
      $b = $Utf8NoBom.GetBytes($prompt)
      $p.StandardInput.BaseStream.Write($b, 0, $b.Length); $p.StandardInput.BaseStream.Flush()
    } catch [System.IO.IOException] { } finally { try { $p.StandardInput.Close() } catch { } }
    if (-not $p.WaitForExit($timeoutSek * 1000)) { try { $p.Kill() } catch { }; throw 'CODEX_TIMEOUT' }
    $stdout = $outT.GetAwaiter().GetResult(); $stderr = $errT.GetAwaiter().GetResult()
    $text = if (Test-Path $aus) { [IO.File]::ReadAllText($aus, $Utf8NoBom) } else { '' }
    if (-not $text.Trim()) {
      $err = ($stderr + ' ' + $stdout)
      if ($err -match '(?i)\b401\b|unauthorized|not logged in|codex login') { throw 'CODEX_LOGIN' }
      if ($err -match '(?i)usage limit|rate limit|\b429\b|too many requests|quota') { throw 'CODEX_LIMIT' }
      $roh = ($err.Trim() -replace '\s+', ' '); if ($roh.Length -gt 300) { $roh = $roh.Substring(0, 300) }
      throw "Codex ($($p.ExitCode)): $roh"
    }
    Log ("Codex: {0:n0} s" -f ((Get-Date) - $t0).TotalSeconds)
    return $text.Trim()
  } finally { Remove-Item $aus -Force -ErrorAction SilentlyContinue }
}

# ── Madeleines Kopf, ohne Cockpit-Server ─────────────────────────────────────────────────
# Dieselben Quellen wie Build-SystemMadeleine im Server: Persona, Wissen, eigene Notizen, Johns
# Coaching-Ordner (gemeinsame Ablage), privater Stand (kompakt), Live-Zahlen aus dem Finanzlauf.
# Alles liest aus C:\dev\madeleine — dieser Code steht im öffentlichen Repo, die Daten nie.
$script:MadeleineDir = 'C:\dev\madeleine'
# Adresse und Token als User-Variablen: FINANZ_KPI_URL (Endpunkt des Finanzlaufs, ohne ?voll=1) und
# FINANZ_TOKEN. Fehlt eins, sagt Madeleine, dass der Finanzlauf nicht erreichbar ist.
function Get-FinanzLive {
  $t = LiesEnv 'FINANZ_TOKEN' $null
  $url = LiesEnv 'FINANZ_KPI_URL' $null
  if (-not $t -or -not $url) { return $null }
  try {
    $sha = [Security.Cryptography.SHA256]::Create()
    $ausweis = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($t)) | ForEach-Object { $_.ToString('x2') })
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $r = Invoke-RestMethod -Uri ($url + '?voll=1') -Method Get -TimeoutSec 20 `
           -Headers @{ 'X-Finanz-Token' = $ausweis } -UserAgent 'john-agent-worker/1.0'
    if (-not $r.ok) { return $null }
    $sub = [ordered]@{}
    foreach ($k in @('stichtag','ausgewertet','monat','kontostand','deckung','ergebnis','vormonat','einnahmen','kosten','warnung','belege','lux','fristen','sync','entscheidungen')) {
      if ($r.PSObject.Properties[$k]) { $sub[$k] = $r.$k }
    }
    $js = ($sub | ConvertTo-Json -Depth 8 -Compress); if ($js.Length -gt 14000) { $js = $js.Substring(0, 14000) + ' …(gekürzt)' }
    return $js
  } catch { Log "Finanzlauf nicht erreichbar: $($_.Exception.Message)"; return $null }
}
function MadeleineSystem {
  $teile = New-Object System.Collections.Generic.List[string]
  $persona = Lies (Join-Path $script:MadeleineDir 'CLAUDE.md') 12000
  $teile.Add("# Persona`n" + $(if ($persona) { $persona } else { 'Du bist Madeleine, Benedikts Beraterin für Finanzen, Steuern und Organisation. Klar, zahlenfest, nichts erfinden. Deutsch, Du-Form.' }))
  $wissen = Join-Path $script:MadeleineDir 'wissen'
  if (Test-Path $wissen) { Get-ChildItem $wissen -Filter *.md -File | Sort-Object Name | ForEach-Object { $x = Lies $_.FullName 12000; if ($x) { $teile.Add("# Datei: madeleine/wissen/$($_.Name)`n$x") } } }
  $stand = Join-Path $script:MadeleineDir 'privat\stand.json'
  if (Test-Path $stand) {
    try {
      $d = [IO.File]::ReadAllText($stand, [Text.Encoding]::UTF8) | ConvertFrom-Json
      $kompakt = [ordered]@{ erzeugt = [string]$d.erzeugt; konten = $d.konten; datenalter_tage = $d.datenalter; fixkosten = $d.fixkosten }
      $js = ($kompakt | ConvertTo-Json -Depth 6 -Compress); if ($js.Length -gt 10000) { $js = $js.Substring(0, 10000) + ' …(gekürzt)' }
      $teile.Add("# Benes private Konten — Auszug aus privat/stand.json (Euro; nenne bei Kontoständen immer das Datum)`n$js")
    } catch { $teile.Add('# Privater Stand: Datei nicht lesbar — sag das, statt Zahlen zu nennen.') }
  }
  $notiz = Lies (Join-Path $script:MadeleineDir 'notizen\beratung.md') 6000 80
  if ($notiz) { $teile.Add("# Deine eigenen Notizen (jüngste zuletzt)`n$notiz") }
  $coach = Join-Path $JohnDir 'coaching'
  if (Test-Path $coach) { Get-ChildItem $coach -Filter *.md -File | Sort-Object Name | ForEach-Object { $x = Lies $_.FullName 6000 60; if ($x) { $teile.Add("# Datei: john/coaching/$($_.Name) (gemeinsame Ablage mit John)`n$x") } } }
  $fin = Get-FinanzLive
  $teile.Add($(if ($fin) { "# Finanzlauf der Vishnu Artists GmbH — Live-Zahlen aus kpi.php (JSON, Euro)`n$fin" } else { '# Finanzlauf: gerade nicht erreichbar — sag das, wenn nach aktuellen GmbH-Zahlen gefragt wird.' }))
  return ($teile -join "`n`n")
}

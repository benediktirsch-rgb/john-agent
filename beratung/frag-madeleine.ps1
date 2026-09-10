<#
  frag-madeleine.ps1 — Johns Schwester gegenlesen lassen (10.09.2026)

  Madeleine ist Benedikts zweite Beraterin (Finanzen, Steuern, Organisation) und läuft über GPT
  (Codex CLI, ChatGPT-Konto). In diesem Repo hat sie eine andere Rolle als im Compass: sie ist
  die **Gegenprüferin der Architektur**. Sie fragt, was ich nicht frage — was kostet das im
  Betrieb, was passiert, wenn drei Monate niemand hinschaut, wer merkt es, wenn es kaputtgeht.

  Die Ehrlichkeitsregel aus der /duo-Skill gilt hier genauso: ich bin Partei. Deshalb schreibe
  ich meine eigene Antwort auf dieselbe Frage **vor** dem Lesen ihrer Antwort in eine Datei und
  ändere sie danach nicht mehr. Ins Protokoll kommt beides — ihre Antwort ungefiltert, und zu
  jedem Punkt, ob ich ihn übernehme und warum.

  Aufruf
    frag-madeleine.ps1 -Frage beratung\fragen\<datei>.md [-Thema "kurz"] [-Effort medium]

  Was sie NICHT bekommt: Zugangsdaten, Memory-Inhalte, personenbezogene Daten, Kontostände.
  Die Frage ist technisch und organisatorisch — sonst gehört sie nicht in dieses Skript.
#>
param(
  [Parameter(Mandatory = $true)][string]$Frage,
  [string]$Thema = '',
  [ValidateSet('low','medium','high','xhigh')][string]$Effort = 'medium',
  [int]$TimeoutSek = 600
)
$ErrorActionPreference = 'Stop'
$Hier      = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo      = Split-Path -Parent $Hier
$Roh       = Join-Path $Hier 'roh'
$Protokoll = Join-Path $Hier 'protokoll.md'
$Duo       = Join-Path $env:USERPROFILE '.claude\skills\duo\duo.ps1'
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

if (-not (Test-Path $Frage)) { Write-Host "Frage-Datei fehlt: $Frage" -ForegroundColor Red; return }
if (-not (Test-Path $Duo))   { Write-Host "duo.ps1 fehlt: $Duo" -ForegroundColor Red; return }
if (-not (Test-Path $Roh))   { New-Item -ItemType Directory -Force $Roh | Out-Null }
if (-not $Thema) { $Thema = [IO.Path]::GetFileNameWithoutExtension($Frage) }

$stempel = Get-Date -Format 'yyyyMMdd-HHmmss'
$prompt  = Join-Path $Roh "$stempel-$($Thema -replace '[^a-zA-Z0-9\-]','-').md"

# Ihre Rolle steht in der Prompt-Datei, nicht im Code: so kann man sie lesen und ändern,
# ohne das Skript anzufassen.
$kopf = @"
Du bist Madeleine — Benedikts zweite Beraterin. Sonst sind Finanzen, Steuern und Organisation
dein Feld; hier prüfst du eine technische Architektur gegen, und zwar aus deiner Perspektive:
Betriebskosten, Aufwand über die Zeit, Organisation, Risiko. Du bist keine Ja-Sagerin. Wenn dir
etwas zu aufwendig, zu fragil oder zu klug gebaut vorkommt, sag das mit Begründung.

Antworte knapp und direkt, ohne Vorgeplänkel: höchstens fünf Punkte, jeder mit einem Satz
Begründung, und am Ende ein Satz, was du an Benedikts Stelle zuerst tun würdest. Deutsch, Du-Form.
Was du nicht beurteilen kannst, sagst du — du erfindest nichts.

Die Architektur liegt im Ordner $Repo (lies dort ARCHITEKTUR.md, docs/protokoll.md, docs/adr/).

--- Die Frage ---

"@
$text = $kopf + ([IO.File]::ReadAllText($Frage, [Text.Encoding]::UTF8))
[IO.File]::WriteAllText($prompt, $text, $Utf8NoBom)

Write-Host "Frage an Madeleine (GPT über Codex), Thema: $Thema" -ForegroundColor Cyan
Write-Host "  Prompt: $prompt" -ForegroundColor DarkGray
$t0 = Get-Date
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Duo -PromptDatei $prompt -Cwd $Repo -Effort $Effort
$dauer = [int]((Get-Date) - $t0).TotalSeconds

$antwortDatei = "$prompt.antwort.md"
if (-not (Test-Path $antwortDatei)) {
  Write-Host "Keine Antwortdatei — Codex angemeldet? (codex login kann nur Bene)" -ForegroundColor Yellow
  return
}
$antwort = [IO.File]::ReadAllText($antwortDatei, [Text.Encoding]::UTF8).Trim()

# Protokoll: append-only. Ihre Antwort steht ungefiltert drin; was ich daraus mache, trage ich
# von Hand darunter ein — das ist Arbeit und soll Arbeit bleiben.
if (-not (Test-Path $Protokoll)) {
  $anfang = @"
# Beratungsprotokoll — Claude und Madeleine

Jede Beratung zur Architektur: die Frage, ihre Antwort **ungefiltert**, und darunter, was
übernommen wurde und was nicht — mit Begründung. Append-only; hier wird nichts umgeschrieben.

"@
  [IO.File]::WriteAllText($Protokoll, $anfang, $Utf8NoBom)
}
$eintrag = @"

## $(Get-Date -Format 'dd.MM.yyyy HH:mm') — $Thema

**Gefragt** (`$([IO.Path]::GetFileName($Frage))`, Antwort nach $dauer s):

$([IO.File]::ReadAllText($Frage, [Text.Encoding]::UTF8).Trim())

**Madeleine sagt:**

$antwort

**Übernommen / nicht übernommen:** _(Claude trägt hier ein, bevor der nächste Commit geht)_

"@
Add-Content -Path $Protokoll -Value $eintrag -Encoding UTF8
Write-Host ''
Write-Host "Protokolliert: $Protokoll ($dauer s)" -ForegroundColor Green
Write-Host 'Jetzt fehlt noch der Absatz „Übernommen / nicht übernommen" — der ist der eigentliche Punkt.' -ForegroundColor DarkGray

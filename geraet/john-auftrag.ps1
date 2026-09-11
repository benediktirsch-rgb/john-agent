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
    raum    einen Zug im Gesprächsraum denken (-Raum <id> -An john|madeleine|beide), Text bleibt lokal
    spiegel Johns Compass-Stapel in die Rezeption spiegeln und OKs von anderen Geraeten an den
            Cockpit-Server nachreichen (kein Claude, dauert Sekunden)

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
  [ValidateSet('takt','hub','frage','stapel','spiegel','raum')][string]$Art = 'takt',
  [string]$Raum = '',
  [ValidateSet('john','madeleine','beide')][string]$An = 'john',
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
$Hub      = ([string](LiesEnv 'JOHN_HUB_URL' 'https://hotel-vaikuntha.de/john')).TrimEnd('/')
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

# ── Modelle: Claude (John) und Codex (Madeleine) stehen in john-ki.ps1 ─────────────────────
. (Join-Path $Hier 'john-ki.ps1')

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
    # Ueber die Lage OHNE Uhrzeit hashen (11.09.2026): die Zeile „## Heute" traegt HH:mm — mit ihr
    # war jede Lage neu, und die Bremse griff nie (07:00-09:00 fuenf Aufrufe fuer „nichts Neues").
    $fuerHash = [regex]::Replace($lage, '(?m)^(## Heute\r?\n.*?\d{4})\s+\d{1,2}:\d{2}\s*$', '$1')
    $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($fuerHash))) -replace '-','').Substring(0, 16)
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

# ── Spiegel: Johns Kachel auf allen Geraeten (11.09.2026) ─────────────────────────────────
# Die Kachel im Compass holt ihren Stapel vom Cockpit-Server. Am Handy gibt es den nicht —
# dort war sie leer. Dieser Lauf schiebt den Stapel in die Rezeption und holt zurueck, was
# auf anderen Geraeten abgeraeumt wurde. Die Datei john-stapel.json wird dabei NUR GELESEN
# (ADR 0004): Rueckwege gehen ueber den Endpunkt des Servers, der seine Datei selbst schreibt.
function IsoZeit([string]$s) {
  if (-not $s) { return $null }
  try { return (Get-Date $s).ToString('yyyy-MM-ddTHH:mm:sszzz') } catch { return $null }
}
function Neuer([string]$a, [string]$b) {
  if (-not $b) { return $true }; if (-not $a) { return $false }
  try { return ([DateTimeOffset]::Parse($a) -gt [DateTimeOffset]::Parse($b)) } catch { return $false }
}
function SpiegelLauf {
  if (-not $HubToken) { Log 'Keine Rezeption angebunden.'; return @{ ok = $false } }
  $datei = Join-Path $Compass 'john-stapel.json'
  $punkte = @(); $stand = @{}; $um = $null
  if (Test-Path $datei) {
    $d = [IO.File]::ReadAllText($datei, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($d.letzte -and $d.letzte.punkte) { $punkte = @($d.letzte.punkte) }
    foreach ($e in @($d.stand.PSObject.Properties)) {
      if (-not $e) { continue }
      $stand[$e.Name] = @{ status = [string]$e.Value.status; ts = (IsoZeit ([string]$e.Value.ts)); bis = [string]$e.Value.bis
                           aktion = [string]$e.Value.aktion; titel = [string]$e.Value.titel }
    }
    # Sortierzeit = letzte.stand (wann John den Stapel sortiert hat). NICHT geschrieben: das
    # aendert sich bei jedem OK, und dann hielte die Kachel sich faelschlich fuer frisch sortiert.
    $um = IsoZeit ([string]$d.letzte.stand); if (-not $um) { $um = IsoZeit ([string]$d.geschrieben) }
  }
  $r = HubRuf 'spiegel' @{ punkte = $punkte; stand = $stand; stand_um = $um; quelle = $Geraet }
  if (-not $r -or -not $r.ok) { Log 'Spiegel: Rezeption hat nicht angenommen.'; return @{ ok = $false } }

  # Nachreichen: was die Rezeption juenger kennt als die Datei, geht an den Cockpit-Server.
  # Nur bei ANDEREM Status — gleicher Status mit anderem Zeitstempel ist kein Auftrag, sonst
  # schoben sich Server und Rezeption dieselbe Zeile ewig hin und her.
  $nach = 0; $fehl = 0
  foreach ($e in @($r.stand.PSObject.Properties)) {
    if (-not $e) { continue }
    $h = $e.Value; $f = $stand[$e.Name]
    $fStatus = if ($f) { $f.status } else { 'offen' }
    if ([string]$h.status -eq $fStatus) { continue }
    if ($f -and -not (Neuer ([string]$h.ts) ([string]$f.ts))) { continue }
    try {
      $body = @{ key = $e.Name; status = [string]$h.status; aktion = [string]$h.aktion; titel = [string]$h.titel; stunden = 24; auftrag = '' } | ConvertTo-Json -Compress
      $antwort = Invoke-RestMethod -Uri 'http://localhost:8787/api/john/stapel/stand' -Method Post -ContentType 'application/json; charset=utf-8' `
                   -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 20
      if ($antwort.ok) { $nach++ } else { $fehl++ }
    } catch { $fehl++ }
  }
  if ($nach -or $fehl) { Log "Spiegel: $nach Stand-Eintrag/Eintraege an den Cockpit-Server nachgereicht$(if ($fehl) { ", $fehl gescheitert (Server belegt?)" })." }
  return @{ ok = ($fehl -eq 0); punkte = $punkte.Count; nach = $nach }
}

# ── Gesprächsraum (11.09.2026) ───────────────────────────────────────────────────────────
# Ein Raum ist eine Datei: C:\dev\john\coaching\raum\<raum>.jsonl. Zeile 1 = {meta, thema,
# erstellt}, danach je Zug {zug, wer, zeit, text, weitergeben}. Der Text bleibt hier; die
# Rezeption bekommt nur das Signal (Art raum, ohne Text — sie weist Text sogar ab).
# John sieht, was Madeleine GESAGT hat, nicht, was sie WEISS — und umgekehrt: jeder Zug bekommt
# Persona und Wissen des Sprechenden plus die Züge des Raums mit weitergeben != false.
$script:RaumOrdner = Join-Path $JohnDir 'coaching\raum'
$script:LaufOrdner = Join-Path $Hier '.auftraege'

function RaumDatei([string]$id) { return (Join-Path $script:RaumOrdner "$id.jsonl") }
function RaumLesen([string]$id) {
  $f = RaumDatei $id
  $thema = ''; $zuege = New-Object System.Collections.Generic.List[object]
  if (Test-Path $f) {
    foreach ($z in [IO.File]::ReadAllLines($f, [Text.Encoding]::UTF8)) {
      if (-not $z.Trim()) { continue }
      try { $o = $z | ConvertFrom-Json } catch { continue }
      if ($o.meta) { $thema = [string]$o.thema; continue }
      $zuege.Add($o)
    }
  }
  # .ToArray() statt @($zuege): @() einer generischen Liste im Hashtable-Literal wirft in PS 5.1
  # „Die Argumenttypen stimmen nicht überein“.
  return @{ thema = $thema; zuege = $zuege.ToArray() }
}
# Anhängen unter einem benannten Mutex: die Tür des Workers schreibt Benes Züge in dieselbe Datei.
# Ohne Sperre könnten beide dieselbe Zugnummer vergeben. Der Name ist mit john-worker.ps1 abgestimmt.
function RaumAnhaengen([string]$id, [string]$wer, [string]$text) {
  $m = New-Object Threading.Mutex($false, "Local\john-raum-$id")
  $hat = $false
  try {
    try { $hat = $m.WaitOne(5000) } catch [Threading.AbandonedMutexException] { $hat = $true }
    $r = RaumLesen $id
    $max = 0; foreach ($z in $r.zuege) { if ([int]$z.zug -gt $max) { $max = [int]$z.zug } }
    $n = $max + 1
    $zeile = (@{ zug = $n; wer = $wer; zeit = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz'); text = $text; weitergeben = $true } | ConvertTo-Json -Compress -Depth 3)
    [IO.File]::AppendAllText((RaumDatei $id), $zeile + "`n", $Utf8NoBom)
    return $n
  } finally { if ($hat) { $m.ReleaseMutex() }; $m.Dispose() }
}
function LaufMerken([string]$id, $info) {
  if (-not (Test-Path $script:LaufOrdner)) { New-Item -ItemType Directory -Force $script:LaufOrdner | Out-Null }
  [IO.File]::WriteAllText((Join-Path $script:LaufOrdner "$id.lauf"), ($info | ConvertTo-Json -Compress), $Utf8NoBom)
}
function LaufLoeschen([string]$id) { Remove-Item (Join-Path $script:LaufOrdner "$id.lauf") -Force -ErrorAction SilentlyContinue }

$script:RaumNamen = @{ john = 'John'; madeleine = 'Madeleine'; bene = 'Bene'; system = 'Hinweis' }
function RaumAnweisung([string]$wer) {
  $ich = $script:RaumNamen[$wer]; $du = if ($wer -eq 'john') { 'Madeleine' } else { 'John' }
  $extra = if ($wer -eq 'madeleine') {
    "`nTechnischer Rahmen: Du läufst über die Codex CLI, aber NICHT als Programmierwerkzeug. Es gibt keine Dateien zu lesen und nichts auszuführen; alles, was du weißt, steht in diesem Text. Willst du etwas festhalten, schreib als letzte Zeile NOTIZ: <ein Satz>."
  } else { '' }
  return @"
--- Gesprächsraum im Flow Compass ---
Anwesend sind Benedikt (Bene), John (sein Coach) und Madeleine (Finanzen, Steuern, Organisation). Du bist $ich.
Unten steht der Verlauf dieses Raums. Antworte auf den letzten Beitrag: zwei bis sechs Sätze, Deutsch, Du-Form zu Bene.
Stimmst du $du zu oder widersprichst ihm/ihr, sag es direkt und mit Beleg. Nichts erfinden: fehlt eine Zahl, sag es.
Nur deine Antwort, ohne Namen davor. Nichts versenden, buchen oder kündigen — vorbereiten ja.$extra
"@
}
function RaumVerlauf($r) {
  $sb = New-Object Text.StringBuilder
  if ($r.thema) { [void]$sb.AppendLine("Thema: $($r.thema)"); [void]$sb.AppendLine() }
  $sichtbar = @($r.zuege | Where-Object { $_.weitergeben -ne $false -and $_.wer -ne 'system' })
  if ($sichtbar.Count -gt 30) { $sichtbar = $sichtbar[($sichtbar.Count - 30)..($sichtbar.Count - 1)] }
  foreach ($z in $sichtbar) {
    $zeit = ''; try { $zeit = ([datetime]::Parse([string]$z.zeit)).ToString('dd.MM. HH:mm') } catch { }
    [void]$sb.AppendLine("$($script:RaumNamen[[string]$z.wer]) ($zeit):"); [void]$sb.AppendLine([string]$z.text); [void]$sb.AppendLine()
  }
  return $sb.ToString()
}
# Madeleines NOTIZ-Zeile: aus dem Raum heraus, in ihre Notizen hinein (wie der Server es macht).
function NotizAbtrennen([string]$text) {
  $zeilen = @($text.TrimEnd() -split "`r?`n")
  if ($zeilen.Count -gt 1 -and $zeilen[-1] -match '^\s*NOTIZ:\s*(.+)$') {
    $satz = $Matches[1].Trim()
    try { [IO.File]::AppendAllText((Join-Path $script:MadeleineDir 'notizen\beratung.md'), "`n- $(Get-Date -Format 'dd.MM.yyyy HH:mm') (Gesprächsraum): $satz", $Utf8NoBom) } catch { }
    return (($zeilen[0..($zeilen.Count - 2)]) -join "`n").TrimEnd()
  }
  return $text.Trim()
}

function RaumLauf {
  if (-not $Raum -or $Raum -notmatch '^[a-z0-9-]{1,40}$') { throw 'Raum-Kennung fehlt oder ist ungültig' }
  if (-not (Test-Path (RaumDatei $Raum))) { throw "Raum $Raum gibt es nicht" }
  $sprecher = if ($An -eq 'beide') { @('john', 'madeleine') } else { @($An) }
  foreach ($wer in $sprecher) {
    $r = RaumLesen $Raum
    $zug = 1; foreach ($z in $r.zuege) { if ([int]$z.zug -ge $zug) { $zug = [int]$z.zug + 1 } }
    # Signal an die Rezeption: wer denkt, in welchem Raum, welcher Zug. Kein Text.
    $jobId = $null
    if ($HubToken) {
      $a = HubRuf 'auftrag' @{ art = 'raum'; raum = $Raum; zug = $zug; an = $wer; thema = $r.thema; wer = $Geraet }
      if ($a -and $a.ok) {
        $jobId = [string]$a.id
        $nm = HubRuf 'nimm' @{ id = $jobId; geraet = $Geraet }
        if (-not $nm -or -not $nm.ok) { Log "Raum $Raum : Zug $zug nicht beansprucht (gestoppt oder vergeben)."; return @{ ok = $false } }
      }
    }
    LaufMerken $Raum @{ jobId = $jobId; an = $wer; pid = $PID; seit = (Get-Date).ToString('o') }
    try {
      $verlauf = RaumVerlauf $r
      if ($wer -eq 'john') {
        $sys = (Lies (Join-Path $JohnDir 'CLAUDE.md') 14000) + "`n`n--- Deine Lage ---`n" + (LageText)
        $antwort = Rufe-Claude $sys ((RaumAnweisung 'john') + "`n`n" + $verlauf)
      } else {
        $antwort = Rufe-Codex ((MadeleineSystem) + "`n`n" + (RaumAnweisung 'madeleine') + "`n`n" + $verlauf) $TimeoutSek
        $antwort = NotizAbtrennen $antwort
      }
      if (-not $antwort.Trim()) { throw 'leere Antwort' }
      $n = RaumAnhaengen $Raum $wer $antwort
      if ($jobId) { HubRuf 'ergebnis' @{ id = $jobId; ok = $true; notiz = "Zug $n liegt am Gerät ($($antwort.Length) Zeichen)" } | Out-Null }
      Log "Raum $Raum : $($script:RaumNamen[$wer]) hat Zug $n geschrieben ($($antwort.Length) Zeichen)."
    } catch {
      $msg = $_.Exception.Message
      RaumAnhaengen $Raum 'system' ("$($script:RaumNamen[$wer]) konnte nicht antworten: $msg") | Out-Null
      if ($jobId) { HubRuf 'ergebnis' @{ id = $jobId; ok = $false; notiz = 'gescheitert' } | Out-Null }
      Log "Raum $Raum : $($script:RaumNamen[$wer]) gescheitert: $msg"
      return @{ ok = $false }
    } finally { LaufLoeschen $Raum }
  }
  return @{ ok = $true }
}

# ── Los ──────────────────────────────────────────────────────────────────────────────────
try {
  switch ($Art) {
    'takt'   { $r = TaktLauf }
    'hub'    { $r = HubLauf }
    'stapel' { $r = TaktLauf }
    'spiegel' { $r = SpiegelLauf }
    'raum'    { $r = RaumLauf }
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
  Log "Abbruch: $($_.Exception.Message) (Zeile $($_.InvocationInfo.ScriptLineNumber) in $([IO.Path]::GetFileName($_.InvocationInfo.ScriptName)))"
  if ($HubToken) { HubRuf 'log' @{ art = 'fehler'; geraet = $Geraet; text = "Auftrag $Art : $($_.Exception.Message)" } | Out-Null }
  exit 1
}

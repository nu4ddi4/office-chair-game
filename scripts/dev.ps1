<#
Quick local runs for development on Windows (no export templates needed).

  .\scripts\dev.ps1 play            Run the game straight from the source tree.
  .\scripts\dev.ps1 build [-Run]    Build chaos-dev\OfficeChairChaos.exe + .pck and optionally start it.

Godot 4.7.2 is taken from $env:CHAOS_GODOT, from PATH, or from .tools\godot in this
repository. If none is found the script offers to download the official build from
github.com/godotengine (about 82 MB) and checks its SHA-512 before using it.
The dev build is the Godot runtime next to an exported game pack; Godot runs the
.pck that shares its file name. Release builds still use scripts\build-game.py.
#>
param(
    [Parameter(Position = 0)][ValidateSet('play', 'build')][string]$Mode = 'play',
    [switch]$Run,
    [switch]$Yes
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Version = '4.7.2-stable'
$ZipName = "Godot_v$Version`_win64.exe.zip"
$ExeName = "Godot_v$Version`_win64.exe"
$Release = "https://github.com/godotengine/godot/releases/download/$Version"
$Tools = Join-Path $Root '.tools\godot'

function Test-Godot([string]$Path) {
    if (-not $Path -or -not (Test-Path $Path)) { return $false }
    $reported = & $Path --version 2>$null | Select-Object -First 1
    return "$reported".StartsWith('4.7.2.stable')
}

function Find-Godot {
    if (Test-Godot $env:CHAOS_GODOT) { return $env:CHAOS_GODOT }
    foreach ($name in @('godot', 'godot4')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command -and (Test-Godot $command.Source)) { return $command.Source }
    }
    $local = Join-Path $Tools $ExeName
    if (Test-Godot $local) { return $local }
    return $null
}

function Get-Godot {
    $found = Find-Godot
    if ($found) { return $found }
    Write-Host "Godot $Version was not found (CHAOS_GODOT, PATH or .tools\godot)."
    if (-not $Yes) {
        $answer = Read-Host "Download $ZipName (about 82 MB) from github.com/godotengine into .tools\godot? [y/N]"
        if ($answer -notmatch '^(y|yes)$') { throw 'Godot is required. Set CHAOS_GODOT to an existing Godot 4.7.2 executable.' }
    }
    New-Item -ItemType Directory -Force $Tools | Out-Null
    $zip = Join-Path $Tools $ZipName
    $sums = Join-Path $Tools 'SHA512-SUMS.txt'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest "$Release/$ZipName" -OutFile $zip -UseBasicParsing
    Invoke-WebRequest "$Release/SHA512-SUMS.txt" -OutFile $sums -UseBasicParsing
    $expected = (Get-Content $sums | Where-Object { $_ -match [regex]::Escape($ZipName) + '$' } | Select-Object -First 1) -split '\s+' | Select-Object -First 1
    $actual = (Get-FileHash $zip -Algorithm SHA512).Hash
    if (-not $expected -or $actual -ne $expected.ToUpper()) {
        Remove-Item $zip -Force
        throw "Checksum mismatch for $ZipName; the download was removed."
    }
    Expand-Archive $zip $Tools -Force
    Remove-Item $zip -Force
    $local = Join-Path $Tools $ExeName
    if (-not (Test-Godot $local)) { throw 'The downloaded Godot did not report version 4.7.2.' }
    return $local
}

function Invoke-Import([string]$Godot) {
    Write-Host 'Importing assets (fast when nothing changed)...'
    $import = Start-Process -FilePath $Godot -ArgumentList @('--headless', '--path', "`"$(Join-Path $Root 'godot')`"", '--editor', '--import', '--quit') -NoNewWindow -Wait -PassThru
    if ($import.ExitCode -ne 0) { throw "Godot import failed with exit code $($import.ExitCode)." }
    $texture = Get-ChildItem (Join-Path $Root 'godot\assets\models') -Filter 'Office_Chaos_*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $texture) { Write-Warning 'The detailed office textures are missing. Run "git lfs pull" so the map GLBs are real files.' }
}

$godot = Get-Godot
Invoke-Import $godot

if ($Mode -eq 'play') {
    Write-Host 'Starting the game from source...'
    Start-Process -FilePath $godot -ArgumentList @('--path', "`"$(Join-Path $Root 'godot')`"")
    return
}

$dist = Join-Path $Root 'chaos-dev'
New-Item -ItemType Directory -Force $dist | Out-Null
$pack = Join-Path $dist 'OfficeChairChaos.pck'
Write-Host 'Exporting the game pack...'
$export = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', "`"$(Join-Path $Root 'godot')`"", '--export-pack', '"Windows Desktop"', "`"$pack`"") -NoNewWindow -Wait -PassThru
if ($export.ExitCode -ne 0 -or -not (Test-Path $pack)) { throw "Exporting the game pack failed (exit code $($export.ExitCode))." }
# The Godot runtime loads the .pck that shares its name; the console twin shows logs.
Copy-Item $godot (Join-Path $dist 'OfficeChairChaos.exe') -Force
$console = $godot -replace '\.exe$', '_console.exe'
if (Test-Path $console) {
    Copy-Item $console (Join-Path $dist 'OfficeChairChaos.console.exe') -Force
}
$size = [math]::Round((Get-Item $pack).Length / 1MB)
Write-Host "Dev build ready: $dist\OfficeChairChaos.exe (pack $size MB)"
if ($Run) { Start-Process -FilePath (Join-Path $dist 'OfficeChairChaos.exe') -WorkingDirectory $dist }

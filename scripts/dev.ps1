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
    if (Test-Godot $env:TINY_OFFICE_GODOT) { return $env:TINY_OFFICE_GODOT }
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
    Write-Host "Godot $Version was not found (TINY_OFFICE_GODOT, PATH or .tools\godot)."
    if (-not $Yes) {
        $answer = Read-Host "Download $ZipName (about 82 MB) from github.com/godotengine into .tools\godot? [y/N]"
        if ($answer -notmatch '^(y|yes)$') { throw 'Godot is required. Set TINY_OFFICE_GODOT to an existing Godot 4.7.2 executable.' }
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

$godot = Get-Godot
$project = Join-Path $Root 'prototype\tiny-office'
$console = $godot -replace '\.exe$', '_console.exe'
$headless = $godot
if (Test-Path -LiteralPath $console) { $headless = $console }

if ($Mode -eq 'play') {
    $generated = Join-Path $project 'generated'
    New-Item -ItemType Directory -Force $generated | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'godot\assets\fonts\NotoSansKR.ttf') -Destination $generated -Force
    & $headless --headless --path $project --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot import failed with exit code $LASTEXITCODE." }
    Start-Process -FilePath $godot -ArgumentList @('--path', "`"$project`"")
    return
}

& python (Join-Path $project 'build.py') --godot $headless --target windows
if ($LASTEXITCODE -ne 0) { throw "Client build failed with exit code $LASTEXITCODE." }
$dist = Join-Path $project 'dist'
if ($Run) { Start-Process -FilePath (Join-Path $dist 'TinyOffice.exe') -WorkingDirectory $dist }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $root 'godot/chaos/resources/update_helper.ps1') -Library
$build = Join-Path $root 'chaos-dist'
$setup = Join-Path $build 'OfficeChairChaos-Setup.exe'
$install = Join-Path $env:RUNNER_TEMP ('office-chair-'+[Guid]::NewGuid().ToString('N')+'\Installed Game')
$data = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'OfficeChairChaos'
$updates = Get-OfficeUpdateRoot
$null = [IO.Directory]::CreateDirectory($updates)
$sentinel = Join-Path $data 'installer-save-preservation.txt'
[IO.File]::WriteAllText($sentinel,'preserve-user-progress')
$checks = 0
function Assert-Check([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Stop-TestGame([int]$ProcessId) {
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -ne $process -and $process.Path -eq (Join-Path $install 'OfficeChairChaos.exe')) { Stop-Process -Id $ProcessId -Force; $process.WaitForExit() }
}
function New-Request([string]$Name, [string]$Version) {
    $copy = Join-Path $updates $Name
    Copy-Item -LiteralPath $setup -Destination $copy -Force
    [pscustomobject]@{product='OfficeChairChaos';version=$Version;installer=$copy;sha256=(Get-OfficeHash $copy);install_dir=$install;parent_pid=2147483000;test_timeout=8;ready_file=(Join-Path $updates ('helper-ready-'+$Name+'.json'))}
}
$processIds = @()
try {
    $installation = Start-Process -FilePath $setup -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/NOICONS',('/DIR="'+$install+'"')) -Wait -PassThru
    Assert-Check ($installation.ExitCode -eq 0) 'First user installation failed'
    Assert-Check (Test-Path -LiteralPath (Join-Path $install 'OfficeChairChaos.exe')) 'Installed EXE is missing'
    $stamp = Get-Content -LiteralPath (Join-Path $install 'office-chair.install.json') -Raw | ConvertFrom-Json
    Assert-Check ($stamp.product -eq 'OfficeChairChaos' -and $stamp.app_id -eq 'OfficeChairChaos') 'Product stamp mismatch'
    $notices = Get-Content -LiteralPath (Join-Path $install 'LICENSES.txt') -Raw -Encoding UTF8
    Assert-Check ($notices.Contains('CMHT Oculus') -and $notices.Contains('SIL OPEN FONT LICENSE') -and $notices.Contains('Godot Engine')) 'Consolidated license notices are incomplete'
    $request = New-Request 'setup-success.exe' $stamp.version
    $success = Invoke-OfficeUpdate $request -HeadlessTest
    Assert-Check $success.passed ('Update failed: '+($success | ConvertTo-Json -Compress))
    Assert-Check (Test-Path -LiteralPath $request.ready_file) 'Helper did not confirm readiness'
    $processIds += $success.process_id
    Stop-TestGame $success.process_id
    Assert-Check ((Get-Content -LiteralPath $sentinel -Raw) -eq 'preserve-user-progress') 'Update touched user progress'
    $originalLicense = [IO.File]::ReadAllText((Join-Path $install 'LICENSES.txt')) + "`nrollback-marker"
    [IO.File]::WriteAllText((Join-Path $install 'LICENSES.txt'),$originalLicense,[Text.UTF8Encoding]::new($false))
    $oldHash = Get-OfficeHash (Join-Path $install 'OfficeChairChaos.exe')
    $request = New-Request 'setup-failed-health.exe' '999.0.0'
    $failure = Invoke-OfficeUpdate $request -HeadlessTest
    Assert-Check (-not $failure.passed -and $failure.rollback) 'A mismatched health version did not roll back'
    $processIds += $failure.process_id
    if ($failure.process_id) { Stop-TestGame $failure.process_id }
    Assert-Check ((Get-OfficeHash (Join-Path $install 'OfficeChairChaos.exe')) -eq $oldHash) 'Rollback did not restore the EXE'
    Assert-Check ([IO.File]::ReadAllText((Join-Path $install 'LICENSES.txt')) -eq $originalLicense) 'Rollback did not restore original install files'
    Assert-Check ((Get-Content -LiteralPath $sentinel -Raw) -eq 'preserve-user-progress') 'Rollback touched user progress'
    $request = New-Request 'setup-bad-checksum.exe' $stamp.version
    $request.sha256 = '0'*64
    $bad = Invoke-OfficeUpdate $request -HeadlessTest
    Assert-Check (-not $bad.passed -and -not $bad.rollback) 'A corrupt installer was not rejected before installation'
    $processIds += $bad.process_id
    if ($bad.process_id) { Stop-TestGame $bad.process_id }
    Assert-Check ((Get-OfficeHash (Join-Path $install 'OfficeChairChaos.exe')) -eq $oldHash) 'Corrupt installer changed the installed game'
    $uninstall = Start-Process -FilePath (Join-Path $install 'unins000.exe') -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -Wait -PassThru
    Assert-Check ($uninstall.ExitCode -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $install 'OfficeChairChaos.exe'))) 'Uninstall failed'
    Assert-Check ((Get-Content -LiteralPath $sentinel -Raw) -eq 'preserve-user-progress') 'Uninstall deleted user progress'
    Write-Output ('CHAOS_INSTALLER '+(@{passed=$true;checks=$checks}|ConvertTo-Json -Compress))
} finally {
    foreach ($processId in $processIds) { if ($processId) { Stop-TestGame $processId } }
}

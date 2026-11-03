param([string]$RequestPath, [switch]$Library)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($PSVersionTable.PSEdition -eq 'Desktop') { $env:PSModulePath = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/Modules' }

function Get-OfficeUpdateRoot {
    Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'OfficeChairChaos\updates'
}
function Assert-OfficePath([string]$Path) {
    if ($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path -match '[\x00-\x1f"<>|]' -or $Path.Substring(2).Contains(':')) { throw 'Invalid local path' }
    $full = [IO.Path]::GetFullPath($Path)
    $cursor = $full
    while ($cursor.Length -gt 3) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked update paths are not allowed' }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    $full
}
function Get-OfficeHash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Write-OfficeStatus([string]$State, [string]$Version, [string]$Message) {
    $root = Get-OfficeUpdateRoot
    $null = [IO.Directory]::CreateDirectory($root)
    $data = @{ state=$State;version=$Version;message=$Message } | ConvertTo-Json -Compress
    [IO.File]::WriteAllText((Join-Path $root 'status.tmp'),$data,[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath (Join-Path $root 'status.tmp') -Destination (Join-Path $root 'status.json') -Force
}
function Test-OfficeParent([int]$ProcessId) {
    $null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
}
function Invoke-OfficeUpdate($Request, [switch]$HeadlessTest) {
    $backup = $null; $newProcess = $null; $parentGone = $false; $directory = $null
    $files = @('OfficeChairChaos.exe','LICENSES.txt','office-chair.install.json','unins000.exe','unins000.dat','unins000.msg')
    $inventory = @{}
    $targetVersion = ''
    try {
        if ($Request.product -ne 'OfficeChairChaos' -or $Request.version -notmatch '^\d+\.\d+\.\d+$' -or $Request.sha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'Invalid update identity' }
        $targetVersion = [string]$Request.version
        $root = Assert-OfficePath (Get-OfficeUpdateRoot)
        $installer = Assert-OfficePath ([string]$Request.installer)
        if (-not $installer.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Installer is outside the update directory' }
        $directory = Assert-OfficePath ([string]$Request.install_dir)
        $stampPath = Join-Path $directory 'office-chair.install.json'
        $stamp = Get-Content -LiteralPath $stampPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($stamp.product -ne 'OfficeChairChaos' -or $stamp.app_id -ne 'OfficeChairChaos') { throw 'Install identity mismatch' }
        if ([int]$Request.parent_pid -le 0) { throw 'Invalid parent process' }
        if ((Get-OfficeHash $installer) -ne $Request.sha256.ToLowerInvariant()) { throw 'Installer checksum mismatch' }
        if ($Request.PSObject.Properties['ready_file']) {
            $ready = Assert-OfficePath ([string]$Request.ready_file)
            if (-not $ready.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($ready) -notlike 'helper-ready-*.json') { throw 'Invalid helper readiness path' }
            [IO.File]::WriteAllText($ready+'.tmp','{"product":"OfficeChairChaos"}',[Text.UTF8Encoding]::new($false))
            Move-Item -LiteralPath ($ready+'.tmp') -Destination $ready -Force
        }
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while (Test-OfficeParent ([int]$Request.parent_pid)) {
            if ([DateTime]::UtcNow -gt $deadline) { throw 'Game did not exit; installation cancelled' }
            Start-Sleep -Milliseconds 100
        }
        $parentGone = $true
        if ((Get-OfficeHash $installer) -ne $Request.sha256.ToLowerInvariant()) { throw 'Installer checksum mismatch' }
        $backup = Join-Path $root ('rollback-'+[Guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($backup)
        foreach ($name in $files) {
            $source = Join-Path $directory $name
            if (Test-Path -LiteralPath $source -PathType Leaf) {
                $source = Assert-OfficePath $source
                Copy-Item -LiteralPath $source -Destination (Join-Path $backup $name)
                $originalHash = Get-OfficeHash $source
                if ((Get-OfficeHash (Join-Path $backup $name)) -ne $originalHash) { throw 'Backup verification failed' }
                $inventory[$name] = $originalHash
            }
        }
        if (-not $inventory.ContainsKey('OfficeChairChaos.exe')) { throw 'Installed game is missing' }
        Write-OfficeStatus 'installing' $targetVersion ''
        $setupArgs = @('/VERYSILENT','/SUPPRESSMSGBOXES','/SP-','/NORESTART','/CLOSEAPPLICATIONS',('/DIR="'+$directory+'"'))
        $setup = Start-Process -FilePath $installer -ArgumentList $setupArgs -Wait -PassThru
        if ($setup.ExitCode -ne 0) { throw ('Installer failed: '+$setup.ExitCode) }
        $health = Join-Path $root ('health-'+[Guid]::NewGuid().ToString('N')+'.json')
        $startArgs = @('--','--update-health-file',('"'+$health+'"'))
        if ($HeadlessTest) { $startArgs = @('--headless','--audio-driver','Dummy','--fixed-fps','120','--','--chaos-test','--update-health-file',('"'+$health+'"')) }
        $newProcess = Start-Process -FilePath (Join-Path $directory 'OfficeChairChaos.exe') -ArgumentList $startArgs -PassThru
        $seconds = 60
        if ($HeadlessTest -and $Request.PSObject.Properties['test_timeout']) { $seconds = [Math]::Max(2,[Math]::Min(10,[int]$Request.test_timeout)) }
        $deadline = [DateTime]::UtcNow.AddSeconds($seconds)
        $healthy = $false
        while ([DateTime]::UtcNow -lt $deadline) {
            if (Test-Path -LiteralPath $health) {
                $report = Get-Content -LiteralPath $health -Raw -Encoding UTF8 | ConvertFrom-Json
                $healthy = $report.product -eq 'OfficeChairChaos' -and $report.version -eq $targetVersion
                break
            }
            if ($newProcess.HasExited) { break }
            Start-Sleep -Milliseconds 100
        }
        if (-not $healthy) { throw 'New game health check failed' }
        Write-OfficeStatus 'success' $targetVersion ''
        Remove-Item -LiteralPath $health -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $backup -Recurse -Force
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{ passed=$true;rollback=$false;process_id=$newProcess.Id;version=$targetVersion }
    } catch {
        $reason = $_.Exception.Message
        if ($null -ne $newProcess -and -not $newProcess.HasExited) { Stop-Process -Id $newProcess.Id -Force; $newProcess.WaitForExit() }
        $restored = $false
        if ($null -ne $backup -and $inventory.Count -gt 0) {
            foreach ($name in $inventory.Keys) {
                Copy-Item -LiteralPath (Join-Path $backup $name) -Destination (Join-Path $directory $name) -Force
                if ((Get-OfficeHash (Join-Path $directory $name)) -ne $inventory[$name]) { throw 'Rollback verification failed' }
            }
            $restored = $true
            $restoredStamp = Get-Content -LiteralPath (Join-Path $directory 'office-chair.install.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OfficeChairChaos_is1'
            if (Test-Path $key) { Set-ItemProperty -Path $key -Name DisplayVersion -Value ([string]$restoredStamp.version) -ErrorAction SilentlyContinue }
        }
        Write-OfficeStatus $(if ($restored) { 'rollback' } else { 'failed' }) $targetVersion $reason
        $restartId = 0
        if ($parentGone -and $null -ne $directory -and (Test-Path -LiteralPath (Join-Path $directory 'OfficeChairChaos.exe'))) {
            $restartArgs = @()
            if ($HeadlessTest) { $restartArgs=@('--headless','--audio-driver','Dummy','--fixed-fps','120','--','--chaos-test') }
            $old = if ($restartArgs.Count) { Start-Process -FilePath (Join-Path $directory 'OfficeChairChaos.exe') -ArgumentList $restartArgs -PassThru } else { Start-Process -FilePath (Join-Path $directory 'OfficeChairChaos.exe') -PassThru }
            $restartId = $old.Id
        }
        return [pscustomobject]@{ passed=$false;rollback=$restored;process_id=$restartId;message=$reason }
    }
}
if (-not $Library) {
    $path = Assert-OfficePath $RequestPath
    $root = (Assert-OfficePath (Get-OfficeUpdateRoot)).TrimEnd('\')+'\'
    if (-not $path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) { throw 'Request is outside the update directory' }
    $request = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $result = Invoke-OfficeUpdate $request
    if (-not $result.passed) { exit 1 }
}

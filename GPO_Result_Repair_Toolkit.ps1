[CmdletBinding()]
param(
    [ValidateSet('Computer','User','Both')][string]$Target = 'Both',
    [switch]$ForceUpdate,
    [switch]$RestartNetlogon,
    [switch]$RepairWmiRepository,
    [switch]$ResetLocalPolicyCache,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$OutputPath = (Join-Path $env:ProgramData 'GPOResultRepair')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:VerificationFailures = 0
$script:Actions = 0

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($env:OS -ne 'Windows_NT') { Write-Error 'This tool requires Windows.'; exit 3 }
if (-not ($ForceUpdate -or $RestartNetlogon -or $RepairWmiRepository -or $ResetLocalPolicyCache)) { Write-Error 'Choose at least one repair action.'; exit 2 }
foreach ($command in 'gpresult.exe','gpupdate.exe','winmgmt.exe') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { Write-Error "$command is required."; exit 3 }
}
if (-not $DryRun -and -not (Test-Administrator)) { Write-Error 'Run from an elevated PowerShell session.'; exit 4 }

$runPath = Join-Path $OutputPath (Get-Date -Format 'yyyyMMdd_HHmmss')
$backupPath = Join-Path $runPath 'backup'
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
$logPath = Join-Path $runPath 'repair.log'
$beforePath = Join-Path $runPath 'before.txt'
$afterPath = Join-Path $runPath 'after.txt'

function Write-Log([string]$Message) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" | Tee-Object -FilePath $logPath -Append
}
function Save-PolicyState([string]$Path) {
    $computerResult = & gpresult.exe /r /scope computer 2>&1 | Out-String
    $userResult = & gpresult.exe /r /scope user 2>&1 | Out-String
    $events = Get-WinEvent -LogName 'Microsoft-Windows-GroupPolicy/Operational' -MaxEvents 100 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated,Id,LevelDisplayName,Message | Format-List | Out-String
    @("Collected: $(Get-Date -Format o)",'=== COMPUTER ===',$computerResult,'=== USER ===',$userResult,'=== EVENTS ===',$events) |
        Set-Content $Path -Encoding UTF8
}
function Invoke-RepairAction([string]$Description,[scriptblock]$Script) {
    $script:Actions++
    Write-Log "ACTION: $Description"
    if ($DryRun) { Write-Log "DRY-RUN: $Description"; return }
    try {
        $result = & $Script 2>&1
        if ($null -ne $result) { $result | Out-String | Add-Content $logPath }
        Write-Log "SUCCESS: $Description"
    } catch {
        $script:Failures++
        Write-Log "FAILED: $Description - $($_.Exception.Message)"
    }
}

Save-PolicyState -Path $beforePath
Write-Log "Saved pre-repair Group Policy evidence to $beforePath"

if (-not $DryRun -and -not $Yes) {
    if ((Read-Host 'Apply selected Group Policy repairs? Type YES') -cne 'YES') { Write-Log 'Repair cancelled.'; exit 10 }
}

if ($RestartNetlogon) {
    Invoke-RepairAction 'Restarting Netlogon' {
        Restart-Service Netlogon -Force
        (Get-Service Netlogon).WaitForStatus('Running',[TimeSpan]::FromSeconds(30))
    }
}
if ($RepairWmiRepository) {
    Invoke-RepairAction 'Verifying and salvaging the WMI repository when required' {
        $verifyOutput = & winmgmt.exe /verifyrepository 2>&1
        $verifyCode = $LASTEXITCODE
        $verifyOutput | Set-Content (Join-Path $runPath 'wmi-verify-before.txt') -Encoding UTF8
        if ($verifyCode -ne 0) {
            $salvageOutput = & winmgmt.exe /salvagerepository 2>&1
            $salvageCode = $LASTEXITCODE
            $salvageOutput | Set-Content (Join-Path $runPath 'wmi-salvage.txt') -Encoding UTF8
            if ($salvageCode -ne 0) { throw "winmgmt /salvagerepository exited with code $salvageCode." }
        } else {
            Write-Log 'WMI repository reported consistent; salvage was not required.'
        }
    }
}
if ($ResetLocalPolicyCache) {
    foreach ($folder in @("$env:SystemRoot\System32\GroupPolicy","$env:SystemRoot\System32\GroupPolicyUsers")) {
        if (Test-Path $folder) {
            $name = Split-Path $folder -Leaf
            Invoke-RepairAction "Backing up and resetting $name" {
                $destination = Join-Path $backupPath $name
                Copy-Item -LiteralPath $folder -Destination $destination -Recurse -Force
                if (-not (Test-Path $destination)) { throw "Backup of $folder was not created." }
                Remove-Item -LiteralPath $folder -Recurse -Force
            }
        } else {
            Write-Log "INFO: $folder does not exist; no cache reset was required."
        }
    }
}
if ($ForceUpdate -or $ResetLocalPolicyCache) {
    $gpArgs = if ($Target -eq 'Both') { @('/force') } else { @("/target:$($Target.ToLowerInvariant())",'/force') }
    Invoke-RepairAction "Refreshing $Target Group Policy" {
        $output = & gpupdate.exe @gpArgs 2>&1
        $output | Set-Content (Join-Path $runPath 'gpupdate.txt') -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { throw "gpupdate exited with code $LASTEXITCODE." }
    }
}

if (-not $DryRun) { Start-Sleep -Seconds 3 }
Save-PolicyState -Path $afterPath

if (-not $DryRun) {
    if ($RestartNetlogon -and (Get-Service Netlogon).Status -ne 'Running') { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: Netlogon is not running.' }
    if ($RepairWmiRepository) {
        $verifyAfter = & winmgmt.exe /verifyrepository 2>&1
        $verifyAfterCode = $LASTEXITCODE
        $verifyAfter | Set-Content (Join-Path $runPath 'wmi-verify-after.txt') -Encoding UTF8
        if ($verifyAfterCode -ne 0) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: WMI repository is still inconsistent.' }
    }
    if (($ForceUpdate -or $ResetLocalPolicyCache) -and -not (Test-Path (Join-Path $runPath 'gpupdate.txt'))) { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: gpupdate evidence was not created.' }
}

if ($script:Failures -gt 0) { exit 20 }
if ($script:VerificationFailures -gt 0) { exit 30 }
Write-Log "Workflow completed. Actions: $script:Actions; DryRun: $DryRun"
exit 0

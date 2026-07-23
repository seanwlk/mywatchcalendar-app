<#
.SYNOPSIS
    Checks via adb whether the MyWatchCalendar home-screen widget background
    refresh (WorkManager periodic task) is scheduled and actually runs with
    the app closed.

.DESCRIPTION
    Performs, in order:
      1. Locates adb and a connected device.
      2. Confirms the app is installed.
      3. Reports background-health signals (standby bucket, background
         restriction, battery-optimization whitelist).
      4. Confirms a WorkManager job is scheduled for the app and shows its
         constraints (expects CONNECTIVITY after the network-constraint fix).
      5. Asks WorkManager for diagnostics to find the 'widget_refresh_task'
         state and its JobScheduler id.
      6. Force-runs the job and watches logcat for the worker result:
           SUCCESS  -> background refresh works end to end
           RETRY    -> background machinery works, but the fetch failed
                       (server unreachable / auth) and will be retried
           FAILURE / callback errors -> background execution is broken
                       (e.g. old build without @pragma('vm:entry-point'))

    Prerequisites: USB debugging enabled, Android 8+, the app launched at
    least once after install (that's what registers the task). For a real
    test, swipe the app away from recents first - do NOT use Force Stop
    (Force Stop cancels all scheduled jobs until the next launch).

.EXAMPLE
    .\scripts\check-widget-refresh.ps1              # full check incl. force-run
    .\scripts\check-widget-refresh.ps1 -NoRun       # inspect state only
    .\scripts\check-widget-refresh.ps1 -DeviceId R58M12ABCDE
#>
[CmdletBinding()]
param(
    [string]$PackageName = 'com.sw.mywatchcalendar',
    [string]$TaskName = 'widget_refresh_task',
    [string]$DeviceId,
    [switch]$NoRun,
    [int]$TimeoutSec = 90
)

$ErrorActionPreference = 'Stop'

function Write-Pass($msg) { Write-Host "[PASS] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Gray }

# ---------------------------------------------------------------- 1. adb ---
function Find-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
    )
    if ($env:ANDROID_HOME)     { $candidates += (Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe') }
    if ($env:ANDROID_SDK_ROOT) { $candidates += (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe') }
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

$adb = Find-Adb
if (-not $adb) {
    Write-Fail 'adb not found. Add platform-tools to PATH or set ANDROID_HOME.'
    exit 1
}
Write-Info "adb: $adb"

# ------------------------------------------------------------- 2. device ---
$deviceLines = & $adb devices 2>&1 | Where-Object { $_ -match '^\S+\s+device$' }
$devices = @($deviceLines | ForEach-Object { ($_ -split '\s+')[0] })
if ($devices.Count -eq 0) {
    Write-Fail 'No device connected (or unauthorized - check the phone screen).'
    exit 1
}
if ($DeviceId) {
    if ($devices -notcontains $DeviceId) {
        Write-Fail "Device '$DeviceId' not connected. Connected: $($devices -join ', ')"
        exit 1
    }
    $serial = $DeviceId
} else {
    $serial = $devices[0]
    if ($devices.Count -gt 1) {
        Write-Warn "Multiple devices connected, using '$serial'. Pass -DeviceId to pick another."
    }
}

function Adb-Shell {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Cmd)
    & $adb -s $serial shell @Cmd 2>&1
}

$release = (Adb-Shell getprop ro.build.version.release | Out-String).Trim()
$brand   = (Adb-Shell getprop ro.product.manufacturer | Out-String).Trim()
Write-Info "Device: $serial ($brand, Android $release)"

# ---------------------------------------------------------- 3. installed ---
$pkgList = Adb-Shell pm list packages $PackageName
if (-not ($pkgList -match "^package:$([regex]::Escape($PackageName))$")) {
    Write-Fail "$PackageName is not installed on this device."
    exit 1
}
Write-Pass "$PackageName is installed."

# -------------------------------------------------- 4. background health ---
$bucketRaw = (Adb-Shell am get-standby-bucket $PackageName | Out-String).Trim()
if ($bucketRaw -match '^\d+$') {
    $bucketNames = @{ 5 = 'EXEMPTED'; 10 = 'ACTIVE'; 20 = 'WORKING_SET'; 30 = 'FREQUENT'; 40 = 'RARE'; 45 = 'RESTRICTED' }
    $bucket = [int]$bucketRaw
    $name = $bucketNames[$bucket]; if (-not $name) { $name = "bucket $bucket" }
    if ($bucket -ge 40) {
        Write-Warn "App standby bucket: $name - the system will heavily defer or block jobs. Open the app now and then, or set battery to Unrestricted."
    } else {
        Write-Pass "App standby bucket: $name"
    }
} else {
    Write-Info "Could not read standby bucket ($bucketRaw)."
}

$appops = (Adb-Shell appops get $PackageName RUN_ANY_IN_BACKGROUND | Out-String).Trim()
if ($appops -match 'ignore|deny') {
    Write-Warn "Background usage is RESTRICTED for this app (appops: $appops). Scheduled jobs will NOT run. Settings > Apps > Battery > remove restriction."
} elseif ($appops) {
    Write-Pass "Background usage allowed (appops: $($appops -replace '\s+', ' '))"
}

$whitelist = Adb-Shell dumpsys deviceidle whitelist
if ($whitelist -match [regex]::Escape($PackageName)) {
    Write-Info 'App is on the battery-optimization whitelist (unrestricted).'
} else {
    Write-Info "App is battery-optimized (default). Fine on stock Android; on aggressive OEMs ($brand) consider setting battery to Unrestricted."
}

# ------------------------------------------------- 5. job scheduled check ---
Write-Info 'Reading JobScheduler state...'
$jsDump = Adb-Shell dumpsys jobscheduler
$jobHeaderRegex = "JOB #[^/]+/(\d+):.*$([regex]::Escape($PackageName))/androidx\.work"
$jobIds = @()
$constraintByJob = @{}
for ($i = 0; $i -lt $jsDump.Count; $i++) {
    if ($jsDump[$i] -match $jobHeaderRegex) {
        $id = $Matches[1]
        $jobIds += $id
        for ($j = $i + 1; $j -lt [Math]::Min($i + 40, $jsDump.Count); $j++) {
            if ($jsDump[$j] -match 'JOB #') { break }
            if ($jsDump[$j] -match 'Required constraints:\s*(.+)$') {
                $constraintByJob[$id] = $Matches[1].Trim()
                break
            }
        }
    }
}
$jobIds = @($jobIds | Select-Object -Unique)
if ($jobIds.Count -eq 0) {
    Write-Fail 'No WorkManager job is scheduled for this app. Launch the app once (registration happens at startup), then re-run this script. Note: Force Stop also unschedules jobs until the next launch.'
    exit 1
}
Write-Pass "WorkManager job(s) scheduled. JobScheduler id(s): $($jobIds -join ', ')"
foreach ($id in $jobIds) {
    if ($constraintByJob[$id]) {
        $c = $constraintByJob[$id]
        if ($c -match 'CONNECTIVITY') {
            Write-Pass "Job ${id}: constraints = $c (network constraint active)"
        } else {
            Write-Info "Job ${id}: constraints = $c"
        }
    }
}

# ------------------------------------------- 6. WorkManager diagnostics ----
Write-Info "Requesting WorkManager diagnostics for '$TaskName'..."
& $adb -s $serial logcat -c 2>$null
Adb-Shell am broadcast -a "androidx.work.diagnostics.REQUEST_DIAGNOSTICS" -p $PackageName | Out-Null
Start-Sleep -Seconds 5
$diagLog = & $adb -s $serial logcat -d 2>&1
$taskRows = @($diagLog | Where-Object { $_ -match 'WM-Diagnostic' -and $_ -match [regex]::Escape($TaskName) })
$diagJobId = $null
if ($taskRows.Count -gt 0) {
    $tokens = ($taskRows[0] -replace '^.*WM-\w+:\s*', '') -split "`t" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $state = $tokens | Where-Object { $_ -match '^(ENQUEUED|RUNNING|SUCCEEDED|FAILED|BLOCKED|CANCELLED)$' } | Select-Object -First 1
    $diagJobId = $tokens | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1
    if ($state) {
        Write-Pass "Task '$TaskName' known to WorkManager, state: $state"
    } else {
        Write-Info "Task '$TaskName' found in diagnostics: $($taskRows[0])"
    }
} else {
    Write-Warn "Diagnostics did not report '$TaskName' (may be a log-level limitation on this build). Continuing with JobScheduler ids."
}

if ($NoRun) {
    Write-Host ''
    Write-Pass 'State check finished (force-run skipped via -NoRun).'
    exit 0
}

# ------------------------------------------------------- 7. force-run it ---
$runIds = @()
if ($diagJobId -and ($jobIds -contains $diagJobId)) { $runIds = @($diagJobId) } else { $runIds = $jobIds }
Write-Info "Force-running job id(s) $($runIds -join ', ') - for a genuine test the app should be swiped away from recents."
& $adb -s $serial logcat -c 2>$null
foreach ($id in $runIds) {
    $runOut = (Adb-Shell cmd jobscheduler run -f $PackageName $id | Out-String).Trim()
    if ($runOut) { Write-Info "jobscheduler run ${id}: $runOut" }
}

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$verdict = $null
$evidence = $null
Write-Info "Watching logcat for the worker result (up to ${TimeoutSec}s)..."
while ((Get-Date) -lt $deadline -and -not $verdict) {
    Start-Sleep -Seconds 3
    $log = & $adb -s $serial logcat -d 2>&1
    foreach ($line in $log) {
        if ($line -match 'Worker result SUCCESS' -and $line -match 'workmanager') { $verdict = 'SUCCESS'; $evidence = $line; break }
        if ($line -match 'Worker result RETRY'   -and $line -match 'workmanager') { $verdict = 'RETRY';   $evidence = $line; break }
        if ($line -match 'Worker result FAILURE' -and $line -match 'workmanager') { $verdict = 'FAILURE'; $evidence = $line; break }
        if ($line -match '(?i)fail.*callback|callback.*(not found|lookup)|not properly initialized') { $verdict = 'CALLBACK'; $evidence = $line; break }
    }
}

Write-Host ''
switch ($verdict) {
    'SUCCESS' {
        Write-Pass 'Background refresh ran END TO END with the OS scheduler: headless Dart isolate started, fetch + widget write succeeded.'
        Write-Info  "Evidence: $($evidence.Trim())"
        Write-Info  'The widget on the home screen should now show fresh data.'
        exit 0
    }
    'RETRY' {
        Write-Warn 'Background execution WORKS (the Dart task ran), but the refresh itself failed - server unreachable or login expired. WorkManager will retry with backoff.'
        Write-Info  "Evidence: $($evidence.Trim())"
        exit 2
    }
    'FAILURE' {
        Write-Fail 'The worker ran but returned failure.'
        Write-Info  "Evidence: $($evidence.Trim())"
    }
    'CALLBACK' {
        Write-Fail "Callback lookup failed - this is the missing @pragma('vm:entry-point') signature (old release build?) or the app was never launched after install."
        Write-Info  "Evidence: $($evidence.Trim())"
    }
    default {
        Write-Fail "No worker result within ${TimeoutSec}s. Possible causes: OEM battery manager blocked the job ($brand), the job ran without logging, or the forced job id was not the widget task."
    }
}

Write-Info 'Recent flutter/WorkManager errors from logcat (if any):'
$errLines = & $adb -s $serial logcat -d 2>&1 | Where-Object { $_ -match 'E/flutter|E AndroidRuntime|WM-WorkerWrapper' } | Select-Object -Last 15
if ($errLines) { $errLines | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray } } else { Write-Info '    (none)' }
exit 1

param(
    [string]$DeviceId = "",
    [string]$SavedIp = "",
    [string]$AdbPath = "adb",
    [int]$ParentPid = 0
)

$ErrorActionPreference = "SilentlyContinue"

if (-not $DeviceId -and $SavedIp) {
    $DeviceId = "$SavedIp:5555"
}

if (-not $DeviceId) {
    exit 0
}

# Resolve adb path if default
if ($AdbPath -eq "adb" -and $env:LOCALAPPDATA) {
    $defaultAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $defaultAdb) {
        $AdbPath = $defaultAdb
    }
}

while ($true) {
    # If a parent PID is provided, verify it is still running
    if ($ParentPid -gt 0) {
        $proc = Get-Process -Id $ParentPid -ErrorAction SilentlyContinue
        if (-not $proc -or $proc.HasExited) {
            break
        }
    }

    # Query device status
    $state = & $AdbPath -s $DeviceId get-state 2>&1
    $stateStr = "$state".Trim()

    if ($LASTEXITCODE -ne 0 -or $stateStr -ne "device") {
        # Connection dropped or device is offline - attempt recovery
        if ($SavedIp) {
            & $AdbPath connect "$SavedIp:5555" 2>&1 | Out-Null
            & $AdbPath -s $DeviceId shell input keyevent 224 2>&1 | Out-Null
        }
    } else {
        # Connection alive - send keepalive heartbeat packet over TCP socket
        & $AdbPath -s $DeviceId shell "echo 1 > /dev/null" 2>&1 | Out-Null
        # Enforce wake lock & screen stayon so Android doesn't sleep
        & $AdbPath -s $DeviceId shell "svc power stayon true" 2>&1 | Out-Null
    }

    Start-Sleep -Seconds 4
}

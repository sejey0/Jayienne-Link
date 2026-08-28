param(
    [string]$TargetDevice = ""
)

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    $adb = "adb"
}

$deviceArg = @()
if ($TargetDevice -and $TargetDevice.Trim() -ne "") {
    $deviceArg = @("-s", $TargetDevice)
}

# Method 1: ip route wlan0
try {
    $routeOut = & $adb @deviceArg shell "ip route" 2>$null
    foreach ($line in ($routeOut -split "`n")) {
        if ($line -match "wlan0.*src\s+([0-9\.]+)") {
            $ip = $matches[1].Trim()
            if ($ip -and $ip -ne "0.0.0.0" -and -not $ip.StartsWith("127.")) {
                Write-Output $ip
                exit 0
            }
        }
    }
} catch {}

# Method 2: ip addr show wlan0
try {
    $addrOut = & $adb @deviceArg shell "ip -f inet addr show wlan0" 2>$null
    if (-not $addrOut) {
        $addrOut = & $adb @deviceArg shell "ip addr show wlan0" 2>$null
    }
    foreach ($line in ($addrOut -split "`n")) {
        if ($line -match "inet\s+([0-9\.]+)/") {
            $ip = $matches[1].Trim()
            if ($ip -and $ip -ne "0.0.0.0" -and -not $ip.StartsWith("127.")) {
                Write-Output $ip
                exit 0
            }
        }
    }
} catch {}

# Method 3: any non-cellular inet IP (e.g. eth0, wlan1)
try {
    $allAddr = & $adb @deviceArg shell "ip -f inet addr" 2>$null
    foreach ($line in ($allAddr -split "`n")) {
        if ($line -match "inet\s+([0-9\.]+)/") {
            $ip = $matches[1].Trim()
            if ($ip -and $ip -notmatch "^(127\.|0\.|10\.|5\.)" -and -not $line.Contains("ccmni") -and -not $line.Contains("rmnet")) {
                Write-Output $ip
                exit 0
            }
        }
    }
} catch {}

exit 1

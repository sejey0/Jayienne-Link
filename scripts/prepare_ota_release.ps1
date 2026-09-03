param(
    [ValidateSet("scan", "apply")]
    [string]$Action = "scan",

    [string]$NewVersion = "",
    [int]$NewBuild = 0,
    [string]$ReleaseNotesFile = "",
    [string]$GhUser = "sejey0",
    [string]$GhRepo = "Jayienne-Link"
)

$ErrorActionPreference = "Stop"

# Paths
$rootDir = (Resolve-Path "$PSScriptRoot\..").Path
$pubspecPath = Join-Path $rootDir "pubspec.yaml"
$versionJsonPath = Join-Path $rootDir "version.json"
$statePath = Join-Path $rootDir "scripts\.ota_state.json"
$buildDir = Join-Path $rootDir "build"
$notesOutPath = Join-Path $PSScriptRoot ".release_notes.txt"

function Get-RealAppVersion {
    $ver = "1.0.0"
    $bld = 1

    if (Test-Path $pubspecPath) {
        $content = Get-Content -Path $pubspecPath -Raw
        if ($content -match '(?m)^\s*version:\s*([0-9]+\.[0-9]+(?:\.[0-9]+)?)(?:\+([0-9]+))?') {
            $ver = $matches[1]
            if ($matches[2]) {
                $bld = [int]$matches[2]
            }
        }
    } elseif (Test-Path $versionJsonPath) {
        try {
            $json = Get-Content -Path $versionJsonPath -Raw | ConvertFrom-Json
            if ($json.version) { $ver = $json.version }
            if ($json.build_number) { $bld = [int]$json.build_number }
        } catch {}
    }

    return @{
        Version = $ver
        BuildNumber = $bld
    }
}

if ($Action -eq "scan") {
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  Scanning Real App Version & Git Commits for OTA   " -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""

    # 1. Real Current Version from pubspec.yaml
    $appVer = Get-RealAppVersion
    $currentVer = $appVer.Version
    $currentBuild = $appVer.BuildNumber

    Write-Host " [Current App Version]" -ForegroundColor Yellow
    Write-Host "   * pubspec.yaml:    v$currentVer (Build $currentBuild)" -ForegroundColor White

    if (Test-Path $versionJsonPath) {
        try {
            $vJson = Get-Content -Path $versionJsonPath -Raw | ConvertFrom-Json
            Write-Host "   * version.json:    v$($vJson.version) (Build $($vJson.build_number))" -ForegroundColor Gray
        } catch {}
    }

    # 2. Latest Git Tag
    $lastTag = ""
    try {
        $gitTagOut = git describe --tags --abbrev=0 2>$null
        if ($gitTagOut) {
            $lastTag = $gitTagOut.Trim()
        }
    } catch {}

    if (-not $lastTag) {
        try {
            $tagList = git tag --sort=-v:refname 2>$null
            if ($tagList) {
                $lastTag = ($tagList | Select-Object -First 1).Trim()
            }
        } catch {}
    }

    if ($lastTag) {
        Write-Host "   * Latest Git Tag:  $lastTag" -ForegroundColor White
    } else {
        Write-Host "   * Latest Git Tag:  (No release tags found)" -ForegroundColor Gray
    }

    # 3. Scan Git Commits
    Write-Host ""
    Write-Host " [Scanning Commits]" -ForegroundColor Yellow

    $commitLines = @()
    if ($lastTag) {
        Write-Host "   Fetching commits since $lastTag..." -ForegroundColor Gray
        $logOutput = git log "$lastTag..HEAD" --pretty=format:"%s" 2>$null
        if ($logOutput) {
            $commitLines = @($logOutput -split "`r?`n")
        }
    }

    if ($commitLines.Count -eq 0) {
        if ($lastTag) {
            Write-Host "   No new commits found directly since $lastTag. Checking recent commits..." -ForegroundColor Gray
        }
        $logOutput = git log -n 10 --pretty=format:"%s" 2>$null
        if ($logOutput) {
            $commitLines = @($logOutput -split "`r?`n")
        }
    }

    # Filter out release bumps and empty lines
    $filteredCommits = @()
    foreach ($line in $commitLines) {
        $trimmed = $line.Trim()
        if ($trimmed -and $trimmed -notmatch '^chore\(release\):' -and $trimmed -notmatch '^bump version') {
            $filteredCommits += $trimmed
        }
    }

    # 4. Analyze Commits for SemVer bump
    $hasBreaking = $false
    $hasFeat = $false
    $changelogBullets = @()

    foreach ($commit in $filteredCommits) {
        if ($commit -match 'BREAKING CHANGE|!:') {
            $hasBreaking = $true
        } elseif ($commit -match '^\s*feat(\([^\)]+\))?:') {
            $hasFeat = $true
        }

        # Format bullet point
        $bullet = $commit
        if (-not ($bullet.StartsWith('-') -or $bullet.StartsWith('*'))) {
            $bullet = "- $bullet"
        }
        $changelogBullets += $bullet
    }

    $vParts = $currentVer.Split('.')
    $major = if ($vParts.Length -ge 1) { [int]$vParts[0] } else { 1 }
    $minor = if ($vParts.Length -ge 2) { [int]$vParts[1] } else { 0 }
    $patch = if ($vParts.Length -ge 3) { [int]$vParts[2] } else { 0 }

    $bumpReason = ""
    $nextVer = ""
    if ($hasBreaking) {
        $nextVer = "$($major + 1).0.0"
        $bumpReason = "Major bump (Breaking changes detected)"
    } elseif ($hasFeat) {
        $nextVer = "$major.$($minor + 1).0"
        $bumpReason = "Minor bump (New features detected)"
    } else {
        $nextVer = "$major.$minor.$($patch + 1)"
        $bumpReason = "Patch bump (Improvements & bug fixes)"
    }
    $nextBuild = $currentBuild + 1

    # Display Commits
    if ($filteredCommits.Count -gt 0) {
        Write-Host "   Found $($filteredCommits.Count) commit(s):" -ForegroundColor Green
        foreach ($c in $filteredCommits) {
            Write-Host "     * $c" -ForegroundColor DarkCyan
        }
    } else {
        Write-Host "   No recent feature or fix commits found." -ForegroundColor Gray
        $changelogBullets += "- Update with exciting improvements and bug fixes."
    }

    Write-Host ""
    Write-Host " [Smart Recommendation]" -ForegroundColor Yellow
    Write-Host "   * Recommended Version: v$nextVer ($bumpReason)" -ForegroundColor Green
    Write-Host "   * Recommended Build:   $nextBuild" -ForegroundColor Green
    Write-Host "----------------------------------------------------" -ForegroundColor Gray

    # Save state to .ota_state.json for batch script consumption
    $defaultNotes = $changelogBullets -join "`n"
    $state = [ordered]@{
        current_version = $currentVer
        current_build = $currentBuild
        last_tag = $lastTag
        recommended_version = $nextVer
        recommended_build = $nextBuild
        bump_reason = $bumpReason
        commits_count = $filteredCommits.Count
        scanned_notes = $defaultNotes
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json -Depth 4), $utf8NoBom)

    # Export fast batch env file
    $envBatPath = Join-Path $rootDir "scripts\.ota_env.bat"
    $envLines = @(
        "set ""CURRENT_VER=$currentVer""",
        "set ""CURRENT_BUILD=$currentBuild""",
        "set ""LAST_TAG=$lastTag""",
        "set ""DEFAULT_NEXT_VER=$nextVer""",
        "set ""DEFAULT_NEXT_BUILD=$nextBuild""",
        "set ""BUMP_REASON=$bumpReason""",
        "set ""COMMITS_COUNT=$($filteredCommits.Count)"""
    )
    [System.IO.File]::WriteAllLines($envBatPath, $envLines)

    exit 0
}

if ($Action -eq "apply") {
    if (-not $NewVersion) {
        Write-Error "NewVersion parameter is required for Action 'apply'."
        exit 1
    }
    if ($NewBuild -le 0) {
        Write-Error "NewBuild parameter must be a positive integer."
        exit 1
    }

    # Ensure build dir exists
    if (-not (Test-Path $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    }

    # 1. Read Release Notes from state or file
    $finalNotes = "Update with exciting improvements and bug fixes."
    if ($ReleaseNotesFile -and (Test-Path $ReleaseNotesFile)) {
        $finalNotes = Get-Content -Path $ReleaseNotesFile -Raw -Encoding UTF8
    } elseif (Test-Path $statePath) {
        try {
            $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
            if ($state.scanned_notes) {
                $finalNotes = $state.scanned_notes
            }
        } catch {}
    }

    $finalNotes = $finalNotes.Trim()
    if (-not $finalNotes) {
        $finalNotes = "Update with exciting improvements and bug fixes."
    }

    # Write release notes to build/release_notes.txt
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($notesOutPath, $finalNotes, $utf8NoBom)

    Write-Host "Updating pubspec.yaml to version: $NewVersion+$NewBuild..." -ForegroundColor Cyan
    $pubspecRaw = [System.IO.File]::ReadAllText($pubspecPath)
    $pubspecContent = $pubspecRaw -replace '(?m)^\s*version:\s*.*$', "version: $NewVersion+$NewBuild"
    [System.IO.File]::WriteAllText($pubspecPath, $pubspecContent, $utf8NoBom)

    Write-Host "Updating version.json..." -ForegroundColor Cyan
    $downloadUrl = "https://github.com/$GhUser/$GhRepo/releases/download/v$NewVersion/app-release.apk"
    $versionData = [ordered]@{
        version = $NewVersion
        build_number = [int]$NewBuild
        download_url = $downloadUrl
        release_notes = $finalNotes
        min_required_version = $NewVersion
        force_update = $true
    }

    $jsonString = $versionData | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($versionJsonPath, $jsonString, $utf8NoBom)

    Write-Host "[SUCCESS] Synchronized version: v$NewVersion (Build $NewBuild)" -ForegroundColor Green
    exit 0
}

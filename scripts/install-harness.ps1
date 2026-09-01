[CmdletBinding()]
param(
    [Alias("d")]
    [string]$Directory = $env:HARNESS_TARGET_DIR,
    [Alias("y")]
    [switch]$Yes,
    [switch]$Merge,
    [switch]$WithEngineeringWisdom,
    [switch]$RefreshAgentShim,
    [switch]$Claude,
    [switch]$Override,
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host $Message
}

function Fail([string]$Message) {
    throw "Error: $Message"
}

function Resolve-TargetPath([string]$PathValue) {
    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        $PathValue = (Get-Location).Path
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($PathValue)
    if ($expanded.StartsWith("~")) {
        $expanded = Join-Path $HOME $expanded.Substring(1).TrimStart("\", "/")
    }
    if ([System.IO.Path]::IsPathRooted($expanded)) {
        return [System.IO.Path]::GetFullPath($expanded)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $expanded))
}

function Get-SourceMode {
    if ($PSScriptRoot) {
        $candidate = Split-Path -Parent $PSScriptRoot
        if ((Test-Path (Join-Path $candidate "AGENTS.md")) -and (Test-Path (Join-Path $candidate "docs/HARNESS.md"))) {
            return @{ Mode = "local"; Root = $candidate }
        }
    }
    return @{ Mode = "remote"; Root = "" }
}

function Read-RemoteText([string]$Url) {
    if ($Url.StartsWith("file://")) {
        return Get-Content -LiteralPath ([uri]$Url).LocalPath -Raw
    }
    return (Invoke-WebRequest -UseBasicParsing -Uri $Url).Content
}

function Write-SourceFile([string]$Relative, [string]$Target) {
    if ($Relative -eq "AGENTS.md") {
        $block = (Read-SourceText "scripts/agent-harness-block.md").TrimEnd("`r", "`n")
        Set-Content -LiteralPath $Target -Value ("# Agent Instructions`n`n" + $block + "`n") -NoNewline
        return
    }

    if ($script:Source.Mode -eq "local") {
        $source = Join-Path $script:Source.Root $Relative
        if (!(Test-Path $source)) {
            Fail "Source file missing: $source"
        }
        Copy-Item -LiteralPath $source -Destination $Target -Force
        return
    }

    $url = "$script:SourceBaseUrl/$($Relative -replace '\\','/')"
    if ($url.StartsWith("file://")) {
        Copy-Item -LiteralPath ([uri]$url).LocalPath -Destination $Target -Force
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $Target
    }
}

function Read-SourceText([string]$Relative) {
    if ($script:Source.Mode -eq "local") {
        $source = Join-Path $script:Source.Root $Relative
        if (!(Test-Path $source)) {
            Fail "Source file missing: $source"
        }
        return Get-Content -LiteralPath $source -Raw
    }

    $url = "$script:SourceBaseUrl/$($Relative -replace '\\','/')"
    return Read-RemoteText $url
}

function Read-PayloadManifest([string]$Manifest) {
    if ($script:Source.Mode -eq "local") {
        $path = Join-Path $script:Source.Root $Manifest
        if (!(Test-Path $path)) {
            Fail "Payload manifest missing: $path"
        }
        return Get-Content -LiteralPath $path
    }

    $url = "$script:SourceBaseUrl/$Manifest"
    try {
        return ((Read-RemoteText $url) -split "\r?\n")
    } catch {
        Fail "Could not download $url"
    }
}

function Get-PayloadFiles([string]$Manifest) {
    foreach ($line in (Read-PayloadManifest $Manifest)) {
        $relative = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($relative) -or $relative.StartsWith("#")) {
            continue
        }
        $relative
    }
}

function Assert-NoReparseComponents([string]$Relative, [string]$Label) {
    $current = $script:TargetDir
    foreach ($component in ($Relative -split '[\\/]')) {
        if ([string]::IsNullOrEmpty($component)) { continue }
        $current = Join-Path $current $component
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
            Fail "refusing symlink or reparse point for $Label"
        }
    }
}

function Copy-HarnessFile([string]$Relative) {
    $target = Join-Path $script:TargetDir $Relative
    Assert-NoReparseComponents $Relative "Harness path $Relative"
    $targetItem = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue

    if ($null -ne $targetItem) {
        if ($script:ConflictAction -eq "merge") {
            Write-Step "skip     $Relative (merge keeps existing file)"
            $script:Skipped++
        } elseif ($Force) {
            if ($DryRun) {
                Write-Step "overwrite $Relative (backup first)"
            } else {
                $backup = Join-Path $script:BackupDir $Relative
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
                Copy-Item -LiteralPath $target -Destination $backup -Force
                Write-SourceFile $Relative $target
                Write-Step "updated  $Relative (backup: $($backup.Substring($script:TargetDir.Length + 1)))"
            }
            $script:Updated++
        } else {
            Write-Step "skip     $Relative (already exists)"
            $script:Skipped++
        }
        return
    }

    if ($DryRun) {
        Write-Step "create   $Relative"
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Write-SourceFile $Relative $target
        Write-Step "created  $Relative"
    }
    $script:Created++
}

function Get-AgentShimBlock {
    return (Read-SourceText "scripts/agent-harness-block.md").TrimEnd("`r", "`n")
}

function Get-ClaudeShimBlock {
    return (Read-SourceText "scripts/claude-harness-block.md").TrimEnd("`r", "`n")
}

function Assert-HarnessMarkers([string]$Content, [string]$Label) {
    $begin = [regex]::Matches($Content, '<!-- HARNESS:BEGIN -->')
    $end = [regex]::Matches($Content, '<!-- HARNESS:END -->')
    if ($begin.Count -eq 0 -and $end.Count -eq 0) {
        return
    }
    if ($begin.Count -ne 1 -or $end.Count -ne 1) {
        Fail "$Label must contain exactly one complete Harness marker pair"
    }
    if ($begin[0].Index -ge $end[0].Index) {
        Fail "$Label Harness markers are out of order"
    }
}

function Refresh-AgentShimFile {
    if (!$RefreshAgentShim) {
        return
    }
    $target = Join-Path $script:TargetDir "AGENTS.md"
    Assert-NoReparseComponents "AGENTS.md" "AGENTS.md"
    $targetItem = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($null -eq $targetItem) {
        return
    }

    $content = Get-Content -LiteralPath $target -Raw
    Assert-HarnessMarkers $content "AGENTS.md"

    if ($DryRun) {
        Write-Step "refresh  AGENTS.md (replace marked Harness block, backup first)"
        $script:Updated++
        return
    }

    New-Item -ItemType Directory -Force -Path $script:BackupDir | Out-Null
    $backup = Join-Path $script:BackupDir "AGENTS.md"
    if (!(Test-Path $backup)) {
        Copy-Item -LiteralPath $target -Destination $backup
    }

    $block = Get-AgentShimBlock
    if ($content -match "(?s)<!-- HARNESS:BEGIN -->.*?<!-- HARNESS:END -->") {
        $content = [regex]::Replace($content, "(?s)<!-- HARNESS:BEGIN -->.*?<!-- HARNESS:END -->", [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block })
    } else {
        $content = $content.TrimEnd() + "`n`n" + $block + "`n"
    }
    Set-Content -LiteralPath $target -Value $content -NoNewline
    Write-Step "updated  AGENTS.md (refreshed Harness block; backup: $($backup.Substring($script:TargetDir.Length + 1)))"
    $script:Updated++
}

function Backup-ClaudeFile {
    $target = Join-Path $script:TargetDir "CLAUDE.md"
    if (!(Test-Path -LiteralPath $target -PathType Leaf)) {
        return
    }
    New-Item -ItemType Directory -Force -Path $script:BackupDir | Out-Null
    $backup = Join-Path $script:BackupDir "CLAUDE.md"
    if (!(Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $target -Destination $backup
    }
}

function Write-ClaudeShim {
    if (!$Claude) {
        return
    }

    $target = Join-Path $script:TargetDir "CLAUDE.md"
    Assert-NoReparseComponents "CLAUDE.md" "CLAUDE.md"
    $sourceTarget = Join-Path $script:Source.Root "CLAUDE.md"
    if ($script:Source.Mode -eq "local" -and (Test-Path -LiteralPath $target -PathType Leaf) -and
        [System.IO.Path]::GetFullPath($target) -eq [System.IO.Path]::GetFullPath($sourceTarget)) {
        Write-Step "skip     CLAUDE.md (source file)"
        $script:Skipped++
        return
    }

    $exists = Test-Path -LiteralPath $target -PathType Leaf
    $content = if ($exists) { Get-Content -LiteralPath $target -Raw } else { "" }
    if ($exists) {
        Assert-HarnessMarkers $content "CLAUDE.md"
    }

    $block = Get-ClaudeShimBlock
    $pattern = '(?s)<!-- HARNESS:BEGIN -->.*?<!-- HARNESS:END -->'
    $current = [regex]::Match($content, $pattern)
    $currentText = if ($current.Success) { $current.Value.Replace("`r`n", "`n").TrimEnd() } else { "" }
    $blockText = $block.Replace("`r`n", "`n").TrimEnd()

    if ($current.Success -and $currentText -eq $blockText) {
        Write-Step "skip     CLAUDE.md (Harness block current)"
        $script:Skipped++
        return
    }

    if ($DryRun) {
        if ($current.Success) {
            Write-Step "update   CLAUDE.md (refresh marked Harness block, backup first)"
        } elseif ($exists) {
            Write-Step "update   CLAUDE.md (append Harness block, backup first)"
        } else {
            Write-Step "create   CLAUDE.md"
        }
        if ($exists) {
            $script:Updated++
        } else {
            $script:Created++
        }
        return
    }

    if ($current.Success) {
        Backup-ClaudeFile
        $before = $content.Substring(0, $current.Index)
        $after = $content.Substring($current.Index + $current.Length)
        $content = $before + $block + $after
        Set-Content -LiteralPath $target -Value $content -NoNewline
        Write-Step "updated  CLAUDE.md (refreshed Harness block; backup: $($script:BackupDir.Substring($script:TargetDir.Length + 1))/CLAUDE.md)"
    } elseif ($exists) {
        Backup-ClaudeFile
        Set-Content -LiteralPath $target -Value ($content.TrimEnd() + "`n`n" + $block + "`n") -NoNewline
        Write-Step "updated  CLAUDE.md (appended Harness block; backup: $($script:BackupDir.Substring($script:TargetDir.Length + 1))/CLAUDE.md)"
    } else {
        New-Item -ItemType Directory -Force -Path $script:TargetDir | Out-Null
        Set-Content -LiteralPath $target -Value ("# Project Rules`n`n" + $block + "`n") -NoNewline
        Write-Step "created  CLAUDE.md"
    }

    if ($exists) {
        $script:Updated++
    } else {
        $script:Created++
    }
}

function Copy-SourceFileTo([string]$SourceRelative, [string]$TargetRelative, [bool]$RefreshMarked = $false) {
    $target = Join-Path $script:TargetDir $TargetRelative
    Assert-NoReparseComponents $TargetRelative "Harness path $TargetRelative"
    $targetItem = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue

    if ($null -ne $targetItem) {
        if ($RefreshMarked -and !$targetItem.PSIsContainer -and ((Get-Content -LiteralPath $target -Raw) -like "*# Claude Code compatibility loader*")) {
            $sourceTemp = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-source-" + [guid]::NewGuid().ToString("N"))
            try {
                Write-SourceFile $SourceRelative $sourceTemp
                if ((Get-FileHash -Algorithm SHA256 $sourceTemp).Hash -eq (Get-FileHash -Algorithm SHA256 $target).Hash) {
                    Write-Step "skip     $TargetRelative (Claude wrapper current)"
                    $script:Skipped++
                    return
                }
                if ($DryRun) {
                    Write-Step "update   $TargetRelative (refresh marked Claude wrapper, backup first)"
                } else {
                    $backup = Join-Path $script:BackupDir $TargetRelative
                    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
                    Copy-Item -LiteralPath $target -Destination $backup -Force
                    Copy-Item -LiteralPath $sourceTemp -Destination $target -Force
                    Write-Step "updated  $TargetRelative (backup: $($backup.Substring($script:TargetDir.Length + 1)))"
                }
                $script:Updated++
                return
            } finally {
                Remove-Item -LiteralPath $sourceTemp -Force -ErrorAction SilentlyContinue
            }
        }
        if ($script:ConflictAction -eq "merge") {
            Write-Step "skip     $TargetRelative (merge keeps existing file)"
            $script:Skipped++
        } elseif ($Force) {
            if ($DryRun) {
                Write-Step "overwrite $TargetRelative (backup first)"
            } else {
                $backup = Join-Path $script:BackupDir $TargetRelative
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
                Copy-Item -LiteralPath $target -Destination $backup -Force
                Write-SourceFile $SourceRelative $target
                Write-Step "updated  $TargetRelative (backup: $($backup.Substring($script:TargetDir.Length + 1)))"
            }
            $script:Updated++
        } else {
            Write-Step "skip     $TargetRelative (already exists)"
            $script:Skipped++
        }
        return
    }

    if ($DryRun) {
        Write-Step "create   $TargetRelative"
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Write-SourceFile $SourceRelative $target
        Write-Step "created  $TargetRelative"
    }
    $script:Created++
}

function Install-ClaudeSkills {
    if (!$Claude) {
        return
    }
    foreach ($file in (Get-PayloadFiles $script:ClaudeSkillsPayloadManifest)) {
        Copy-SourceFileTo $file $file $true
    }
    if ($WithEngineeringWisdom) {
        Copy-SourceFileTo "scripts/claude-engineering-wisdom-shim.md" ".claude/skills/engineering-wisdom/SKILL.md" $true
    }
}

function Get-HarnessReleaseTag {
    if ($env:HARNESS_CORE_RELEASE_TAG) { return $env:HARNESS_CORE_RELEASE_TAG.Trim() }
    if ($script:Source.Mode -eq "local") {
        $path = Join-Path $script:Source.Root "scripts/harness-release-tag"
        if (!(Test-Path $path)) { Fail "Harness core release tag is missing: $path" }
        return ((Get-Content -LiteralPath $path | Where-Object { $_ -match "\S" -and $_ -notmatch "^\s*#" } | Select-Object -First 1) -as [string]).Trim()
    }
    try {
        $text = Read-RemoteText "$script:CoreSourceBaseUrl/scripts/harness-release-tag"
        return (($text -split "`n" | Where-Object { $_ -match "\S" -and $_ -notmatch "^\s*#" } | Select-Object -First 1) -as [string]).Trim()
    } catch {
        Fail "Harness core release tag is missing"
    }
}

function Merge-CoreGitignore([string]$Target) {
    Assert-NoReparseComponents ".gitignore" ".gitignore"
    $rules = @("# Harness core maintenance binary", "scripts/bin/harness", "scripts/bin/harness.exe")
    $targetItem = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    $existing = if ($null -ne $targetItem) { Get-Content -LiteralPath $Target } else { @() }
    $missing = @($rules | Where-Object { $existing -notcontains $_ })
    if ($missing.Count -eq 0) {
        Write-Step "skip     .gitignore (Harness core binary rules already present)"
        return
    }
    if ($DryRun) {
        Write-Step "update   .gitignore (append Harness core binary rules)"
        return
    }
    $prefix = if (($null -ne $targetItem) -and ($targetItem.Length -gt 0)) { "`n" } else { "" }
    Add-Content -LiteralPath $Target -Value ($prefix + (($missing -join "`n") + "`n")) -NoNewline
    Write-Step "updated  .gitignore (appended Harness core binary rules)"
}

function Assert-NotReparsePoint([string]$Path, [string]$Label) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -ne $item -and (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
        Fail "refusing symlink or reparse point for $Label"
    }
}

function Install-HarnessCore {
    $platform = if ($env:HARNESS_CORE_CLI_PLATFORM) { $env:HARNESS_CORE_CLI_PLATFORM } else { "windows-x64" }
    if ($platform -ne "windows-x64") { Fail "Unsupported Windows Harness core platform: $platform" }
    $stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-core-" + [guid]::NewGuid().ToString("N"))
    $staged = Join-Path $stageRoot "harness.exe"
    $command = if (Test-Path (Join-Path $script:TargetDir ".harness-core/manifest.json")) { "update" } else { "install" }
    $pendingVersion = $null
    $sessionPath = Join-Path $script:TargetDir ".harness-core/update/session.json"
    if ($command -eq "update" -and (Test-Path $sessionPath)) {
        $pendingVersion = (Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json).to_version
        if ([string]::IsNullOrWhiteSpace($pendingVersion)) { Fail "could not read pending Harness update version" }
    }
    New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null
    try {
        if ($env:HARNESS_CORE_BINARY) {
            if (!(Test-Path $env:HARNESS_CORE_BINARY)) { Fail "HARNESS_CORE_BINARY does not exist: $env:HARNESS_CORE_BINARY" }
            Copy-Item -LiteralPath $env:HARNESS_CORE_BINARY -Destination $staged
        } elseif ($script:Source.Mode -eq "local") {
            & cargo build --quiet --manifest-path (Join-Path $script:Source.Root "Cargo.toml") -p harness --locked
            if ($LASTEXITCODE -ne 0) { Fail "could not build the local Rust harness CLI" }
            Copy-Item -LiteralPath (Join-Path $script:Source.Root "target/debug/harness.exe") -Destination $staged
        } else {
            $releaseTag = if ($pendingVersion) { "harness-v$pendingVersion" } else { Get-HarnessReleaseTag }
            if ($releaseTag -notmatch '^harness-v[0-9]+\.[0-9]+\.[0-9]+(?:[-.][A-Za-z0-9]+)*$') { Fail "invalid Harness core release tag: $releaseTag" }
            $baseUrl = if ($env:HARNESS_CORE_CLI_BASE_URL) { $env:HARNESS_CORE_CLI_BASE_URL.TrimEnd("/") } else { "https://github.com/hoangnb24/repository-harness/releases/download/$releaseTag" }
            $binaryUrl = "$baseUrl/harness-windows-x64.exe"
            $checksumUrl = "$binaryUrl.sha256"
            $checksum = "$staged.sha256"
            if ($binaryUrl.StartsWith("file://")) {
                Copy-Item -LiteralPath ([uri]$binaryUrl).LocalPath -Destination $staged
                Copy-Item -LiteralPath ([uri]$checksumUrl).LocalPath -Destination $checksum
            } else {
                Invoke-WebRequest -UseBasicParsing -Uri $binaryUrl -OutFile $staged
                Invoke-WebRequest -UseBasicParsing -Uri $checksumUrl -OutFile $checksum
            }
            $expected = ((Get-Content -LiteralPath $checksum -Raw) -split "\s+")[0].ToLowerInvariant()
            if ($expected -notmatch '^[0-9a-f]{64}$') {
                Fail "Invalid SHA-256 checksum for harness-windows-x64.exe: expected a 64-character hexadecimal digest"
            }
            $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $staged).Hash.ToLowerInvariant()
            if ($expected -ne $actual) { Fail "Checksum mismatch for harness-windows-x64.exe: expected $expected, got $actual" }
            $reportedVersion = ((& $staged --version) -split "\s+")[-1]
            if ($LASTEXITCODE -ne 0 -or $reportedVersion -ne $releaseTag.Substring(9)) {
                Fail "Harness core release identity mismatch: tag=$($releaseTag.Substring(9)), binary=$reportedVersion"
            }
        }

        $runner = $staged
        $arguments = @($command, "--directory", $script:TargetDir)
        if ($command -eq "update") { $arguments += "--candidate" }
        if ($pendingVersion) { $arguments += "--continue" }
        if ($DryRun) { $arguments += "--dry-run" }
        $target = $null
        $targetTemp = $null
        if (!$DryRun) {
            $target = Join-Path $script:TargetDir "scripts/bin/harness.exe"
            Assert-NotReparsePoint (Join-Path $script:TargetDir "scripts") "repository scripts directory"
            Assert-NotReparsePoint (Join-Path $script:TargetDir "scripts/bin") "repository scripts/bin directory"
            Assert-NotReparsePoint $target "repository Harness executable"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
            $targetTemp = Join-Path (Split-Path -Parent $target) (".harness." + [guid]::NewGuid().ToString("N") + ".tmp")
            Assert-NotReparsePoint $targetTemp "temporary Harness executable"
            Copy-Item -LiteralPath $staged -Destination $targetTemp
            if (Test-Path $target) {
                $backup = Join-Path $script:BackupDir "scripts/bin/harness.exe"
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
                Copy-Item -LiteralPath $target -Destination $backup -Force
            }
        }
        & $runner @arguments
        $commandStatus = $LASTEXITCODE
        if ($commandStatus -eq 2 -and !$DryRun) {
            $retained = Join-Path $script:TargetDir ".harness-core/update-candidate/harness.exe"
            Assert-NotReparsePoint (Join-Path $script:TargetDir ".harness-core") ".harness-core"
            Assert-NotReparsePoint (Join-Path $script:TargetDir ".harness-core/update-candidate") "retained candidate directory"
            Assert-NotReparsePoint $retained "retained update candidate"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $retained) | Out-Null
            Copy-Item -LiteralPath $staged -Destination $retained -Force
        }
        if ($commandStatus -eq 0 -and !$DryRun) {
            if (Test-Path $target) {
                $replaceBackup = Join-Path $script:BackupDir "scripts/bin/.harness-replace-backup.exe"
                [System.IO.File]::Replace($targetTemp, $target, $replaceBackup)
                Remove-Item -LiteralPath $replaceBackup -Force -ErrorAction SilentlyContinue
            } else {
                Move-Item -LiteralPath $targetTemp -Destination $target
            }
            Remove-Item -LiteralPath (Join-Path $script:TargetDir ".harness-core/update-candidate") -Recurse -Force -ErrorAction SilentlyContinue
            Merge-CoreGitignore (Join-Path $script:TargetDir ".gitignore")
            Write-Step "installed scripts/bin/harness.exe ($platform)"
        } elseif ($targetTemp) {
            Remove-Item -LiteralPath $targetTemp -Force -ErrorAction SilentlyContinue
        }
        if ($commandStatus -eq 2) { Fail "Harness core update needs resolution; edit .harness-core/update/resolved/, then rerun this installer or harness update --continue" }
        if ($commandStatus -ne 0) { Fail "harness $command failed with exit code $commandStatus" }
    } finally {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-EngineeringWisdom {
    if (!$WithEngineeringWisdom) { return }
    foreach ($file in (Get-PayloadFiles $script:EngineeringWisdomPayloadManifest)) {
        Copy-HarnessFile $file
    }
}

$script:Created = 0
$script:Updated = 0
$script:Skipped = 0
$script:Source = Get-SourceMode
$script:SourceBaseUrl = if ($env:HARNESS_SOURCE_BASE_URL) { $env:HARNESS_SOURCE_BASE_URL.TrimEnd("/") } else { "https://raw.githubusercontent.com/vtp772002/harness-by-victoria/main" }
$script:CoreSourceBaseUrl = if ($env:HARNESS_CORE_SOURCE_BASE_URL) { $env:HARNESS_CORE_SOURCE_BASE_URL.TrimEnd("/") } else { "https://raw.githubusercontent.com/vtp772002/harness-by-victoria/main" }
$script:PayloadManifest = "scripts/harness-install-files.txt"
$script:EngineeringWisdomPayloadManifest = "scripts/engineering-wisdom-install-files.txt"
$script:ClaudeSkillsPayloadManifest = "scripts/claude-skill-install-files.txt"
$script:TargetDir = Resolve-TargetPath $Directory
$backupRelative = ".harness-backup/" + [guid]::NewGuid().ToString("N")
$script:BackupDir = Join-Path $script:TargetDir $backupRelative
Assert-NoReparseComponents $backupRelative "Harness backup directory"
$script:ConflictAction = "install"

if ($Merge -and $Override) {
    Fail "Use only one of -Merge or -Override"
}

if (!$DryRun -and !(Test-Path $script:TargetDir)) {
    New-Item -ItemType Directory -Force -Path $script:TargetDir | Out-Null
}

$protectedPaths = @("AGENTS.md", "docs")
foreach ($protected in $protectedPaths) {
    Assert-NoReparseComponents $protected "protected Harness path $protected"
}
$conflicts = $protectedPaths | Where-Object {
    $item = Get-Item -LiteralPath (Join-Path $script:TargetDir $_) -Force -ErrorAction SilentlyContinue
    $null -ne $item
}
if ($conflicts.Count -gt 0) {
    if ($Merge) {
        $script:ConflictAction = "merge"
        Write-Step "Continuing with merge. Existing files will be skipped."
    } elseif ($Override) {
        $script:ConflictAction = "override"
        foreach ($protected in $protectedPaths) {
            $path = Join-Path $script:TargetDir $protected
            $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            if ($null -eq $item) { continue }
            if ($DryRun) {
                Write-Step "override $protected (backup first)"
            } else {
                New-Item -ItemType Directory -Force -Path $script:BackupDir | Out-Null
                Move-Item -LiteralPath $path -Destination (Join-Path $script:BackupDir $protected)
                Write-Step "removed  $protected (backup: $($script:BackupDir.Substring($script:TargetDir.Length + 1))/$protected)"
            }
        }
    } elseif ($Yes) {
        Fail "target already contains protected Harness paths: $($conflicts -join ', '). Use -Merge or -Override."
    } else {
        Write-Host "Warning: target already contains protected Harness paths: $($conflicts -join ', ')"
        $choice = Read-Host "Choose Merge, Override, or Stop [Stop]"
        switch -Regex ($choice) {
            "^(m|merge)$" { $script:ConflictAction = "merge"; Write-Step "Continuing with merge. Existing files will be skipped." }
            "^(o|override)$" {
                $script:ConflictAction = "override"
                foreach ($protected in $protectedPaths) {
                    $path = Join-Path $script:TargetDir $protected
                    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
                    if ($null -ne $item) {
                        New-Item -ItemType Directory -Force -Path $script:BackupDir | Out-Null
                        Move-Item -LiteralPath $path -Destination (Join-Path $script:BackupDir $protected)
                    }
                }
            }
            default { Fail "installation stopped" }
        }
    }
}

if ($script:Source.Mode -eq "local") {
    Write-Step "Harness source: $($script:Source.Root)"
} else {
    Write-Step "Harness source: $script:SourceBaseUrl"
}
Write-Step "Harness profile: core"
if ($WithEngineeringWisdom) {
    Write-Step "Engineering wisdom: included (explicit opt-in)"
} else {
    Write-Step "Engineering wisdom: excluded"
}
Write-Step "Target project: $script:TargetDir"

Install-HarnessCore

Install-EngineeringWisdom
Refresh-AgentShimFile
Write-ClaudeShim
Install-ClaudeSkills

Write-Step ""
Write-Step "Done. Created: $script:Created, updated: $script:Updated, skipped: $script:Skipped."
if ($script:Skipped -gt 0 -and !$Force) {
    Write-Step "Existing files were left untouched. Re-run with -Force to overwrite with backups."
}
if ($Force -and $script:Updated -gt 0 -and !$DryRun) {
    Write-Step "Backups were written to: $script:BackupDir"
}

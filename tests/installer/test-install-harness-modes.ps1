$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$Installer = Join-Path $Root "scripts/install-harness.ps1"
$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-installer-modes-" + [guid]::NewGuid())

& cargo build --quiet --manifest-path (Join-Path $Root "Cargo.toml") -p harness --locked
if (!$?) { throw "failed to build the core maintenance CLI" }
$env:HARNESS_CORE_BINARY = Join-Path $Root "target/debug/harness.exe"
$CoreVersion = ((& $env:HARNESS_CORE_BINARY --version) -split "\s+")[-1]

function Invoke-Install([string]$Directory, [string[]]$Mode = @()) {
    $Arguments = @{ Directory = $Directory; Yes = $true }
    foreach ($Name in $Mode) { $Arguments[$Name] = $true }
    & $Installer @Arguments | Out-Null
    if (!$?) { throw "installer failed for $Directory $Mode" }
}

function Assert-RejectedParameter([string]$Name, [object]$Value) {
    $Target = Join-Path $Temp ("rejected-" + $Name.ToLowerInvariant())
    $Arguments = @{ Directory = $Target; Yes = $true }
    $Arguments[$Name] = $Value
    $Accepted = $false
    try {
        & $Installer @Arguments | Out-Null
        $Accepted = $true
    } catch {
        # Parameter binding is expected to reject the removed protocol-v1 name.
    }
    if ($Accepted) { throw "installer unexpectedly accepted removed parameter -$Name" }
    if (Test-Path $Target) { throw "rejected parameter -$Name wrote its target" }
}

try {
    # Fresh install is core-only.
    $Fresh = Join-Path $Temp "fresh"
    Invoke-Install $Fresh
    if (!(Test-Path (Join-Path $Fresh "scripts/bin/harness.exe"))) { throw "core maintenance CLI missing" }
    if (!(Test-Path (Join-Path $Fresh ".harness-core/manifest.json"))) { throw "core provenance missing" }
    if (!(Test-Path (Join-Path $Fresh "docs/WORKFLOW.md"))) { throw "core workflow missing" }
    if (!(Test-Path (Join-Path $Fresh "docs/patterns/encoding-invariants.md"))) { throw "invariant pattern missing" }
    if (!(Test-Path (Join-Path $Fresh ".agents/skills/encode-invariant/SKILL.md"))) { throw "encode-invariant skill missing" }
    $FreshAgents = Get-Content -Raw (Join-Path $Fresh "AGENTS.md")
    if (!$FreshAgents.Contains("docs/patterns/encoding-invariants.md")) { throw "invariant routing missing" }
    $FreshWorkflow = Get-Content -Raw (Join-Path $Fresh "docs/WORKFLOW.md")
    if (!$FreshWorkflow.Contains("Does The Work Encode An Invariant?")) { throw "invariant workflow missing" }
    $FreshInvariantSkill = Get-Content -Raw (Join-Path $Fresh ".agents/skills/encode-invariant/SKILL.md")
    if (!$FreshInvariantSkill.Contains("prevent a documented violation from recurring")) { throw "invariant skill trigger missing" }
    foreach ($RequiredInvariantText in @(
        "Reuse the repository's existing test, build, task, lint, scan, or validation",
        "Choose the lowest deterministic layer that sees the complete accepted",
        "authority source, and a concrete compliant next action",
        "local validation command and observed result",
        "optional hook availability, if any",
        "CI invocation discovered or absent",
        "branch-protection enforcement verified or unverified"
    )) {
        if (!$FreshInvariantSkill.Contains($RequiredInvariantText)) { throw "invariant method missing: $RequiredInvariantText" }
    }
    $FreshInvariantMetadata = Get-Content -Raw (Join-Path $Fresh ".agents/skills/encode-invariant/agents/openai.yaml")
    if (!$FreshInvariantMetadata.Contains("allow_implicit_invocation: true")) { throw "invariant skill is not request-triggered" }
    $FreshOnboarding = Get-Content -Raw (Join-Path $Fresh ".agents/skills/onboard-repository/SKILL.md")
    if (!$FreshOnboarding.Contains("Compare documented invariants with executable checks")) { throw "onboarding invariant comparison missing" }
    $Gitignore = Get-Content -Raw (Join-Path $Fresh ".gitignore")
    if (!$Gitignore.Contains("scripts/bin/harness.exe")) { throw "core binary ignore rule missing" }
    if ($Gitignore.Contains("harness.db")) { throw "core install wrote database ignore rules" }
    foreach ($Legacy in @(
        "scripts/bin/harness-cli.exe",
        "scripts/bootstrap-harness.sh",
        "scripts/bootstrap-harness.ps1",
        "scripts/schema",
        "docs/contracts/harness-orchestration-v1.md",
        "harness.db"
    )) {
        if (Test-Path (Join-Path $Fresh $Legacy)) { throw "core install created legacy artifact $Legacy" }
    }
    if (Test-Path (Join-Path $Fresh ".agents/skills/engineering-wisdom")) { throw "core implicitly installed engineering wisdom" }

    # Engineering wisdom remains explicit-only.
    $Wisdom = Join-Path $Temp "wisdom"
    Invoke-Install $Wisdom @("WithEngineeringWisdom")
    if (!(Test-Path (Join-Path $Wisdom ".agents/skills/engineering-wisdom/SKILL.md"))) { throw "explicit engineering wisdom skill missing" }
    $WisdomAgent = Get-Content -Raw (Join-Path $Wisdom ".agents/skills/engineering-wisdom/agents/openai.yaml")
    if (!$WisdomAgent.Contains("allow_implicit_invocation: false")) { throw "engineering wisdom is not explicit-only" }

    # Force overwrites an opted-in advisory file and backs up the old bytes.
    $Force = Join-Path $Temp "force"
    New-Item -ItemType Directory -Force (Join-Path $Force ".agents/skills/engineering-wisdom") | Out-Null
    "consumer mutation" | Set-Content (Join-Path $Force ".agents/skills/engineering-wisdom/SKILL.md")
    Invoke-Install $Force @("WithEngineeringWisdom", "Force")
    if ((Get-Content -Raw (Join-Path $Force ".agents/skills/engineering-wisdom/SKILL.md")).Contains("consumer mutation")) { throw "force did not replace advisory file" }
    $ForceBackup = Get-ChildItem (Join-Path $Force ".harness-backup") -Recurse -Filter "SKILL.md" -File |
        Where-Object { $_.FullName -like "*engineering-wisdom*" } |
        Select-Object -First 1
    if (!$ForceBackup -or !(Get-Content -Raw $ForceBackup.FullName).Contains("consumer mutation")) { throw "force backup missing old advisory file" }

    # Merge fills core gaps while retaining every legacy artifact unchanged.
    $Merge = Join-Path $Temp "merge"
    New-Item -ItemType Directory -Force -Path @(
        (Join-Path $Merge "docs/contracts"),
        (Join-Path $Merge "scripts/schema"),
        (Join-Path $Merge "scripts/bin")
    ) | Out-Null
    "project agents" | Set-Content (Join-Path $Merge "AGENTS.md")
    "project harness" | Set-Content (Join-Path $Merge "docs/HARNESS.md")
    "legacy contract" | Set-Content (Join-Path $Merge "docs/contracts/harness-orchestration-v1.md")
    "legacy bootstrap" | Set-Content (Join-Path $Merge "scripts/bootstrap-harness.ps1")
    "legacy schema" | Set-Content (Join-Path $Merge "scripts/schema/001.sql")
    "legacy cli" | Set-Content (Join-Path $Merge "scripts/bin/harness-cli.exe")
    "legacy database" | Set-Content (Join-Path $Merge "harness.db")
    Invoke-Install $Merge @("Merge")
    if ((Get-Content -Raw (Join-Path $Merge "AGENTS.md")).Trim() -ne "project agents") { throw "merge replaced AGENTS.md" }
    if (!(Test-Path (Join-Path $Merge "docs/WORKFLOW.md"))) { throw "merge did not fill core payload" }
    foreach ($LegacyFile in @(
        [pscustomobject]@{ Path = "docs/contracts/harness-orchestration-v1.md"; Content = "legacy contract" },
        [pscustomobject]@{ Path = "scripts/bootstrap-harness.ps1"; Content = "legacy bootstrap" },
        [pscustomobject]@{ Path = "scripts/schema/001.sql"; Content = "legacy schema" },
        [pscustomobject]@{ Path = "scripts/bin/harness-cli.exe"; Content = "legacy cli" },
        [pscustomobject]@{ Path = "harness.db"; Content = "legacy database" }
    )) {
        if ((Get-Content -Raw (Join-Path $Merge $LegacyFile.Path)).Trim() -ne $LegacyFile.Content) { throw "merge changed legacy artifact $($LegacyFile.Path)" }
    }
    if ((Get-Content -Raw (Join-Path $Merge ".gitignore")).Contains("harness.db")) { throw "merge wrote database ignore rules" }

    # Override replaces and backs up AGENTS.md/docs, but leaves scripts alone.
    $Override = Join-Path $Temp "override"
    New-Item -ItemType Directory -Force (Join-Path $Override "docs"), (Join-Path $Override "scripts") | Out-Null
    "old agents" | Set-Content (Join-Path $Override "AGENTS.md")
    "old docs" | Set-Content (Join-Path $Override "docs/private.md")
    "old scripts" | Set-Content (Join-Path $Override "scripts/private.ps1")
    Invoke-Install $Override @("Override")
    $OverrideBackup = Get-ChildItem (Join-Path $Override ".harness-backup") -Directory | Select-Object -First 1
    if (!(Test-Path (Join-Path $OverrideBackup.FullName "AGENTS.md"))) { throw "override AGENTS backup missing" }
    if (!(Test-Path (Join-Path $OverrideBackup.FullName "docs/private.md"))) { throw "override docs backup missing" }
    if (Test-Path (Join-Path $Override "docs/private.md")) { throw "override retained replaced docs" }
    if ((Get-Content -Raw (Join-Path $Override "scripts/private.ps1")).Trim() -ne "old scripts") { throw "override changed scripts" }

    # Agent refresh preserves local text and replaces only the marked block.
    $Shim = Join-Path $Temp "shim"
    New-Item -ItemType Directory -Force (Join-Path $Shim "docs") | Out-Null
    "local rule`n`n<!-- HARNESS:BEGIN -->`nstale`n<!-- HARNESS:END -->" | Set-Content (Join-Path $Shim "AGENTS.md")
    $ShimHash = (Get-FileHash -Algorithm SHA256 (Join-Path $Shim "AGENTS.md")).Hash
    Invoke-Install $Shim @("Merge", "RefreshAgentShim")
    $ShimText = Get-Content -Raw (Join-Path $Shim "AGENTS.md")
    if (!$ShimText.Contains("local rule") -or $ShimText.Contains("stale") -or !$ShimText.Contains("No control-plane operation is required.")) { throw "shim refresh failed" }
    $ShimBackup = Get-ChildItem (Join-Path $Shim ".harness-backup") -Recurse -Filter "AGENTS.md" -File | Select-Object -First 1
    if (!$ShimBackup -or (Get-FileHash -Algorithm SHA256 $ShimBackup.FullName).Hash -ne $ShimHash) { throw "shim backup does not match prior AGENTS.md" }

    $Malformed = Join-Path $Temp "malformed"
    New-Item -ItemType Directory -Force (Join-Path $Malformed "docs") | Out-Null
    "custom`n<!-- HARNESS:BEGIN -->`nstale without end" | Set-Content (Join-Path $Malformed "AGENTS.md")
    $AcceptedMalformed = $false
    try {
        Invoke-Install $Malformed @("Merge", "RefreshAgentShim")
        $AcceptedMalformed = $true
    } catch {
        if (!$_.Exception.Message.Contains("exactly one complete Harness marker pair")) { throw }
    }
    if ($AcceptedMalformed) { throw "installer unexpectedly accepted malformed Harness markers" }

    # Dry-run does not create its target.
    $Dry = Join-Path $Temp "dry"
    & $Installer -Directory $Dry -Yes -DryRun | Out-Null
    if (Test-Path $Dry) { throw "dry-run wrote target" }

    # Removed protocol-v1 parameters fail during binding.
    Assert-RejectedParameter "WithCli" $true
    Assert-RejectedParameter "UpgradeCli" $true
    Assert-RejectedParameter "Ref" "harness-cli-v0.1.14"

    # Core writes refuse a scripts junction/reparse point.
    $SymlinkTarget = Join-Path $Temp "symlink-target"
    $SymlinkSink = Join-Path $Temp "symlink-sink"
    New-Item -ItemType Directory -Force $SymlinkTarget, $SymlinkSink | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $SymlinkTarget "scripts") -Target $SymlinkSink | Out-Null
    $AcceptedSymlink = $false
    try {
        Invoke-Install $SymlinkTarget
        $AcceptedSymlink = $true
    } catch {
        if (!$_.Exception.Message.Contains("refusing symlink or reparse point for repository scripts directory")) { throw }
    }
    if ($AcceptedSymlink) { throw "installer unexpectedly followed a scripts reparse point" }
    if (Get-ChildItem $SymlinkSink -Force | Select-Object -First 1) { throw "installer wrote through scripts reparse point" }

    # Remote bootstrap validates both checksum and release/binary identity.
    $RemoteInstaller = Join-Path $Temp "install-harness.ps1"
    Copy-Item $Installer $RemoteInstaller
    $CoreSource = Join-Path $Temp "core-source"
    $CoreAssets = Join-Path $Temp "core-assets"
    New-Item -ItemType Directory -Force (Join-Path $CoreSource "scripts"), $CoreAssets | Out-Null
    "harness-v$CoreVersion" | Set-Content -Encoding ascii (Join-Path $CoreSource "scripts/harness-release-tag")
    $CoreAsset = Join-Path $CoreAssets "harness-windows-x64.exe"
    Copy-Item $env:HARNESS_CORE_BINARY $CoreAsset
    $CoreHash = (Get-FileHash -Algorithm SHA256 $CoreAsset).Hash.ToLowerInvariant()
    "$($CoreHash.ToUpperInvariant())  harness-windows-x64.exe" | Set-Content -Encoding ascii "$CoreAsset.sha256"
    Remove-Item Env:HARNESS_CORE_BINARY
    $env:HARNESS_SOURCE_BASE_URL = ([uri]$Root).AbsoluteUri.TrimEnd("/")
    $env:HARNESS_CORE_SOURCE_BASE_URL = ([uri](Resolve-Path $CoreSource).Path).AbsoluteUri.TrimEnd("/")
    $env:HARNESS_CORE_CLI_BASE_URL = ([uri](Resolve-Path $CoreAssets).Path).AbsoluteUri.TrimEnd("/")
    $Remote = Join-Path $Temp "remote"
    & $RemoteInstaller -Directory $Remote -Yes | Out-Null
    if (!(Test-Path (Join-Path $Remote "scripts/bin/harness.exe"))) { throw "verified remote core binary missing" }

    "bad-checksum" | Set-Content -Encoding ascii "$CoreAsset.sha256"
    $AcceptedChecksum = $false
    try {
        & $RemoteInstaller -Directory (Join-Path $Temp "bad-checksum") -Yes | Out-Null
        $AcceptedChecksum = $true
    } catch {
        if (!$_.Exception.Message.Contains("Invalid SHA-256 checksum for harness-windows-x64.exe")) { throw }
    }
    if ($AcceptedChecksum) { throw "installer unexpectedly accepted a bad core checksum" }

    "$CoreHash  harness-windows-x64.exe" | Set-Content -Encoding ascii "$CoreAsset.sha256"
    "harness-v999.0.0" | Set-Content -Encoding ascii (Join-Path $CoreSource "scripts/harness-release-tag")
    $AcceptedIdentity = $false
    try {
        & $RemoteInstaller -Directory (Join-Path $Temp "bad-identity") -Yes | Out-Null
        $AcceptedIdentity = $true
    } catch {
        if (!$_.Exception.Message.Contains("Harness core release identity mismatch")) { throw }
    }
    if ($AcceptedIdentity) { throw "installer unexpectedly accepted a mismatched core version" }

    Write-Host "PowerShell core install, safety, shim, opt-in, and removed-parameter modes passed"
}
finally {
    Remove-Item Env:HARNESS_CORE_BINARY -ErrorAction SilentlyContinue
    Remove-Item Env:HARNESS_SOURCE_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:HARNESS_CORE_SOURCE_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:HARNESS_CORE_CLI_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $Temp -ErrorAction SilentlyContinue
}

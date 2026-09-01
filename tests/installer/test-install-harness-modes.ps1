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

    # The Claude shim is available through the PowerShell bootstrap with the
    # same canonical block, preservation, idempotence, and backup contract.
    $Claude = Join-Path $Temp "claude"
    New-Item -ItemType Directory -Force $Claude | Out-Null
    "# Local Claude Rules`n`nKeep this Claude-only rule.`n" | Set-Content (Join-Path $Claude "CLAUDE.md")
    $ClaudeBefore = (Get-FileHash -Algorithm SHA256 (Join-Path $Claude "CLAUDE.md")).Hash
    Invoke-Install $Claude @("Merge", "Claude")
    $ClaudeText = Get-Content -Raw (Join-Path $Claude "CLAUDE.md")
    if (!$ClaudeText.Contains("Keep this Claude-only rule.") -or !$ClaudeText.Contains("@AGENTS.md")) { throw "PowerShell Claude shim did not preserve or import canonical instructions" }
    $ClaudeBegin = ([regex]::Matches($ClaudeText, '<!-- HARNESS:BEGIN -->')).Count
    $ClaudeEnd = ([regex]::Matches($ClaudeText, '<!-- HARNESS:END -->')).Count
    if ($ClaudeBegin -ne 1 -or $ClaudeEnd -ne 1) { throw "PowerShell Claude shim marker count is not idempotent" }
    foreach ($Skill in @("audit-onboarding-proposal", "encode-invariant", "improve-harness", "onboard-repository")) {
        $ClaudeSkill = Join-Path $Claude ".claude/skills/$Skill/SKILL.md"
        if (!(Test-Path $ClaudeSkill)) { throw "PowerShell Claude skill wrapper missing: $Skill" }
        $ClaudeSkillText = Get-Content -Raw $ClaudeSkill
        if (!$ClaudeSkillText.Contains(".agents/skills/$Skill/SKILL.md")) { throw "PowerShell Claude skill wrapper is not canonical: $Skill" }
        if (!$ClaudeSkillText.Contains("<!-- HARNESS:CLAUDE-SKILL-WRAPPER:v1 -->")) { throw "PowerShell Claude skill wrapper marker missing: $Skill" }
    }
    if (Test-Path (Join-Path $Claude ".claude/skills/engineering-wisdom/SKILL.md")) { throw "engineering wisdom was not kept explicit-only" }
    $ClaudeBackup = Get-ChildItem (Join-Path $Claude ".harness-backup") -Recurse -Filter "CLAUDE.md" -File | Select-Object -First 1
    if (!$ClaudeBackup -or (Get-FileHash -Algorithm SHA256 $ClaudeBackup.FullName).Hash -ne $ClaudeBefore) { throw "PowerShell Claude shim backup does not match prior CLAUDE.md" }
    Invoke-Install $Claude @("Merge", "Claude")
    $ClaudeText = Get-Content -Raw (Join-Path $Claude "CLAUDE.md")
    if (([regex]::Matches($ClaudeText, '<!-- HARNESS:BEGIN -->')).Count -ne 1) { throw "PowerShell Claude shim is not idempotent" }

    $StaleClaudeSkill = Join-Path $Claude ".claude/skills/encode-invariant/SKILL.md"
    @(
        "<!-- HARNESS:CLAUDE-SKILL-WRAPPER:v1 -->"
        "# Claude Code compatibility loader"
        "stale wrapper"
    ) | Set-Content $StaleClaudeSkill
    Invoke-Install $Claude @("Merge", "Claude")
    $RefreshedClaudeSkill = Get-Content -Raw $StaleClaudeSkill
    if (!$RefreshedClaudeSkill.Contains("canonical skill is") -or $RefreshedClaudeSkill.Contains("stale wrapper")) { throw "PowerShell Claude skill wrapper was not refreshed from the canonical source" }
    $StaleClaudeBackup = Get-ChildItem (Join-Path $Claude ".harness-backup") -Recurse -Filter "SKILL.md" -File | Where-Object { $_.FullName -like "*encode-invariant*" } | Select-Object -First 1
    if (!$StaleClaudeBackup -or !(Get-Content -Raw $StaleClaudeBackup.FullName).Contains("stale wrapper")) { throw "PowerShell Claude skill wrapper backup is missing stale bytes" }

    $ConsumerClaudeSkill = Join-Path $Claude ".claude/skills/encode-invariant/SKILL.md"
    @(
        "# Claude Code compatibility loader"
        "consumer-owned policy"
    ) | Set-Content $ConsumerClaudeSkill
    $ConsumerClaudeSkillBefore = (Get-FileHash -Algorithm SHA256 $ConsumerClaudeSkill).Hash
    Invoke-Install $Claude @("Merge", "Claude")
    $ConsumerClaudeSkillAfter = (Get-FileHash -Algorithm SHA256 $ConsumerClaudeSkill).Hash
    if ($ConsumerClaudeSkillAfter -ne $ConsumerClaudeSkillBefore) { throw "PowerShell consumer skill with legacy heading was overwritten" }
    if ((Get-Content -Raw $ConsumerClaudeSkill).Contains("canonical skill is")) { throw "PowerShell consumer skill was treated as a marked wrapper" }

    # Copilot instructions are an opt-in compatibility loader. It appends one
    # canonical block, preserves local instructions, and backs up refreshes.
    $Copilot = Join-Path $Temp "copilot"
    New-Item -ItemType Directory -Force (Join-Path $Copilot ".github") | Out-Null
    "# Local Copilot Rules`n`nKeep this Copilot-only rule." | Set-Content (Join-Path $Copilot ".github/copilot-instructions.md")
    $CopilotBefore = (Get-FileHash -Algorithm SHA256 (Join-Path $Copilot ".github/copilot-instructions.md")).Hash
    Invoke-Install $Copilot @("Copilot", "Merge")
    $CopilotText = Get-Content -Raw (Join-Path $Copilot ".github/copilot-instructions.md")
    if (!$CopilotText.Contains("Keep this Copilot-only rule.") -or !$CopilotText.Contains("GitHub Copilot compatibility loader")) { throw "PowerShell Copilot loader did not preserve local instructions" }
    if (([regex]::Matches($CopilotText, '<!-- HARNESS:COPILOT-INSTRUCTIONS:BEGIN:v1 -->')).Count -ne 1) { throw "PowerShell Copilot loader marker is not idempotent" }
    $CopilotBackup = Get-ChildItem (Join-Path $Copilot ".harness-backup") -Recurse -Filter "copilot-instructions.md" -File | Select-Object -First 1
    if (!$CopilotBackup -or (Get-FileHash -Algorithm SHA256 $CopilotBackup.FullName).Hash -ne $CopilotBefore) { throw "PowerShell Copilot loader backup does not match prior instructions" }
    Invoke-Install $Copilot @("Copilot", "Merge")
    $CopilotText = Get-Content -Raw (Join-Path $Copilot ".github/copilot-instructions.md")
    if (([regex]::Matches($CopilotText, '<!-- HARNESS:COPILOT-INSTRUCTIONS:BEGIN:v1 -->')).Count -ne 1) { throw "PowerShell Copilot loader is not idempotent" }

    @(
        "# Copilot Repository Instructions"
        "<!-- HARNESS:COPILOT-INSTRUCTIONS:BEGIN:v1 -->"
        "stale"
        "<!-- HARNESS:COPILOT-INSTRUCTIONS:END:v1 -->"
    ) | Set-Content (Join-Path $Copilot ".github/copilot-instructions.md")
    Invoke-Install $Copilot @("Copilot", "Merge")
    $RefreshedCopilot = Get-Content -Raw (Join-Path $Copilot ".github/copilot-instructions.md")
    if (!$RefreshedCopilot.Contains("GitHub Copilot compatibility loader") -or $RefreshedCopilot.Contains("stale")) { throw "PowerShell Copilot loader was not refreshed" }

    @(
        "# GitHub Copilot compatibility loader"
        "consumer-owned policy"
    ) | Set-Content (Join-Path $Copilot ".github/copilot-instructions.md")
    Invoke-Install $Copilot @("Copilot", "Merge")
    $ConsumerCopilot = Get-Content -Raw (Join-Path $Copilot ".github/copilot-instructions.md")
    if (!$ConsumerCopilot.Contains("consumer-owned policy") -or !$ConsumerCopilot.Contains("GitHub Copilot compatibility loader")) { throw "PowerShell consumer Copilot instructions were replaced" }
    if (([regex]::Matches($ConsumerCopilot, '<!-- HARNESS:COPILOT-INSTRUCTIONS:BEGIN:v1 -->')).Count -ne 1) { throw "PowerShell consumer Copilot marker missing" }

    "# Copilot Repository Instructions`n<!-- HARNESS:COPILOT-INSTRUCTIONS:BEGIN:v1 -->`nstale without end" | Set-Content (Join-Path $Copilot ".github/copilot-instructions.md")
    $AcceptedMalformedCopilot = $false
    try {
        Invoke-Install $Copilot @("Copilot", "Merge")
        $AcceptedMalformedCopilot = $true
    } catch {
        if (!$_.Exception.Message.Contains("exactly one complete Copilot Harness marker pair")) { throw }
    }
    if ($AcceptedMalformedCopilot) { throw "PowerShell installer unexpectedly accepted malformed Copilot markers" }

    $ClaudeOptIn = Join-Path $Temp "claude-opt-in"
    Invoke-Install $ClaudeOptIn @("Claude", "WithEngineeringWisdom")
    if (!(Test-Path (Join-Path $ClaudeOptIn ".claude/skills/engineering-wisdom/SKILL.md"))) { throw "PowerShell Claude engineering-wisdom wrapper missing after explicit opt-in" }

    $MalformedClaude = Join-Path $Temp "malformed-claude"
    New-Item -ItemType Directory -Force $MalformedClaude | Out-Null
    "custom`n<!-- HARNESS:BEGIN -->`nstale without end" | Set-Content (Join-Path $MalformedClaude "CLAUDE.md")
    $AcceptedMalformedClaude = $false
    try {
        Invoke-Install $MalformedClaude @("Claude")
        $AcceptedMalformedClaude = $true
    } catch {
        if (!$_.Exception.Message.Contains("exactly one complete Harness marker pair")) { throw }
    }
    if ($AcceptedMalformedClaude) { throw "installer unexpectedly accepted malformed Claude markers" }

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

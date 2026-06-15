[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TargetOrg = "CCOE-Azure-Terraform",

    [string]$SourceOrg,

    [string]$SourceRepo,

    [string]$TargetRepo,

    [string]$EnvFile = ".env"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$NameFallbacks = @{
    AZURE_CLIENT_ID       = @("ARM_CLIENT_ID")
    AZURE_CLIENT_SECRET   = @("ARM_CLIENT_SECRET")
    AZURE_SUBSCRIPTION_ID = @("ARM_SUBSCRIPTION_ID")
    AZURE_TENANT_ID       = @("ARM_TENANT_ID")
}

function Normalize-OrgName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $normalized = $Name.Trim()

    if ($normalized -match '^[Tt]arget\s+[Oo]rg\s*:\s*(.+)$') {
        $normalized = $Matches[1].Trim()
    }

    return $normalized
}

function Get-RepoRoot {
    try {
        $repoRoot = (git rev-parse --show-toplevel).Trim()
        if (-not [string]::IsNullOrWhiteSpace($repoRoot)) {
            return $repoRoot
        }
    }
    catch {
    }

    return (Get-Location).Path
}

function Resolve-InputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $repoCandidate = Join-Path (Get-RepoRoot) $Path
    if (Test-Path -LiteralPath $repoCandidate) {
        return $repoCandidate
    }

    $cwdCandidate = Join-Path (Get-Location).Path $Path
    if (Test-Path -LiteralPath $cwdCandidate) {
        return $cwdCandidate
    }

    return $repoCandidate
}

function Get-OriginOrg {
    $originUrl = (git remote get-url origin).Trim()

    if ($originUrl -match '^https://github\.com/([^/]+)/') {
        return $Matches[1]
    }

    if ($originUrl -match '^git@github\.com:([^/]+)/') {
        return $Matches[1]
    }

    throw "Could not infer the source GitHub organization from origin URL: $originUrl"
}

function Get-OriginRepoName {
    $originUrl = (git remote get-url origin).Trim()

    if ($originUrl -match '^https://github\.com/[^/]+/([^/]+?)(?:\.git)?$') {
        return $Matches[1]
    }

    if ($originUrl -match '^git@github\.com:[^/]+/([^/]+?)(?:\.git)?$') {
        return $Matches[1]
    }

    throw "Could not infer the source GitHub repository name from origin URL: $originUrl"
}

function Assert-GhReady {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI 'gh' is not installed or not on PATH."
    }

    gh auth status | Out-Null
}

function Read-DotEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolvedPath = Resolve-InputPath -Path $Path

    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "Environment file not found: $resolvedPath"
    }

    $values = @{}

    foreach ($line in Get-Content -LiteralPath $resolvedPath) {
        $trimmed = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }

        if ($trimmed -notmatch '^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            continue
        }

        $name = $Matches[1]
        $value = $Matches[2].Trim()

        if (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))
        ) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $values[$name] = $value
    }

    return $values
}

function Get-GhJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & gh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI command failed: gh $($Arguments -join ' ')"
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        return $null
    }

    return $output | ConvertFrom-Json
}

function Get-GhLines {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & gh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI command failed: gh $($Arguments -join ' ')"
    }

    return @($output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-OrgSecretNames {
    param([string]$Org)

    return @(
        Get-GhLines @(
        "api", "--paginate",
        "orgs/$Org/actions/secrets",
        "--jq", ".secrets[]?.name"
        )
    )
}

function Get-OrgVariableNames {
    param([string]$Org)

    return @(
        Get-GhLines @(
        "api", "--paginate",
        "orgs/$Org/actions/variables",
        "--jq", ".variables[]?.name"
        )
    )
}

function Get-RepoSecretNames {
    param(
        [string]$Owner,
        [string]$Repo
    )

    return @(
        Get-GhLines @(
            "api", "--paginate",
            "repos/$Owner/$Repo/actions/secrets",
            "--jq", ".secrets[]?.name"
        )
    )
}

function Get-RepoVariableNames {
    param(
        [string]$Owner,
        [string]$Repo
    )

    return @(
        Get-GhLines @(
            "api", "--paginate",
            "repos/$Owner/$Repo/actions/variables",
            "--jq", ".variables[]?.name"
        )
    )
}

function Write-NameList {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [AllowNull()]
        [string[]]$Items
    )

    $Items = @($Items)

    Write-Host ""
    Write-Host $Title

    if ($Items.Count -eq 0) {
        Write-Host "  (none)"
        return
    }

    foreach ($item in ($Items | Sort-Object -Unique)) {
        Write-Host "  $item"
    }
}

function Get-OrgSecretDetail {
    param(
        [string]$Org,
        [string]$Name
    )

    return Get-GhJson @("api", "orgs/$Org/actions/secrets/$Name")
}

function Get-OrgVariableDetail {
    param(
        [string]$Org,
        [string]$Name
    )

    return Get-GhJson @("api", "orgs/$Org/actions/variables/$Name")
}

function Get-RepoSecretDetail {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Name
    )

    return Get-GhJson @("api", "repos/$Owner/$Repo/actions/secrets/$Name")
}

function Get-RepoVariableDetail {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Name
    )

    return Get-GhJson @("api", "repos/$Owner/$Repo/actions/variables/$Name")
}

function Get-SelectedRepoNamesForSecret {
    param(
        [string]$Org,
        [string]$Name
    )

    return @(
        Get-GhLines @(
        "api", "--paginate",
        "orgs/$Org/actions/secrets/$Name/repositories",
        "--jq", ".repositories[]?.name"
        )
    )
}

function Get-SelectedRepoNamesForVariable {
    param(
        [string]$Org,
        [string]$Name
    )

    return @(
        Get-GhLines @(
        "api", "--paginate",
        "orgs/$Org/actions/variables/$Name/repositories",
        "--jq", ".repositories[]?.name"
        )
    )
}

function Get-TargetRepoNames {
    param([string]$Org)

    return @(
        Get-GhLines @(
        "repo", "list", $Org,
        "--limit", "1000",
        "--json", "name",
        "--jq", ".[].name"
        )
    )
}

function Get-SharedRepoNames {
    param(
        [string[]]$SourceRepos,
        [string[]]$TargetRepos
    )

    return @($SourceRepos | Where-Object { $_ -in $TargetRepos } | Sort-Object -Unique)
}

function Get-EnvValueForName {
    param(
        [hashtable]$EnvValues,
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return [pscustomobject]@{
            Found      = $false
            SourceName = $null
            Value      = $null
        }
    }

    if ($EnvValues.ContainsKey($Name)) {
        return [pscustomobject]@{
            Found      = $true
            SourceName = $Name
            Value      = $EnvValues[$Name]
        }
    }

    $fallbackNames = @($NameFallbacks[$Name] | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    foreach ($fallbackName in $fallbackNames) {
        if (-not [string]::IsNullOrWhiteSpace($fallbackName) -and $EnvValues.ContainsKey($fallbackName)) {
            return [pscustomobject]@{
                Found      = $true
                SourceName = $fallbackName
                Value      = $EnvValues[$fallbackName]
            }
        }
    }

    return [pscustomobject]@{
        Found      = $false
        SourceName = $null
        Value      = $null
    }
}

function Get-MatchedNames {
    param(
        [string[]]$Names,
        [hashtable]$EnvValues
    )

    return @(
        $Names |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Where-Object { (Get-EnvValueForName -EnvValues $EnvValues -Name $_).Found } |
        Sort-Object -Unique
    )
}

function Get-UnmatchedNames {
    param(
        [string[]]$Names,
        [hashtable]$EnvValues
    )

    return @(
        $Names |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Where-Object { -not (Get-EnvValueForName -EnvValues $EnvValues -Name $_).Found } |
        Sort-Object -Unique
    )
}

function Assert-RepoExists {
    param(
        [string]$Owner,
        [string]$Repo
    )

    & gh repo view "$Owner/$Repo" --json nameWithOwner | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Repository '$Owner/$Repo' was not found or is not accessible."
    }
}

function Sync-OrgSecret {
    param(
        [string]$SourceOrg,
        [string]$TargetOrg,
        [string]$Name,
        [hashtable]$EnvValues,
        [string[]]$TargetRepos
    )

    $detail = Get-OrgSecretDetail -Org $SourceOrg -Name $Name
    $envMatch = Get-EnvValueForName -EnvValues $EnvValues -Name $Name
    if (-not $envMatch.Found) {
        throw "No matching value found in .env for org secret '$Name'."
    }
    $args = @("secret", "set", $Name, "--org", $TargetOrg, "--body", $envMatch.Value)

    if ($detail.visibility -eq "selected") {
        $sourceRepos = Get-SelectedRepoNamesForSecret -Org $SourceOrg -Name $Name
        $reposToUse = @($sourceRepos | Where-Object { $_ -in $TargetRepos } | Sort-Object -Unique)

        if ($reposToUse.Count -gt 0) {
            $args += @("--repos", ($reposToUse -join ","))
        }
        else {
            Write-Warning "Secret '$Name' uses selected repositories in '$SourceOrg', but no matching repos were found in '$TargetOrg'. Falling back to private visibility."
            $args += @("--visibility", "private")
        }
    }
    elseif ($detail.visibility) {
        $args += @("--visibility", [string]$detail.visibility)
    }

    if ($PSCmdlet.ShouldProcess("$TargetOrg/$Name", "Set GitHub organization secret")) {
        & gh @args
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set org secret '$Name' in '$TargetOrg'."
        }
    }
}

function Sync-OrgVariable {
    param(
        [string]$SourceOrg,
        [string]$TargetOrg,
        [string]$Name,
        [hashtable]$EnvValues,
        [string[]]$TargetRepos
    )

    $detail = Get-OrgVariableDetail -Org $SourceOrg -Name $Name
    $args = @("variable", "set", $Name, "--org", $TargetOrg, "--body", [string]$detail.value)

    if ($detail.visibility -eq "selected") {
        $sourceRepos = Get-SelectedRepoNamesForVariable -Org $SourceOrg -Name $Name
        $reposToUse = @($sourceRepos | Where-Object { $_ -in $TargetRepos } | Sort-Object -Unique)

        if ($reposToUse.Count -gt 0) {
            $args += @("--repos", ($reposToUse -join ","))
        }
        else {
            Write-Warning "Variable '$Name' uses selected repositories in '$SourceOrg', but no matching repos were found in '$TargetOrg'. Falling back to private visibility."
            $args += @("--visibility", "private")
        }
    }
    elseif ($detail.visibility) {
        $args += @("--visibility", [string]$detail.visibility)
    }

    if ($PSCmdlet.ShouldProcess("$TargetOrg/$Name", "Set GitHub organization variable")) {
        & gh @args
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set org variable '$Name' in '$TargetOrg'."
        }
    }
}

function Sync-RepoSecret {
    param(
        [string]$SourceOrg,
        [string]$SourceRepo,
        [string]$TargetOrg,
        [string]$TargetRepo,
        [string]$Name,
        [hashtable]$EnvValues
    )

    $null = Get-RepoSecretDetail -Owner $SourceOrg -Repo $SourceRepo -Name $Name
    $envMatch = Get-EnvValueForName -EnvValues $EnvValues -Name $Name
    if (-not $envMatch.Found) {
        throw "No matching value found in .env for repo secret '${SourceOrg}/${SourceRepo}:$Name'."
    }

    if ($PSCmdlet.ShouldProcess("$TargetOrg/$TargetRepo/$Name", "Set GitHub repository secret")) {
        & gh secret set $Name --repo "$TargetOrg/$TargetRepo" --body $envMatch.Value
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set repo secret '$Name' in '$TargetOrg/$TargetRepo'."
        }
    }
}

function Sync-RepoVariable {
    param(
        [string]$SourceOrg,
        [string]$SourceRepo,
        [string]$TargetOrg,
        [string]$TargetRepo,
        [string]$Name,
        [hashtable]$EnvValues
    )

    $detail = Get-RepoVariableDetail -Owner $SourceOrg -Repo $SourceRepo -Name $Name

    if ($PSCmdlet.ShouldProcess("$TargetOrg/$TargetRepo/$Name", "Set GitHub repository variable")) {
        & gh variable set $Name --repo "$TargetOrg/$TargetRepo" --body ([string]$detail.value)
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set repo variable '$Name' in '$TargetOrg/$TargetRepo'."
        }
    }
}

Assert-GhReady

if (-not $SourceOrg) {
    $SourceOrg = Get-OriginOrg
}

if (-not $SourceRepo) {
    $SourceRepo = Get-OriginRepoName
}

$SourceOrg = Normalize-OrgName -Name $SourceOrg
$TargetOrg = Normalize-OrgName -Name $TargetOrg
$SourceRepo = $SourceRepo.Trim()

if (-not $TargetRepo) {
    $TargetRepo = $SourceRepo
}

$TargetRepo = $TargetRepo.Trim()

$envValues = Read-DotEnv -Path $EnvFile
$sourceRepos = Get-TargetRepoNames -Org $SourceOrg
$targetRepos = Get-TargetRepoNames -Org $TargetOrg
Assert-RepoExists -Owner $SourceOrg -Repo $SourceRepo
Assert-RepoExists -Owner $TargetOrg -Repo $TargetRepo

$sharedRepoNames = Get-SharedRepoNames -SourceRepos $sourceRepos -TargetRepos $targetRepos

$orgSecretNames = Get-OrgSecretNames -Org $SourceOrg
$orgVariableNames = Get-OrgVariableNames -Org $SourceOrg
$targetOrgSecretNames = Get-OrgSecretNames -Org $TargetOrg
$targetOrgVariableNames = Get-OrgVariableNames -Org $TargetOrg

$repoScope = @{}
foreach ($repoName in $sharedRepoNames) {
    $sourceRepoSecrets = Get-RepoSecretNames -Owner $SourceOrg -Repo $repoName
    $sourceRepoVariables = Get-RepoVariableNames -Owner $SourceOrg -Repo $repoName
    $targetRepoSecrets = Get-RepoSecretNames -Owner $TargetOrg -Repo $repoName
    $targetRepoVariables = Get-RepoVariableNames -Owner $TargetOrg -Repo $repoName

    $repoScope[$repoName] = [pscustomobject]@{
        SourceSecrets    = @($sourceRepoSecrets)
        SourceVariables  = @($sourceRepoVariables)
        TargetSecrets    = @($targetRepoSecrets)
        TargetVariables  = @($targetRepoVariables)
        MatchedSecrets   = @(Get-MatchedNames -Names $sourceRepoSecrets -EnvValues $envValues)
        MatchedVariables = @($sourceRepoVariables | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
        UnmatchedSecrets = @(Get-UnmatchedNames -Names $sourceRepoSecrets -EnvValues $envValues)
        UnmatchedVars    = @()
    }
}

$matchedOrgSecrets = @(Get-MatchedNames -Names $orgSecretNames -EnvValues $envValues)
$matchedOrgVariables = @($orgVariableNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
$matchedRepoSecrets = @($repoScope.Values | ForEach-Object { $_.MatchedSecrets } | Sort-Object -Unique)
$matchedRepoVariables = @($repoScope.Values | ForEach-Object { $_.MatchedVariables } | Sort-Object -Unique)

Write-Host "Source org: $SourceOrg"
Write-Host "Source repo: $SourceRepo"
Write-Host "Target org: $TargetOrg"
Write-Host "Target repo: $TargetRepo"
Write-Host "Env file: $EnvFile"
Write-Host "Shared repos between source and target orgs: $($sharedRepoNames.Count)"
Write-Host "Matching org secrets: $($matchedOrgSecrets.Count)"
Write-Host "Matching org variables: $($matchedOrgVariables.Count)"
Write-Host "Matching repo secrets: $($matchedRepoSecrets.Count)"
Write-Host "Matching repo variables: $($matchedRepoVariables.Count)"
Write-NameList -Title "Env keys discovered:" -Items @($envValues.Keys)
Write-NameList -Title "Shared repos found in both orgs:" -Items $sharedRepoNames

Write-Host ""
Write-Host "=== Org Level ==="
Write-NameList -Title "Secrets in source org:" -Items $orgSecretNames
Write-NameList -Title "Secrets already in target org:" -Items $targetOrgSecretNames
Write-NameList -Title "Secrets to sync from ${EnvFile}:" -Items $matchedOrgSecrets
Write-NameList -Title "Variables in source org:" -Items $orgVariableNames
Write-NameList -Title "Variables already in target org:" -Items $targetOrgVariableNames
Write-NameList -Title "Variables to copy from source org:" -Items $matchedOrgVariables

foreach ($repoName in $sharedRepoNames) {
    $repoData = $repoScope[$repoName]
    Write-Host ""
    Write-Host "=== Repo: $repoName ==="
    Write-NameList -Title "Secrets in source repo:" -Items $repoData.SourceSecrets
    Write-NameList -Title "Secrets already in target repo:" -Items $repoData.TargetSecrets
    Write-NameList -Title "Secrets to sync from ${EnvFile}:" -Items $repoData.MatchedSecrets
    Write-NameList -Title "Variables in source repo:" -Items $repoData.SourceVariables
    Write-NameList -Title "Variables already in target repo:" -Items $repoData.TargetVariables
    Write-NameList -Title "Variables to copy from source repo:" -Items $repoData.MatchedVariables
}

foreach ($name in $matchedOrgSecrets) {
    Sync-OrgSecret -SourceOrg $SourceOrg -TargetOrg $TargetOrg -Name $name -EnvValues $envValues -TargetRepos $targetRepos
}

foreach ($name in $matchedOrgVariables) {
    Sync-OrgVariable -SourceOrg $SourceOrg -TargetOrg $TargetOrg -Name $name -EnvValues $envValues -TargetRepos $targetRepos
}

foreach ($repoName in $sharedRepoNames) {
    $repoData = $repoScope[$repoName]
    foreach ($name in $repoData.MatchedSecrets) {
        Sync-RepoSecret -SourceOrg $SourceOrg -SourceRepo $repoName -TargetOrg $TargetOrg -TargetRepo $repoName -Name $name -EnvValues $envValues
    }
    foreach ($name in $repoData.MatchedVariables) {
        Sync-RepoVariable -SourceOrg $SourceOrg -SourceRepo $repoName -TargetOrg $TargetOrg -TargetRepo $repoName -Name $name -EnvValues $envValues
    }
}

$unmatchedOrgSecretNames = @(Get-UnmatchedNames -Names $orgSecretNames -EnvValues $envValues)

if ($unmatchedOrgSecretNames.Count -gt 0) {
    Write-Host ""
    Write-Host "Org secrets skipped because no same-named value exists in ${EnvFile}:"
    $unmatchedOrgSecretNames | ForEach-Object { Write-Host "  $_" }
}

foreach ($repoName in $sharedRepoNames) {
    $repoData = $repoScope[$repoName]
    if (@($repoData.UnmatchedSecrets).Count -gt 0) {
        Write-Host ""
        Write-Host "Repo secrets skipped because no same-named value exists in ${EnvFile} [$repoName]:"
        $repoData.UnmatchedSecrets | ForEach-Object { Write-Host "  $_" }
    }
    if (@($repoData.UnmatchedVars).Count -gt 0) {
        Write-Host ""
        Write-Host "Repo variables skipped because no same-named value exists in ${EnvFile} [$repoName]:"
        $repoData.UnmatchedVars | ForEach-Object { Write-Host "  $_" }
    }
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Org secrets synced from ${EnvFile}: $($matchedOrgSecrets.Count)"
Write-Host "Org variables copied from source: $($matchedOrgVariables.Count)"
Write-Host "Repo secrets synced from ${EnvFile}: $($matchedRepoSecrets.Count)"
Write-Host "Repo variables copied from source: $($matchedRepoVariables.Count)"
Write-Host "Repo pairs processed: $($sharedRepoNames.Count)"

if ($unmatchedOrgSecretNames.Count -gt 0) {
    Write-Host "Org secrets skipped: $($unmatchedOrgSecretNames.Count)"
}

$repoSkippedSecrets = @($repoScope.Values | ForEach-Object { @($_.UnmatchedSecrets).Count } | Measure-Object -Sum)
if (($repoSkippedSecrets.Sum | ForEach-Object { $_ }) -gt 0) {
    Write-Host "Repo secrets skipped: $($repoSkippedSecrets.Sum)"
}

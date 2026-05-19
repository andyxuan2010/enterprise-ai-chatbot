[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SourceOrg,

    [string]$SourceRepo,

    [string]$TargetOrg = "CCOE-Azure-Terraform",

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

function Get-RepoVariableDetail {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Name
    )

    return Get-GhJson @("api", "repos/$Owner/$Repo/actions/variables/$Name")
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

function Write-NameList {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [AllowNull()]
        [object]$Items
    )

    $normalizedItems = @(
        foreach ($item in @($Items)) {
            if ($null -ne $item) {
                [string]$item
            }
        }
    )

    Write-Host ""
    Write-Host $Title

    if ($normalizedItems.Count -eq 0) {
        Write-Host "  (none)"
        return
    }

    foreach ($item in ($normalizedItems | Sort-Object -Unique)) {
        Write-Host "  $item"
    }
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

function Sync-RepoSecret {
    param(
        [string]$SourceOrg,
        [string]$SourceRepo,
        [string]$TargetOrg,
        [string]$TargetRepo,
        [string]$Name,
        [hashtable]$EnvValues
    )

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
        [string]$Name
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

Assert-RepoExists -Owner $SourceOrg -Repo $SourceRepo
Assert-RepoExists -Owner $TargetOrg -Repo $TargetRepo

$sourceRepoSecrets = Get-RepoSecretNames -Owner $SourceOrg -Repo $SourceRepo
$sourceRepoVariables = Get-RepoVariableNames -Owner $SourceOrg -Repo $SourceRepo
$targetRepoSecrets = Get-RepoSecretNames -Owner $TargetOrg -Repo $TargetRepo
$targetRepoVariables = Get-RepoVariableNames -Owner $TargetOrg -Repo $TargetRepo

$matchedSecrets = @(Get-MatchedNames -Names $sourceRepoSecrets -EnvValues $envValues)
$unmatchedSecrets = @(Get-UnmatchedNames -Names $sourceRepoSecrets -EnvValues $envValues)
$matchedVariables = @($sourceRepoVariables | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

Write-Host "Source repo: $SourceOrg/$SourceRepo"
Write-Host "Target repo: $TargetOrg/$TargetRepo"
Write-Host "Env file: $EnvFile"
Write-Host "Matching repo secrets: $($matchedSecrets.Count)"
Write-Host "Matching repo variables: $($matchedVariables.Count)"
Write-NameList -Title "Env keys discovered:" -Items @($envValues.Keys)

Write-Host ""
Write-Host "=== Repo Level ==="
Write-NameList -Title "Secrets in source repo:" -Items $sourceRepoSecrets
Write-NameList -Title "Secrets already in target repo:" -Items $targetRepoSecrets
Write-NameList -Title "Secrets to sync from ${EnvFile}:" -Items $matchedSecrets
Write-NameList -Title "Variables in source repo:" -Items $sourceRepoVariables
Write-NameList -Title "Variables already in target repo:" -Items $targetRepoVariables
Write-NameList -Title "Variables to copy from source repo:" -Items $matchedVariables

foreach ($name in $matchedSecrets) {
    Sync-RepoSecret -SourceOrg $SourceOrg -SourceRepo $SourceRepo -TargetOrg $TargetOrg -TargetRepo $TargetRepo -Name $name -EnvValues $envValues
}

foreach ($name in $matchedVariables) {
    Sync-RepoVariable -SourceOrg $SourceOrg -SourceRepo $SourceRepo -TargetOrg $TargetOrg -TargetRepo $TargetRepo -Name $name
}

if ($unmatchedSecrets.Count -gt 0) {
    Write-Host ""
    Write-Host "Repo secrets skipped because no same-named value exists in ${EnvFile}:"
    $unmatchedSecrets | ForEach-Object { Write-Host "  $_" }
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Repo secrets synced from ${EnvFile}: $($matchedSecrets.Count)"
Write-Host "Repo variables copied from source: $($matchedVariables.Count)"

if ($unmatchedSecrets.Count -gt 0) {
    Write-Host "Repo secrets skipped: $($unmatchedSecrets.Count)"
}

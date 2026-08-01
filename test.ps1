param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ChangedFiles
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesRoot = Join-Path $repoRoot "modules"

function Get-TargetModules {
  param(
    [string[]]$Files
  )

  if (-not $Files -or $Files.Count -eq 0) {
    return Get-ChildItem -Path $modulesRoot -Directory | Sort-Object Name
  }

  $moduleNames = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

  foreach ($file in $Files) {
    if ([string]::IsNullOrWhiteSpace($file)) {
      continue
    }

    $relativePath = $file -replace '/', '\'
    if (-not $relativePath.StartsWith("modules\")) {
      continue
    }

    $parts = $relativePath.Split('\', [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($parts.Length -lt 2) {
      continue
    }

    [void]$moduleNames.Add($parts[1])
  }

  if ($moduleNames.Count -eq 0) {
    return Get-ChildItem -Path $modulesRoot -Directory | Sort-Object Name
  }

  return @(
    $moduleNames |
      Sort-Object |
      ForEach-Object { Get-Item (Join-Path $modulesRoot $_) }
  )
}

$modules = @(Get-TargetModules -Files $ChangedFiles)

if (-not $modules -or $modules.Count -eq 0) {
  Write-Host "No Terraform modules selected for testing."
  exit 0
}

$failures = @()

foreach ($module in $modules) {
  Write-Host "====================================================" -ForegroundColor Cyan
  Write-Host "terraform test :: $($module.Name)" -ForegroundColor Cyan

  Push-Location $module.FullName
  try {
    terraform init -backend=false -input=false -no-color | Out-Null
    terraform test -no-color

    if ($LASTEXITCODE -ne 0) {
      $failures += $module.Name
    }
  }
  finally {
    Pop-Location
  }
}

if ($failures.Count -gt 0) {
  Write-Error ("terraform test failed for module(s): " + ($failures -join ", "))
}

Write-Host "All selected module tests passed." -ForegroundColor Green

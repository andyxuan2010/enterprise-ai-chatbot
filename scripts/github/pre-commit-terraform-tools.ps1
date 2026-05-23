param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('terraform-docs', 'tflint', 'trivy')]
    [string]$Tool
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$terraformRoot = Join-Path $repoRoot 'terraform'
Set-Location $terraformRoot

function Invoke-TerraformInit {
    $env:TF_PLUGIN_TIMEOUT = '200s'
    terraform init -backend=false -input=false -no-color | Out-Null
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

switch ($Tool) {
    'terraform-docs' {
        terraform-docs --config .terraform-docs.yml .
        exit $LASTEXITCODE
    }
    'tflint' {
        Invoke-TerraformInit
        tflint --init
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }

        $tflintHelp = tflint --help 2>&1 | Out-String
        if ($tflintHelp -match 'call-module-type') {
            tflint --chdir=. --call-module-type=all --format=compact --no-color
        }
        else {
            tflint --chdir=. --module --format=compact --no-color
        }
        exit $LASTEXITCODE
    }
    'trivy' {
        if (-not (Get-Command trivy -ErrorAction SilentlyContinue)) {
            Write-Error "trivy is not installed or not available on PATH."
        }

        Invoke-TerraformInit
        trivy config `
            --misconfig-scanners terraform `
            --severity HIGH,CRITICAL `
            --exit-code 1 `
            --format table `
            --tf-vars environments/dev/terraform.tfvars `
            --quiet `
            .
        exit $LASTEXITCODE
    }
}

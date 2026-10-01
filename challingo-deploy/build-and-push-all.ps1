# Build and push API, Web, and Worker images (reads deploy/api.env + web.env).
#
# Usage:
#   .\build-and-push-all.ps1
#   .\build-and-push-all.ps1 -SkipRegistryCheck
#   .\build-and-push-all.ps1 -SkipWorker

param(
    [switch]$SkipRegistryCheck,
    [switch]$SkipWorker
)

$ErrorActionPreference = 'Stop'
$DeployDir = $PSScriptRoot
. (Join-Path $DeployDir 'load-env.ps1')

function Write-GuiProgress {
    param([string]$Component, [string]$Phase, [string]$Status, [string]$Detail = '')
    $extra = if ($Detail) { " detail=$Detail" } else { '' }
    Write-Host "[gui-progress] component=$Component phase=$Phase status=$Status$extra"
}

$childSplat = @{}
if (-not $SkipRegistryCheck) {
    $cfg = Import-EnvFile (Join-Path $DeployDir 'api.env')
    $registry = $cfg['REGISTRY']
    if (-not $registry) { throw 'api.env must set REGISTRY' }
    Write-GuiProgress -Component registry -Phase check -Status running -Detail $registry
    Write-Host "→ Checking registry $registry …" -ForegroundColor Yellow
    Test-RegistryReachable -Reg $registry
    Assert-DockerInsecureRegistry -Reg $registry
    if ($env:SCAFFOLD_REGISTRY_USER -and $env:SCAFFOLD_REGISTRY_PASSWORD) {
        Connect-DockerRegistry -Reg $registry -Username $env:SCAFFOLD_REGISTRY_USER -Password $env:SCAFFOLD_REGISTRY_PASSWORD
    }
    Write-GuiProgress -Component registry -Phase check -Status done
    $childSplat['SkipRegistryCheck'] = $true
} else {
    $childSplat['SkipRegistryCheck'] = $true
}

Write-Host "=== Build and push all (challingo) ===" -ForegroundColor Cyan
Write-GuiProgress -Component pipeline -Phase start -Status running -Detail 'Build and push all images'

Write-GuiProgress -Component api -Phase start -Status running
& (Join-Path $DeployDir 'build-and-push-api.ps1') @childSplat
Write-GuiProgress -Component api -Phase start -Status done

Write-GuiProgress -Component web -Phase start -Status running
& (Join-Path $DeployDir 'build-and-push-web.ps1') @childSplat
Write-GuiProgress -Component web -Phase start -Status done

if (-not $SkipWorker) {
    $monorepoRoot = Split-Path $DeployDir -Parent
    $apiRoot = Join-Path $monorepoRoot 'challingo-api'
    $workerDockerfile = Join-Path (Join-Path $apiRoot 'Challingo.Worker') 'Dockerfile'
    if (Test-Path $workerDockerfile) {
        Write-GuiProgress -Component worker -Phase start -Status running
        & (Join-Path $DeployDir 'build-and-push-worker.ps1') @childSplat
        Write-GuiProgress -Component worker -Phase start -Status done
    } else {
        Write-Host "Skipping worker (no Dockerfile at $workerDockerfile)" -ForegroundColor Yellow
        Write-GuiProgress -Component worker -Phase start -Status skipped -Detail 'No worker Dockerfile'
    }
} else {
    Write-GuiProgress -Component worker -Phase start -Status skipped -Detail 'SkipWorker'
}

Write-Host ""
Write-Host "All images pushed. Syncing server-files/.env + staging ..." -ForegroundColor Cyan
Write-GuiProgress -Component sync -Phase env -Status running -Detail 'sync-server-env'
& (Join-Path $DeployDir 'sync-server-env.ps1')
$syncSt = Join-Path $DeployDir 'sync-server-env-staging.ps1'
if (Test-Path $syncSt) { & $syncSt }
Write-GuiProgress -Component sync -Phase env -Status done

Write-GuiProgress -Component pipeline -Phase start -Status done -Detail 'All images pushed and env synced'
Write-Host ""
Write-Host "Done. Copy server-files/ (and server-files-staging/) to VPS." -ForegroundColor Green
Write-Host "  Staging: ./server-up-staging.sh  →  https://staging.{domain}/  (or http://IP:81/)" -ForegroundColor DarkGray
Write-Host "  Prod:    ./server-up.sh          →  https://{domain}/" -ForegroundColor DarkGray
Write-Host "  Promote: ./promote-staging-to-prod.sh" -ForegroundColor DarkGray

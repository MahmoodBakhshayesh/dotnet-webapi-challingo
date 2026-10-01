# Build and push Worker image (reads deploy/api.env). Build context = challingo-api folder.

param(
    [switch]$SkipRegistryCheck
)

$ErrorActionPreference = 'Stop'
$DeployDir = $PSScriptRoot
. (Join-Path $DeployDir 'load-env.ps1')

function Write-GuiProgress {
    param([string]$Component, [string]$Phase, [string]$Status, [string]$Detail = '')
    $extra = if ($Detail) { " detail=$Detail" } else { '' }
    Write-Host "[gui-progress] component=$Component phase=$Phase status=$Status$extra"
}

$cfg = Import-EnvFile (Join-Path $DeployDir 'api.env')
$Tag = $cfg['TAG']
$Registry = $cfg['REGISTRY']
if (-not $Tag -or -not $Registry) { throw 'api.env must set TAG and REGISTRY' }

$DockerPrefix = 'challingo'
$Builder = "$DockerPrefix-builder"
$MonorepoRoot = Split-Path $DeployDir -Parent
$ApiRoot = Join-Path $MonorepoRoot 'challingo-api'
$Image = "$Registry/${DockerPrefix}-worker:$Tag"
$Dockerfile = Join-Path (Join-Path $ApiRoot 'Challingo.Worker') 'Dockerfile'

if (-not $SkipRegistryCheck) {
    Test-RegistryReachable -Reg $Registry
    Assert-DockerInsecureRegistry -Reg $Registry
}
if ($env:SCAFFOLD_REGISTRY_USER -and $env:SCAFFOLD_REGISTRY_PASSWORD) {
    Connect-DockerRegistry -Reg $Registry -Username $env:SCAFFOLD_REGISTRY_USER -Password $env:SCAFFOLD_REGISTRY_PASSWORD
}
Ensure-BuildxBuilder -BuilderName $Builder

if (-not (Test-Path $Dockerfile)) { throw "Missing Dockerfile: $Dockerfile" }

Write-Host "=== Worker $Image ===" -ForegroundColor Cyan
Push-Location $ApiRoot
try {
    Write-GuiProgress -Component worker -Phase build -Status running -Detail "Building $Image"
    Write-Host "→ Building Worker image…" -ForegroundColor Yellow
    docker buildx build --platform linux/amd64 -f $Dockerfile -t $Image --load .
    if ($LASTEXITCODE -ne 0) {
        Write-GuiProgress -Component worker -Phase build -Status failed
        throw 'build failed'
    }
    Write-GuiProgress -Component worker -Phase build -Status done

    Write-GuiProgress -Component worker -Phase push -Status running -Detail "Pushing $Image"
    Write-Host "→ Pushing Worker image…" -ForegroundColor Yellow
    try {
        Invoke-DockerPushWithRetry -Image $Image
    } catch {
        Write-GuiProgress -Component worker -Phase push -Status failed
        throw
    }
    Write-GuiProgress -Component worker -Phase push -Status done
} finally {
    Pop-Location
}

Write-Host "Done Worker. Run sync-server-env.ps1, copy server-files/ to VPS, run ./server-up.sh" -ForegroundColor Green

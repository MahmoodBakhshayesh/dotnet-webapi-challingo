# Build and push Web image (reads deploy/web.env).

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

$cfg = Import-EnvFile (Join-Path $DeployDir 'web.env')
$Tag = $cfg['TAG']
$Registry = $cfg['REGISTRY']
if (-not $Tag -or -not $Registry) { throw 'web.env must set TAG and REGISTRY' }

$DockerPrefix = 'challingo'
$MonorepoRoot = Split-Path $DeployDir -Parent
$WebRoot = Join-Path $MonorepoRoot 'challingo-web'
$Image = "$Registry/${DockerPrefix}-web:$Tag"
$Builder = "$DockerPrefix-builder"

$buildKeys = @(
    'NEXT_PUBLIC_API_URL', 'NEXT_PUBLIC_WS_URL', 'NEXT_PUBLIC_MAP_API_KEY',
    'NEXT_PUBLIC_MAP_USE_WMS', 'NEXT_PUBLIC_MAP_TILE_URL',
    'NEXT_PUBLIC_MAP_TILE_ATTRIBUTION',     'NEXT_PUBLIC_MAP_WMS_LAYERS', 'NEXT_PUBLIC_MAP_WMS_FORMAT', 'NEXT_PUBLIC_MAINTENANCE_MODE',
    'NEXT_PUBLIC_GOOGLE_CLIENT_ID'
)
$pairs = @()
foreach ($k in $buildKeys) {
    $v = if ($cfg.ContainsKey($k)) { $cfg[$k] } else { '' }
    $pairs += '--build-arg'; $pairs += "$k=$v"
}

if (-not $SkipRegistryCheck) {
    Test-RegistryReachable -Reg $Registry
    Assert-DockerInsecureRegistry -Reg $Registry
}
if ($env:SCAFFOLD_REGISTRY_USER -and $env:SCAFFOLD_REGISTRY_PASSWORD) {
    Connect-DockerRegistry -Reg $Registry -Username $env:SCAFFOLD_REGISTRY_USER -Password $env:SCAFFOLD_REGISTRY_PASSWORD
}
Ensure-BuildxBuilder -BuilderName $Builder

Write-Host "=== Web $Image ===" -ForegroundColor Cyan
Push-Location $WebRoot
try {
    Write-GuiProgress -Component web -Phase build -Status running -Detail "Building $Image"
    Write-Host "→ Building Web image…" -ForegroundColor Yellow
    $cmd = @('buildx', 'build', '--platform', 'linux/amd64', '-f', 'Dockerfile', '-t', $Image, '--load') + $pairs + '.'
    & docker @cmd
    if ($LASTEXITCODE -ne 0) {
        Write-GuiProgress -Component web -Phase build -Status failed
        throw 'build failed'
    }
    Write-GuiProgress -Component web -Phase build -Status done

    Write-GuiProgress -Component web -Phase push -Status running -Detail "Pushing $Image"
    Write-Host "→ Pushing Web image…" -ForegroundColor Yellow
    try {
        Invoke-DockerPushWithRetry -Image $Image
    } catch {
        Write-GuiProgress -Component web -Phase push -Status failed
        throw
    }
    Write-GuiProgress -Component web -Phase push -Status done
} finally {
    Pop-Location
}

Write-Host "Done Web. Run sync-server-env.ps1, copy server-files/ to VPS, run ./server-up.sh" -ForegroundColor Green

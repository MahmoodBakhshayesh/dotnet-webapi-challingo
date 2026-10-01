#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot publish prep: deploy api.env + web.env (ports, CORS, NEXT_PUBLIC_*), merge nginx server block.

.PARAMETER Domain
  Public production host, e.g. example.com (web at /, API at /api/).

.PARAMETER StagingDomain
  Public staging host (default staging.{Domain}). Separate hostname — not a path prefix.

.PARAMETER ApiPort
  Host port mapped to API container (docker compose API_HOST_PORT).

.PARAMETER WebPort
  Host port mapped to web container (WEB_HOST_PORT).

.PARAMETER PostgresPort
  Host port mapped to Postgres container (POSTGRES_HOST_PORT).

.PARAMETER TlsMode
  Http — serve on port 80 only (optional HTTPS redirect stub).
  Https — HTTP redirects to HTTPS; app on 443 with Let's Encrypt paths.

.PARAMETER NginxConfigPath
  Path to your VPS nginx.conf (updated in place; backup created).

.PARAMETER NginxPriority
  First — insert before other scaffold blocks (use for Http-only apps so HTTPS does not steal the host).
  Last — insert before certbot include (default).

.PARAMETER Registry
  Docker registry host:port for **push from dev** (sets REGISTRY in api.env and web.env). server-files/.env gets 127.0.0.1:port for VPS pull.

.PARAMETER Tag
  Image tag for api, web, and worker (sets TAG in api.env and web.env).

.PARAMETER Interactive
  Prompt for all settings (also the default when the script is run with no parameters).

.EXAMPLE
  .\Set-PublishSettings.ps1 -Domain example.com -ApiPort 8080 -WebPort 3000 -PostgresPort 5434 -TlsMode Http -NginxConfigPath C:\nginx\nginx.conf

.EXAMPLE
  .\Set-PublishSettings.ps1 -Domain mythezio.ir -ApiPort 8084 -WebPort 3004 -PostgresPort 5436 -TlsMode Https -NginxConfigPath /etc/nginx/nginx.conf -UploadMaxBodySize 50M
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Domain,

    [string]$StagingDomain = '',

    [int]$ApiPort = 0,

    [int]$WebPort = 0,

    [int]$PostgresPort = 0,

    [ValidateSet('Http', 'Https', '')]
    [string]$TlsMode = '',

    [string]$NginxConfigPath,

    [string]$DeployDir = $PSScriptRoot,

    [ValidateSet('First', 'Last')]
    [string]$NginxPriority = 'Last',

    [string]$UploadMaxBodySize = '50M',

    [string]$Registry = '',

    [string]$Tag = '',

    [ValidateSet('PreservePrefix', 'StripPrefix')]
    [string]$ApiProxyStyle = '',

    [switch]$SkipSync,

    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'load-env.ps1')

function Read-PublishPrompt {
    param(
        [string]$Label,
        [string]$Default = '',
        [switch]$Required
    )

    while ($true) {
        $suffix = if ($Default) { " [$Default]" } else { '' }
        $raw = Read-Host "$Label$suffix"
        if (-not $raw) {
            if ($Default) { return $Default }
            if (-not $Required) { return '' }
            Write-Host '  Value is required.' -ForegroundColor Yellow
            continue
        }
        return $raw.Trim()
    }
}

function Read-PublishChoice {
    param(
        [string]$Label,
        [string[]]$Choices,
        [string]$Default
    )

    $choicesText = ($Choices -join '/')
    while ($true) {
        $raw = Read-Host "$Label [$Default] ($choicesText)"
        if (-not $raw) { $raw = $Default }
        $match = $Choices | Where-Object { $_ -ieq $raw.Trim() } | Select-Object -First 1
        if ($match) { return $match }
        Write-Host "  Choose: $($Choices -join ', ')" -ForegroundColor Yellow
    }
}

function Read-PublishPort {
    param(
        [string]$Label,
        [string]$Default
    )

    while ($true) {
        $raw = Read-PublishPrompt -Label $Label -Default $Default -Required
        $port = 0
        if ([int]::TryParse($raw, [ref]$port) -and $port -gt 0 -and $port -le 65535) {
            return $port
        }
        Write-Host '  Enter a port number between 1 and 65535.' -ForegroundColor Yellow
    }
}

function Get-DefaultPublishDomain {
    param([hashtable]$ApiEnv)
    if (-not $ApiEnv.ContainsKey('Cors__AllowedOrigins__0')) { return '' }
    $origin = [string]$ApiEnv['Cors__AllowedOrigins__0']
    if (-not $origin) { return '' }
    $origin = $origin -replace '^https?://', ''
    $origin = $origin.TrimEnd('/')
    if ($origin.StartsWith('www.')) { $origin = $origin.Substring(4) }
    return $origin
}

function Initialize-PublishSettingsInteractive {
    param([string]$Dir)

    Write-Host ''
    Write-Host 'Publish settings wizard' -ForegroundColor Cyan
    Write-Host 'Press Enter to keep the value in [brackets].' -ForegroundColor DarkGray
    Write-Host ''

    $apiPath = Join-Path $Dir 'api.env'
    $webPath = Join-Path $Dir 'web.env'
    if (-not (Test-Path $apiPath)) { throw "Missing $apiPath" }
    if (-not (Test-Path $webPath)) { throw "Missing $webPath" }

    $api = Get-EnvFile $apiPath
    $web = Get-EnvFile $webPath

    $serverReg = ''
    $serverPath = Join-Path (Join-Path $Dir 'server-files') '.env'
    if (Test-Path $serverPath) {
        $server = Get-EnvFile $serverPath
        if ($server.ContainsKey('REGISTRY') -and $server['REGISTRY']) {
            $serverReg = $server['REGISTRY']
        }
    }

    $script:Domain = Read-PublishPrompt -Label 'Public domain (e.g. shop.example.com)' `
        -Default (Get-DefaultPublishDomain $api) -Required
    $defaultStag = if ($api.ContainsKey('PUBLISH_STAGING_DOMAIN') -and $api['PUBLISH_STAGING_DOMAIN']) {
        $api['PUBLISH_STAGING_DOMAIN']
    } else {
        "staging.$($script:Domain)"
    }
    $script:StagingDomain = Read-PublishPrompt -Label 'Staging domain (separate hostname)' `
        -Default $defaultStag
    $script:ApiPort = Read-PublishPort -Label 'API host port (API_HOST_PORT)' -Default $api['API_HOST_PORT']
    $script:WebPort = Read-PublishPort -Label 'Web host port (WEB_HOST_PORT)' -Default $web['WEB_HOST_PORT']
    $script:PostgresPort = Read-PublishPort -Label 'Postgres host port (POSTGRES_HOST_PORT)' -Default $api['POSTGRES_HOST_PORT']
    $script:TlsMode = Read-PublishChoice -Label 'TLS mode' -Choices @('Http', 'Https') -Default 'Http'
    $defaultNginx = Resolve-DefaultNginxConfigPath -DeployDir $Dir
    $script:NginxConfigPath = Read-PublishPrompt -Label 'Path to nginx.conf on this machine' `
        -Default $defaultNginx -Required

    $defaultReg = if ($api['REGISTRY']) { $api['REGISTRY'] } elseif ($serverReg) { $serverReg } else { '127.0.0.1:8585' }
    $script:Registry = Read-PublishPrompt -Label 'Docker registry (host:port)' -Default $defaultReg
    $script:Tag = Read-PublishPrompt -Label 'Image tag (api, web, worker)' -Default $api['TAG']
    $script:NginxPriority = Read-PublishChoice -Label 'Nginx block priority' -Choices @('First', 'Last') -Default $NginxPriority
    $script:UploadMaxBodySize = Read-PublishPrompt -Label 'Upload max body size' -Default $UploadMaxBodySize

    Write-Host ''
    Write-Host 'Summary:' -ForegroundColor Cyan
    Write-Host "  Domain:      $Domain"
    Write-Host "  API port:    $ApiPort"
    Write-Host "  Web port:    $WebPort"
    Write-Host "  Postgres:    $PostgresPort"
    Write-Host "  TLS:         $TlsMode"
    Write-Host "  Registry:    $Registry"
    Write-Host "  Tag:         $Tag"
    Write-Host "  Nginx:       $NginxConfigPath"
    Write-Host "  Nginx order: $NginxPriority"
    Write-Host "  Max upload:  $UploadMaxBodySize"
    Write-Host ''

    $confirm = Read-Host 'Apply these settings? [Y/n]'
    if ($confirm -match '^[nN]') { throw 'Cancelled by user.' }
}

function Assert-PublishSettingsParams {
    if (-not $Domain) { throw 'Domain is required. Run without parameters for the interactive wizard, or pass -Domain.' }
    if ($ApiPort -le 0) { throw 'ApiPort is required. Run without parameters for the interactive wizard, or pass -ApiPort.' }
    if ($WebPort -le 0) { throw 'WebPort is required. Run without parameters for the interactive wizard, or pass -WebPort.' }
    if ($PostgresPort -le 0) { throw 'PostgresPort is required. Run without parameters for the interactive wizard, or pass -PostgresPort.' }
    if (-not $TlsMode) { throw 'TlsMode is required (Http or Https). Run without parameters for the interactive wizard, or pass -TlsMode.' }
    if (-not $NginxConfigPath) {
        throw 'NginxConfigPath is required. Run without parameters for the interactive wizard, pass -NginxConfigPath, or link deploy folder via New-Project/Update-Project (writes .scaffold-nginx-path).'
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Normalize-Registry {
    param([string]$Value)
    $r = $Value.Trim()
    $r = $r -replace '^https?://', ''
    $r = $r.TrimEnd('/')
    return $r
}

function Get-RegistryHostPort {
    param([string]$Registry)
    if ($Registry -match ':(\d+)$') { return $Matches[1] }
    return '8585'
}

function Normalize-Domain {
    param([string]$Value)
    $d = $Value.Trim().ToLowerInvariant()
    $d = $d -replace '^https?://', ''
    $d = $d.TrimEnd('/')
    if ($d.StartsWith('www.')) {
        $d = $d.Substring(4)
    }
    return $d
}

function Get-ProjectSlug {
    param([string]$Dir, [hashtable]$ApiEnv)
    if ($ApiEnv.ContainsKey('POSTGRES_DB') -and $ApiEnv['POSTGRES_DB']) {
        return $ApiEnv['POSTGRES_DB']
    }
    $name = Split-Path $Dir -Leaf
    return ($name -replace '-deploy$', '').Replace('-', '')
}

function Get-CorsOrigins {
    param([string]$Domain, [string]$Mode)
    $origins = [System.Collections.Generic.List[string]]::new()
    $add = {
        param($u)
        if ($origins -notcontains $u) { $origins.Add($u) }
    }

    if ($Mode -eq 'Https') {
        & $add "https://$Domain"
        & $add "https://www.$Domain"
        & $add "http://$Domain"
        & $add "http://www.$Domain"
    } else {
        & $add "http://$Domain"
        & $add "http://www.$Domain"
    }

    & $add 'http://127.0.0.1:3000'
    & $add 'http://localhost:3000'
    return $origins
}

function Get-PublicApiUrl {
    param([string]$Domain, [string]$Mode)
    # Relative path — same web image on prod and staging hosts (each proxies /api to its API).
    return '/api'
}

function New-NginxProjectBlock {
    param(
        [string]$Slug,
        [string]$Domain,
        [string]$StagingDomain = '',
        [int]$ApiPort,
        [int]$WebPort,
        [string]$TlsMode,
        [string]$UploadMaxBodySize,
        [string]$ApiProxyStyle,
        [int]$StagingApiPort = 0,
        [int]$StagingWebPort = 0
    )

    # Separate hostnames for prod / staging (mirrored by gui/lib/RemoteDomain.ps1).

    if ($StagingApiPort -le 0) { $StagingApiPort = $ApiPort + 1 }
    if ($StagingWebPort -le 0) { $StagingWebPort = $WebPort + 1 }
    if (-not $StagingDomain) { $StagingDomain = "staging.$Domain" }

    $webUpstream = "${Slug}_web"
    $apiUpstream = "${Slug}_api"
    $webStagingUpstream = "${Slug}_web_staging"
    $apiStagingUpstream = "${Slug}_api_staging"
    $apiPass = if ($ApiProxyStyle -eq 'StripPrefix') { "http://${apiUpstream}/" } else { "http://${apiUpstream}" }
    $apiPassStag = if ($ApiProxyStyle -eq 'StripPrefix') { "http://${apiStagingUpstream}/" } else { "http://${apiStagingUpstream}" }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("    # SCAFFOLD_BEGIN: $Slug")
    [void]$sb.AppendLine("    # =============================================================================")
    [void]$sb.AppendLine("    # $Domain (prod) / $StagingDomain (staging) - $Slug")
    [void]$sb.AppendLine("    #   $Domain/              -> 127.0.0.1:$WebPort")
    [void]$sb.AppendLine("    #   $Domain/api/          -> 127.0.0.1:$ApiPort")
    [void]$sb.AppendLine("    #   $StagingDomain/       -> 127.0.0.1:$StagingWebPort")
    [void]$sb.AppendLine("    #   $StagingDomain/api/   -> 127.0.0.1:$StagingApiPort")
    [void]$sb.AppendLine("    # =============================================================================")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    upstream $webUpstream {")
    [void]$sb.AppendLine("        server 127.0.0.1:$WebPort;")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("    upstream $apiUpstream {")
    [void]$sb.AppendLine("        server 127.0.0.1:$ApiPort;")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("    upstream $webStagingUpstream {")
    [void]$sb.AppendLine("        server 127.0.0.1:$StagingWebPort;")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("    upstream $apiStagingUpstream {")
    [void]$sb.AppendLine("        server 127.0.0.1:$StagingApiPort;")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("")

    function Append-VhostShell {
        param(
            [System.Text.StringBuilder]$Builder,
            [string]$ServerNames,
            [string]$CertDomain,
            [string]$WebUp,
            [string]$ApiPassValue,
            [string]$ApiUp,
            [string]$Mode,
            [string]$BodySize,
            [switch]$IncludeHttpRedirectStub
        )
        if ($Mode -eq 'Http') {
            if ($IncludeHttpRedirectStub) {
                [void]$Builder.AppendLine("    server {")
                [void]$Builder.AppendLine("        listen 443 ssl http2;")
                [void]$Builder.AppendLine("        server_name $ServerNames;")
                [void]$Builder.AppendLine("")
                [void]$Builder.AppendLine("        ssl_certificate /etc/nginx/ssl/${Slug}-redirect.crt;")
                [void]$Builder.AppendLine("        ssl_certificate_key /etc/nginx/ssl/${Slug}-redirect.key;")
                [void]$Builder.AppendLine("")
                [void]$Builder.AppendLine("        return 301 http://$CertDomain`$request_uri;")
                [void]$Builder.AppendLine("    }")
                [void]$Builder.AppendLine("")
            }
            if ($ServerNames -match 'www\.') {
                $apex = ($ServerNames -split '\s+') | Where-Object { $_ -notmatch '^www\.' } | Select-Object -First 1
                if ($apex) {
                    [void]$Builder.AppendLine("    server {")
                    [void]$Builder.AppendLine("        listen 80;")
                    [void]$Builder.AppendLine("        server_name www.$apex;")
                    [void]$Builder.AppendLine("        return 301 http://$apex`$request_uri;")
                    [void]$Builder.AppendLine("    }")
                    [void]$Builder.AppendLine("")
                }
            }
            [void]$Builder.AppendLine("    server {")
            [void]$Builder.AppendLine("        listen 80;")
            [void]$Builder.AppendLine("        server_name $CertDomain;")
        } else {
            [void]$Builder.AppendLine("    server {")
            [void]$Builder.AppendLine("        listen 80;")
            [void]$Builder.AppendLine("        server_name $ServerNames;")
            [void]$Builder.AppendLine("        return 301 https://`$host`$request_uri;")
            [void]$Builder.AppendLine("    }")
            [void]$Builder.AppendLine("")
            [void]$Builder.AppendLine("    server {")
            [void]$Builder.AppendLine("        listen 443 ssl http2;")
            [void]$Builder.AppendLine("        server_name $ServerNames;")
            [void]$Builder.AppendLine("")
            [void]$Builder.AppendLine("        ssl_certificate /etc/letsencrypt/live/$CertDomain/fullchain.pem;")
            [void]$Builder.AppendLine("        ssl_certificate_key /etc/letsencrypt/live/$CertDomain/privkey.pem;")
            [void]$Builder.AppendLine("        include /etc/letsencrypt/options-ssl-nginx.conf;")
            [void]$Builder.AppendLine("        ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;")
        }

        [void]$Builder.AppendLine("")
        [void]$Builder.AppendLine("        client_max_body_size $BodySize;")
        [void]$Builder.AppendLine("        gzip on;")
        [void]$Builder.AppendLine("        gzip_types text/plain text/css application/json application/javascript text/xml application/xml image/svg+xml;")
        [void]$Builder.AppendLine("        gzip_min_length 1024;")
        [void]$Builder.AppendLine("")
        [void]$Builder.AppendLine("        location ^~ /api/ {")
        [void]$Builder.AppendLine("            proxy_pass $ApiPassValue;")
        [void]$Builder.AppendLine("            proxy_http_version 1.1;")
        [void]$Builder.AppendLine("            proxy_connect_timeout 120s;")
        [void]$Builder.AppendLine("            proxy_send_timeout 600s;")
        [void]$Builder.AppendLine("            proxy_read_timeout 600s;")
        [void]$Builder.AppendLine("            proxy_set_header Host `$host;")
        [void]$Builder.AppendLine("            proxy_set_header X-Real-IP `$remote_addr;")
        [void]$Builder.AppendLine("            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;")
        if ($Mode -eq 'Https') {
            [void]$Builder.AppendLine("            proxy_set_header X-Forwarded-Proto https;")
        } else {
            [void]$Builder.AppendLine("            proxy_set_header X-Forwarded-Proto `$scheme;")
        }
        [void]$Builder.AppendLine("            proxy_set_header Upgrade `$http_upgrade;")
        [void]$Builder.AppendLine("            proxy_set_header Connection `$connection_upgrade;")
        [void]$Builder.AppendLine("        }")
        [void]$Builder.AppendLine("")
        [void]$Builder.AppendLine("        location ^~ /uploads/ {")
        [void]$Builder.AppendLine("            proxy_pass http://${ApiUp}/uploads/;")
        [void]$Builder.AppendLine("            proxy_http_version 1.1;")
        [void]$Builder.AppendLine("            proxy_connect_timeout 120s;")
        [void]$Builder.AppendLine("            proxy_read_timeout 600s;")
        [void]$Builder.AppendLine("            proxy_set_header Host `$host;")
        [void]$Builder.AppendLine("            proxy_set_header X-Real-IP `$remote_addr;")
        [void]$Builder.AppendLine("            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;")
        if ($Mode -eq 'Https') {
            [void]$Builder.AppendLine("            proxy_set_header X-Forwarded-Proto https;")
        } else {
            [void]$Builder.AppendLine("            proxy_set_header X-Forwarded-Proto `$scheme;")
        }
        [void]$Builder.AppendLine("        }")
        [void]$Builder.AppendLine("")
        [void]$Builder.AppendLine("        location / {")
        [void]$Builder.AppendLine("            proxy_pass http://${WebUp};")
        [void]$Builder.AppendLine("            proxy_http_version 1.1;")
        [void]$Builder.AppendLine("            proxy_connect_timeout 60s;")
        [void]$Builder.AppendLine("            proxy_read_timeout 120s;")
        [void]$Builder.AppendLine("            proxy_set_header Host `$host;")
        [void]$Builder.AppendLine("            proxy_set_header X-Real-IP `$remote_addr;")
        [void]$Builder.AppendLine("            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;")
        if ($Mode -eq 'Https') {
            [void]$Builder.AppendLine("            proxy_set_header X-Forwarded-Proto https;")
        } else {
            [void]$Builder.AppendLine("            proxy_set_header X-Forwarded-Proto `$scheme;")
        }
        [void]$Builder.AppendLine("            proxy_set_header Upgrade `$http_upgrade;")
        [void]$Builder.AppendLine("            proxy_set_header Connection `$connection_upgrade;")
        [void]$Builder.AppendLine("        }")
        [void]$Builder.AppendLine("    }")
        [void]$Builder.AppendLine("")
    }

    Append-VhostShell -Builder $sb -ServerNames "$Domain www.$Domain" -CertDomain $Domain `
        -WebUp $webUpstream -ApiPassValue $apiPass -ApiUp $apiUpstream -Mode $TlsMode `
        -BodySize $UploadMaxBodySize -IncludeHttpRedirectStub

    Append-VhostShell -Builder $sb -ServerNames $StagingDomain -CertDomain $StagingDomain `
        -WebUp $webStagingUpstream -ApiPassValue $apiPassStag -ApiUp $apiStagingUpstream -Mode $TlsMode `
        -BodySize $UploadMaxBodySize

    [void]$sb.AppendLine("    # SCAFFOLD_END: $Slug")

    return $sb.ToString()
}

function Update-NginxConfig {
    param(
        [string]$Path,
        [string]$Slug,
        [string]$Block,
        [string]$Priority
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $begin = "    # SCAFFOLD_BEGIN: $Slug"
    $end = "    # SCAFFOLD_END: $Slug"

    if ($content -match [regex]::Escape($begin)) {
        $pattern = "(?s)$([regex]::Escape($begin)).*?$([regex]::Escape($end))"
        $content = [regex]::Replace($content, $pattern, $Block.TrimEnd())
        return $content
    }

    # Remove legacy upstream-only lines if re-adding full block
    $content = [regex]::Replace($content, "(?m)^\s*upstream ${Slug}_web \{[^}]+\}\s*\r?\n", '')
    $content = [regex]::Replace($content, "(?m)^\s*upstream ${Slug}_api \{[^}]+\}\s*\r?\n", '')

    $insertBefore = $null
    if ($Priority -eq 'First') {
        if ($content -match '(?m)^\s*# SCAFFOLD_BEGIN:') {
            $insertBefore = $Matches[0]
        } elseif ($content -match '(?m)^\s*# ={5,}') {
            $insertBefore = $Matches[0]
        }
    }

    if (-not $insertBefore) {
        if ($content -match '(?m)^\s*include /etc/nginx/conf\.d/\*\.conf;') {
            $insertBefore = $Matches[0]
        } else {
            throw 'Could not find insert point (include /etc/nginx/conf.d/*.conf;) in nginx.conf'
        }
    }

    $idx = $content.IndexOf($insertBefore)
    if ($idx -lt 0) { throw "Insert marker not found: $insertBefore" }

    return $content.Insert($idx, "`n$Block`n")
}

# --- main ---

if (-not $NginxConfigPath) {
    $NginxConfigPath = Resolve-DefaultNginxConfigPath -DeployDir $DeployDir
}

if ($Interactive -or $PSBoundParameters.Count -eq 0) {
    Initialize-PublishSettingsInteractive -Dir $DeployDir
} else {
    Assert-PublishSettingsParams
}

$domain = Normalize-Domain $Domain
$stagingDomain = if ($StagingDomain) { Normalize-Domain $StagingDomain } else { "staging.$domain" }
$nginxPath = (Resolve-Path -LiteralPath $NginxConfigPath).Path
$apiEnvPath = Join-Path $DeployDir 'api.env'
$webEnvPath = Join-Path $DeployDir 'web.env'

if (-not (Test-Path $apiEnvPath)) { throw "Missing $apiEnvPath" }
if (-not (Test-Path $webEnvPath)) { throw "Missing $webEnvPath" }

$apiEnv = Get-EnvFile $apiEnvPath
$slug = Get-ProjectSlug -Dir $DeployDir -ApiEnv $apiEnv

if (-not $ApiProxyStyle) {
    $ApiProxyStyle = 'PreservePrefix'
}

$publicApi = Get-PublicApiUrl -Domain $domain -Mode $TlsMode
$cors = Get-CorsOrigins -Domain $domain -Mode $TlsMode

$apiUpdates = @{
    API_HOST_PORT      = "$ApiPort"
    POSTGRES_HOST_PORT = "$PostgresPort"
}
for ($i = 0; $i -lt $cors.Count; $i++) {
    $apiUpdates["Cors__AllowedOrigins__$i"] = $cors[$i]
}

# Rotate known JWT placeholders to a per-project random key (256-bit).
$jwtPlaceholders = @(
    'change-me-use-at-least-32-characters-long-secret',
    '1234564646466466544464456664656664646465445',
    'IYUPGgTk19+IPaQVK/4xugkHKfSF4mrPptMdzYfDI38=',
    ''
)
$currentJwt = if ($apiEnv.ContainsKey('Jwt__Key')) { [string]$apiEnv['Jwt__Key'] } else { '' }
if ($jwtPlaceholders -contains $currentJwt -or $currentJwt.Length -lt 32) {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $apiUpdates['Jwt__Key'] = [Convert]::ToBase64String($bytes)
    Write-Host "  Generated new Jwt__Key (previous value was missing or a template placeholder)" -ForegroundColor DarkYellow
}

$webUpdates = @{
    WEB_HOST_PORT           = "$WebPort"
    NEXT_PUBLIC_API_URL     = $publicApi
    NEXT_PUBLIC_WS_URL      = $publicApi
}

# Persist public domain for GUI round-trip (NEXT_PUBLIC_API_URL may be relative "/api").
$apiUpdates['PUBLISH_DOMAIN'] = $domain
$apiUpdates['PUBLISH_STAGING_DOMAIN'] = $stagingDomain
$webUpdates['PUBLISH_DOMAIN'] = $domain
$webUpdates['PUBLISH_STAGING_DOMAIN'] = $stagingDomain

if ($Tag) {
    $apiUpdates['TAG'] = $Tag.Trim()
    $webUpdates['TAG'] = $Tag.Trim()
}

if ($Registry) {
    $reg = Normalize-Registry $Registry
    $apiUpdates['REGISTRY'] = $reg
    $webUpdates['REGISTRY'] = $reg
}

Write-Host "Publish settings for $slug ($domain / staging $stagingDomain)" -ForegroundColor Cyan
Write-Host "  API host port: $ApiPort  Web host port: $WebPort  Postgres port: $PostgresPort  TLS: $TlsMode" -ForegroundColor DarkGray
Write-Host "  Public API URL: $publicApi" -ForegroundColor DarkGray
if ($Tag) { Write-Host "  Image tag: $Tag" -ForegroundColor DarkGray }
if ($Registry) { Write-Host "  Registry: $(Normalize-Registry $Registry)" -ForegroundColor DarkGray }
Write-Host "  Nginx: $nginxPath (priority $NginxPriority)" -ForegroundColor DarkGray

if ($WhatIf) {
    Write-Host "[WhatIf] Would update api.env, web.env, nginx.conf" -ForegroundColor DarkCyan
    return
}

Remove-EnvFileKeys -Path $apiEnvPath -KeyPatterns @('Cors__AllowedOrigins__*')
Set-EnvFileValues -Path $apiEnvPath -Updates $apiUpdates
Set-EnvFileValues -Path $webEnvPath -Updates $webUpdates
Write-Host "Updated api.env and web.env" -ForegroundColor Green

$block = New-NginxProjectBlock -Slug $slug -Domain $domain -StagingDomain $stagingDomain -ApiPort $ApiPort -WebPort $WebPort `
    -TlsMode $TlsMode -UploadMaxBodySize $UploadMaxBodySize -ApiProxyStyle $ApiProxyStyle `
    -StagingApiPort ($ApiPort + 1) -StagingWebPort ($WebPort + 1)

$backup = "$nginxPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -LiteralPath $nginxPath -Destination $backup -Force
Write-Host "Backup: $backup" -ForegroundColor DarkGray

$newNginx = Update-NginxConfig -Path $nginxPath -Slug $slug -Block $block -Priority $NginxPriority
Write-Utf8NoBom -Path $nginxPath -Content $newNginx
Write-Host "Updated nginx.conf (block SCAFFOLD_BEGIN: $slug)" -ForegroundColor Green
Write-Host "  Staging host: $stagingDomain -> web :$($WebPort+1); API :$($ApiPort+1)" -ForegroundColor DarkGray

if (-not $SkipSync) {
    $sync = Join-Path $DeployDir 'sync-server-env.ps1'
    if (Test-Path $sync) {
        Write-Host "Running sync-server-env.ps1 ..." -ForegroundColor DarkGray
        & $sync
    }
    $syncSt = Join-Path $DeployDir 'sync-server-env-staging.ps1'
    if (Test-Path $syncSt) {
        Write-Host "Running sync-server-env-staging.ps1 ..." -ForegroundColor DarkGray
        & $syncSt
    }
}

if ($Registry -and -not $WhatIf) {
    $reg = Normalize-Registry $Registry
    $hostPort = Get-RegistryHostPort $reg
    $regUpdates = @{
        REGISTRY           = "127.0.0.1:$hostPort"
        REGISTRY_HOST_PORT = $hostPort
    }
    foreach ($folder in @('server-files', 'server-files-staging')) {
        $serverEnvPath = Join-Path (Join-Path $DeployDir $folder) '.env'
        if (Test-Path $serverEnvPath) {
            Set-EnvFileValues -Path $serverEnvPath -Updates $regUpdates
            Write-Host "Updated $folder/.env REGISTRY (VPS pull via 127.0.0.1:$hostPort)" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "--- Next steps ---" -ForegroundColor Yellow
Write-Host "  1. Rebuild web image (NEXT_PUBLIC_* changed): .\build-and-push-web.ps1"
Write-Host "  2. Copy nginx.conf to VPS, test: sudo nginx -t && sudo systemctl reload nginx"
Write-Host "  3. Ensure SSL certs exist (Https: certbot; Http redirect: ssl/${slug}-redirect.crt)"
Write-Host "  4. .\build-and-push-all.ps1 then copy server-files/ + server-files-staging/ to VPS"
Write-Host "  5. Staging: ./server-up-staging.sh  |  Prod: ./server-up.sh  |  Promote: ./promote-staging-to-prod.sh"

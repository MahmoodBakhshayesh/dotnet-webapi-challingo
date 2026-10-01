# Sync server-files-staging/.env from deploy/api.env + deploy/web.env.
# Staging uses a separate hostname (PUBLISH_STAGING_DOMAIN).
# Ports/DB are offset from production so both stacks can run on one VPS.
# Images use :staging tags (server-up-staging.sh promotes TAG -> staging).

$ErrorActionPreference = 'Stop'
$DeployDir = $PSScriptRoot
. (Join-Path $DeployDir 'load-env.ps1')

function Get-ServerPullRegistry {
    param([hashtable]$ApiEnv, [string]$RegistryHostPort = '')
    $port = $RegistryHostPort
    if (-not $port -and $ApiEnv.ContainsKey('REGISTRY') -and [string]$ApiEnv['REGISTRY'] -match ':(\d+)$') {
        $port = $Matches[1]
    }
    if (-not $port) { $port = '8585' }
    $tls = ($port -eq '443')
    return @{
        REGISTRY           = "127.0.0.1:$port"
        REGISTRY_HOST_PORT = $port
        REGISTRY_TLS       = if ($tls) { 'true' } else { 'false' }
    }
}

function Get-IntOrDefault([string]$raw, [int]$fallback) {
    $n = 0
    if ([int]::TryParse("$raw", [ref]$n) -and $n -gt 0) { return $n }
    return $fallback
}

$DockerPrefix = 'challingo'
$ProjectPascal = 'Challingo'
$EnvPrefix = 'CHALLINGO'
$ApiImageKey = "${EnvPrefix}_API_IMAGE"
$WebImageKey = "${EnvPrefix}_WEB_IMAGE"
$WorkerImageKey = "${EnvPrefix}_WORKER_IMAGE"

$apiPath = Join-Path $DeployDir 'api.env'
$webPath = Join-Path $DeployDir 'web.env'
$serverEnvPath = Join-Path (Join-Path $DeployDir 'server-files-staging') '.env'

$api = Get-EnvFile $apiPath
$web = Get-EnvFile $webPath

$preserve = @{}
if (Test-Path $serverEnvPath) {
    $existing = Get-EnvFile $serverEnvPath
    if ($existing.ContainsKey('REGISTRY_HOST_PORT') -and $existing['REGISTRY_HOST_PORT']) {
        $preserve['REGISTRY_HOST_PORT'] = $existing['REGISTRY_HOST_PORT']
    }
}

$skip = @{ 'TAG' = $true; 'REGISTRY' = $true }
foreach ($key in (@($api.Keys) + @($web.Keys))) {
    if ($key -like 'NEXT_PUBLIC_*') { $skip[$key] = $true }
}

$merged = @{}
foreach ($key in $preserve.Keys) { $merged[$key] = $preserve[$key] }
foreach ($key in $api.Keys) {
    if (-not $skip.ContainsKey($key)) { $merged[$key] = $api[$key] }
}
foreach ($key in $web.Keys) {
    if (-not $skip.ContainsKey($key) -and $key -ne 'TAG') { $merged[$key] = $web[$key] }
}

$pullReg = Get-ServerPullRegistry -ApiEnv $api -RegistryHostPort $preserve['REGISTRY_HOST_PORT']
$merged['REGISTRY'] = $pullReg['REGISTRY']
$merged['REGISTRY_HOST_PORT'] = $pullReg['REGISTRY_HOST_PORT']
if ($pullReg.ContainsKey('REGISTRY_TLS')) { $merged['REGISTRY_TLS'] = $pullReg['REGISTRY_TLS'] }
$registryPull = $pullReg['REGISTRY']

$merged['API_VERSION'] = $api['TAG']
$merged['WEB_VERSION'] = $web['TAG']
$merged['WORKER_VERSION'] = $api['TAG']

# Staging image tags (separate from production :latest)
$merged[$ApiImageKey] = "$registryPull/${DockerPrefix}-api:staging"
$merged[$WebImageKey] = "$registryPull/${DockerPrefix}-web:staging"
$merged[$WorkerImageKey] = "$registryPull/${DockerPrefix}-worker:staging"

# Port offsets so staging can run beside production on one VPS
$prodApiPort = Get-IntOrDefault $api['API_HOST_PORT'] 8080
$prodWebPort = Get-IntOrDefault $web['WEB_HOST_PORT'] 3000
$prodPgPort = Get-IntOrDefault $api['POSTGRES_HOST_PORT'] 5434
$merged['API_HOST_PORT'] = [string]($prodApiPort + 1)
$merged['WEB_HOST_PORT'] = [string]($prodWebPort + 1)
$merged['POSTGRES_HOST_PORT'] = [string]($prodPgPort + 1)

# Isolated database
$prodDb = if ($api['POSTGRES_DB']) { [string]$api['POSTGRES_DB'] } else { $DockerPrefix }
$stagingDb = if ($prodDb -match '_staging$') { $prodDb } else { "${prodDb}_staging" }
$merged['POSTGRES_DB'] = $stagingDb

$pgUser = if ($api['POSTGRES_USER']) { $api['POSTGRES_USER'] } else { 'scaffoldadmin' }
$pgPass = if ($api['POSTGRES_PASSWORD']) { $api['POSTGRES_PASSWORD'] } else { 'changeme' }
$merged['ConnectionStrings__Database'] =
    "Host=postgres;Port=5432;Database=$stagingDb;Username=$pgUser;Password=$pgPass;Pooling=true"

# Easier for testers — migrate on staging by default
$merged['Database__AutoMigrate'] = 'true'

# Derive the in-network Redis connection string from REDIS_PASSWORD so compose and app cannot drift.
if ($merged['REDIS_PASSWORD']) {
    $merged['Redis__ConnectionString'] = "redis:6379,password=$($merged['REDIS_PASSWORD']),abortConnect=false"
}
$merged['DOCKER_PREFIX'] = $DockerPrefix

# Distinct JWT issuer so staging tokens are not confused with prod
if ($merged.ContainsKey('Jwt__Issuer') -and $merged['Jwt__Issuer'] -and $merged['Jwt__Issuer'] -notmatch 'Staging$') {
    $merged['Jwt__Issuer'] = "$($merged['Jwt__Issuer'])-Staging"
}
if ($merged.ContainsKey('Jwt__Audience') -and $merged['Jwt__Audience'] -and $merged['Jwt__Audience'] -notmatch 'Staging$') {
    $merged['Jwt__Audience'] = "$($merged['Jwt__Audience'])-Staging"
}

# Staging publishes on its own hostname (not a /_staging path)
$prodDomain = if ($merged.ContainsKey('PUBLISH_DOMAIN')) { [string]$merged['PUBLISH_DOMAIN'] } else { '' }
$stagDomain = if ($merged.ContainsKey('PUBLISH_STAGING_DOMAIN') -and $merged['PUBLISH_STAGING_DOMAIN']) {
    [string]$merged['PUBLISH_STAGING_DOMAIN']
} elseif ($prodDomain) {
    "staging.$prodDomain"
} else { '' }
if ($stagDomain) {
    $merged['PUBLISH_DOMAIN'] = $stagDomain
    $merged['PUBLISH_STAGING_DOMAIN'] = $stagDomain
    $tls = if ($merged.ContainsKey('PUBLISH_TLS') -and $merged['PUBLISH_TLS'] -match '^[Hh]ttps') { 'Https' } else { 'Http' }
    $scheme = if ($tls -eq 'Https') { 'https' } else { 'http' }
    # Drop prod CORS keys copied from api.env; set staging origins
    foreach ($k in @($merged.Keys | Where-Object { $_ -like 'Cors__AllowedOrigins__*' })) {
        $merged.Remove($k) | Out-Null
    }
    $merged['Cors__AllowedOrigins__0'] = "${scheme}://${stagDomain}"
}

# Rabbit ports offset when messaging enabled
if ($merged.ContainsKey('RABBITMQ_HOST_PORT')) {
    $rp = Get-IntOrDefault $merged['RABBITMQ_HOST_PORT'] 5672
    $merged['RABBITMQ_HOST_PORT'] = [string]($rp + 1)
}
if ($merged.ContainsKey('RABBITMQ_MGMT_HOST_PORT')) {
    $rm = Get-IntOrDefault $merged['RABBITMQ_MGMT_HOST_PORT'] 15672
    $merged['RABBITMQ_MGMT_HOST_PORT'] = [string]($rm + 1)
}
if ($merged.ContainsKey('REDIS_HOST_PORT')) {
    $rd = Get-IntOrDefault $merged['REDIS_HOST_PORT'] 6379
    $merged['REDIS_HOST_PORT'] = [string]($rd + 1)
}

$stagingApiPort = $merged['API_HOST_PORT']
$stagingWebPort = $merged['WEB_HOST_PORT']
$stagingPgPort = $merged['POSTGRES_HOST_PORT']

$order = @(
    "# $ProjectPascal - STAGING server deploy (generated by sync-server-env-staging.ps1)",
    '# Public host: set PUBLISH_DOMAIN to the staging hostname (separate from production).',
    '# Edit deploy/api.env + web.env, then re-run this sync.',
    '',
    'REGISTRY', 'REGISTRY_HOST_PORT', 'REGISTRY_TLS', '',
    'API_VERSION', 'WEB_VERSION', 'WORKER_VERSION', '',
    $ApiImageKey, $WebImageKey, $WorkerImageKey, '',
    'API_HOST_PORT', 'WEB_HOST_PORT', 'POSTGRES_HOST_PORT', '',
    'POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_DB', '',
    'ConnectionStrings__Database',
    'DOCKER_PREFIX', '',
    'Serilog__Enabled', 'Serilog__MinimumLevel', 'Serilog__WriteToFile', 'Serilog__FilePath', '',
    'Health__Enabled', 'Database__AutoMigrate', '',
    'Maintenance__Enabled', 'Maintenance__Message', 'Maintenance__BypassKey', '',
    'Storage__Provider', 'Storage__LocalRoot', '',
    'BACKUP_DIR', 'BACKUP_RETENTION_DAYS', 'BACKUP_OFFSITE_PATH', '',
    'Observability__Enabled', 'SEQ_HOST_PORT', 'UPTIME_KUMA_HOST_PORT', '',
    'Jwt__Key', 'Jwt__Issuer', 'Jwt__Audience', 'Jwt__ExpirationInMinutes', 'Jwt__RefreshTokenExpirationDays', '',
    'Cors__AllowedOrigins__0', 'Cors__AllowedOrigins__1', '',
    'Auth__EnablePasswordLogin', 'Auth__EnableEmailAuth', 'Auth__EnablePhoneAuth', 'Auth__OtpRateLimitPerMinute',
    'Auth__SeedAdminEmail', 'Auth__SeedAdminPassword', '',
    'RateLimit__Enabled', 'RateLimit__GlobalPerMinute', '',
    'RequestTimeout__Enabled', 'RequestTimeout__Seconds', '',
    'Http__Enabled', 'Http__TimeoutSeconds', 'Http__RetryCount', 'Http__RetryBaseDelayMs', 'Http__CircuitBreakFailures', 'Http__CircuitBreakSeconds', '',
    'Idempotency__Enabled', 'Idempotency__TtlHours', 'Idempotency__HeaderName', '',
    'Otp__MaxVerifyAttempts', '',
    'Otp__DevMode', 'Otp__LogOnly', '',
    'Sms__Provider', 'Sms__SmsIrApiKey', 'Sms__SmsIrVerifyTemplateId', 'Sms__SmsIrVerifyCodeParameterName', 'Sms__SmsIrLineNumber', 'Sms__OtpMessageTemplate', '',
    'RabbitMq__Enabled', 'RabbitMq__HostName', 'RabbitMq__Port', 'RabbitMq__UserName', 'RabbitMq__Password', 'RabbitMq__EmailQueueName', 'RabbitMq__SmsOtpQueueName', 'RabbitMq__EmailDeadLetterQueueName', 'RabbitMq__SmsOtpDeadLetterQueueName', '',
    'RABBITMQ_USER', 'RABBITMQ_PASSWORD', 'RABBITMQ_HOST_PORT', 'RABBITMQ_MGMT_HOST_PORT', '',

    'Redis__Enabled', 'Redis__ConnectionString', 'Redis__InstanceName', 'REDIS_PASSWORD', 'REDIS_HOST_PORT', '',

    'Competition__FreeRankedRoundsPerDay', 'Competition__SmallRoundThreshold', 'Competition__ScheduleDaysAhead', 'Competition__InviteBaseUrl', 'Competition__AllowAdminTimeTravel', '',

    'Realtime__Enabled', 'Realtime__HubPath', 'Realtime__KeepAliveSeconds', 'Realtime__ClientTimeoutSeconds', 'Realtime__EnableDetailedErrors', '',

    'Email__Enabled', 'Email__FromAddress', 'Email__FromDisplayName', 'Email__SmtpHost', 'Email__SmtpPort', 'Email__SmtpUsername', 'Email__SmtpPassword', 'Email__OtpSubject', '',
    'Google__ClientId', '',
    'Worker__PollIntervalSeconds', 'Worker__EnableSampleJob', 'Worker__EnableEmailDelivery', 'Worker__EnableSmsOtpDelivery', '',

    'Scheduler__Enabled', 'Scheduler__Jobs__Heartbeat__Enabled', 'Scheduler__Jobs__Heartbeat__Cron', '',

    'Store__Currency', 'Store__FreeShippingThreshold', 'Store__FlatShippingRate', '',
    'Stripe__SecretKey', 'Stripe__PublishableKey', 'Stripe__WebhookSecret', 'Stripe__SuccessUrl', 'Stripe__CancelUrl', '',
    'PUBLISH_DOMAIN', 'PUBLISH_STAGING_DOMAIN', 'PUBLISH_TLS'
)

$lines = New-Object System.Collections.Generic.List[string]
foreach ($item in $order) {
    if ($item -eq '') { $lines.Add(''); continue }
    if ($item.StartsWith('#')) { $lines.Add($item); continue }
    if ($merged.ContainsKey($item)) {
        $lines.Add((Format-EnvLine -Key $item -Value $merged[$item]))
        $merged.Remove($item) | Out-Null
    }
}
foreach ($key in ($merged.Keys | Sort-Object)) {
    $lines.Add((Format-EnvLine -Key $key -Value $merged[$key]))
}

$stagingDir = Split-Path $serverEnvPath -Parent
if (-not (Test-Path $stagingDir)) {
    New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null
}

$text = ($lines -join "`n") + "`n"
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($serverEnvPath, $text, $utf8)

Write-Host "Updated $serverEnvPath" -ForegroundColor Green
Write-Host "  Staging ports API=$stagingApiPort WEB=$stagingWebPort PG=$stagingPgPort DB=$stagingDb" -ForegroundColor DarkGray
Write-Host "  Images :staging  |  public host PUBLISH_DOMAIN (staging hostname)" -ForegroundColor DarkGray

$LASTEXITCODE = 0
exit 0

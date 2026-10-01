# Load KEY=VALUE env file into a hashtable or process environment.

function Unquote-EnvValue {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    $v = $Value.Trim()

    function Unquote-EnvValueOnce([string]$raw) {
        $x = $raw.Trim()
        if ($x.Length -ge 2 -and $x.StartsWith('"') -and $x.EndsWith('"')) {
            $inner = $x.Substring(1, $x.Length - 2)
            $sb = New-Object System.Text.StringBuilder
            for ($i = 0; $i -lt $inner.Length; $i++) {
                $ch = $inner[$i]
                if ($ch -eq '\' -and ($i + 1) -lt $inner.Length) {
                    $next = $inner[$i + 1]
                    if ($next -eq '"' -or $next -eq '\') {
                        [void]$sb.Append($next)
                        $i++
                        continue
                    }
                }
                [void]$sb.Append($ch)
            }
            return $sb.ToString()
        }
        if ($x.Length -ge 2 -and $x.StartsWith("'") -and $x.EndsWith("'")) {
            return $x.Substring(1, $x.Length - 2)
        }
        return $x
    }

    # Peel repeated Format-EnvLine / GUI quote layers (passwords with # / ! were remangled).
    for ($n = 0; $n -lt 40; $n++) {
        $next = Unquote-EnvValueOnce $v
        if ($next -eq $v) { break }
        $v = $next
    }
    return $v
}

function Format-EnvLine {
    param(
        [string]$Key,
        [string]$Value
    )

    # Always format from a fully unquoted value so re-sync never stacks escapes.
    $v = Unquote-EnvValue -Value ([string]$Value)
    if ($v -match '[\s#"''\\]' -or $v -match '[=`]') {
        $escaped = $v.Replace('\', '\\').Replace('"', '\"')
        return "$Key=`"$escaped`""
    }
    return "$Key=$v"
}

function Get-EnvFile {
    param([string]$Path)

    $map = @{}
    if (-not (Test-Path $Path)) {
        throw "Missing env file: $Path"
    }
    $text = [System.IO.File]::ReadAllText($Path)
    foreach ($line in ($text -split '\r?\n')) {
        $line = $line.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        $key = $line.Substring(0, $i).Trim()
        $val = Unquote-EnvValue -Value ($line.Substring($i + 1).Trim())
        $map[$key] = $val
    }
    return $map
}

function Set-EnvFileValues {
    param(
        [string]$Path,
        [hashtable]$Updates
    )

    if (-not (Test-Path $Path)) {
        throw "Missing env file: $Path"
    }

    $lines = [System.IO.File]::ReadAllLines($Path)
    $written = @{}
    $out = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ($trim -match '^([^#=]+)=(.*)$') {
            $key = $matches[1].Trim()
            if ($Updates.ContainsKey($key)) {
                $out.Add((Format-EnvLine -Key $key -Value ([string]$Updates[$key])))
                $written[$key] = $true
                continue
            }
        }
        $out.Add($line)
    }

    foreach ($key in $Updates.Keys) {
        if (-not $written.ContainsKey($key)) {
            $out.Add((Format-EnvLine -Key $key -Value ([string]$Updates[$key])))
        }
    }

    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($Path, $out.ToArray(), $enc)
}

function Repair-EnvFileEscapes {
    <#
    .SYNOPSIS
      Peel stacked quote/escape layers in an env file (GUI/sync remangle of passwords with #).
    #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) { throw "Missing env file: $Path" }
    $map = Get-EnvFile -Path $Path
    if ($map.ContainsKey('POSTGRES_PASSWORD') -or $map.ContainsKey('POSTGRES_USER') -or $map.ContainsKey('POSTGRES_DB')) {
        $pw = if ($map.ContainsKey('POSTGRES_PASSWORD')) { [string]$map['POSTGRES_PASSWORD'] } else { 'changeme' }
        $user = if ($map.ContainsKey('POSTGRES_USER')) { [string]$map['POSTGRES_USER'] } else { 'scaffoldadmin' }
        $db = if ($map.ContainsKey('POSTGRES_DB')) { [string]$map['POSTGRES_DB'] } else { '' }
        if ($map.ContainsKey('ConnectionStrings__Database') -and $db) {
            # Rebuild full connection string so Username cannot drift from POSTGRES_USER.
            $map['ConnectionStrings__Database'] =
                "Host=postgres;Port=5432;Database=$db;Username=$user;Password=$pw;Pooling=true"
        } elseif ($map.ContainsKey('ConnectionStrings__Database')) {
            $cs = [string]$map['ConnectionStrings__Database']
            if ($cs -match 'Password=') {
                $cs = [regex]::Replace($cs, 'Password=[^;]*', "Password=$pw", 1)
            }
            if ($cs -match 'Username=') {
                $cs = [regex]::Replace($cs, 'Username=[^;]*', "Username=$user", 1)
            }
            $map['ConnectionStrings__Database'] = $cs
        }
    }
    $lines = [System.IO.File]::ReadAllLines($Path)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ($trim -match '^([^#=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            if ($map.ContainsKey($key)) {
                $out.Add((Format-EnvLine -Key $key -Value ([string]$map[$key])))
                continue
            }
        }
        $out.Add($line)
    }
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($Path, $out.ToArray(), $enc)
}

function Remove-EnvFileKeys {
    param(
        [string]$Path,
        [string[]]$KeyPatterns
    )

    if (-not (Test-Path $Path)) { return }

    $lines = [System.IO.File]::ReadAllLines($Path)
    $out = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        $trim = $line.Trim()
        $drop = $false
        if ($trim -match '^([^#=]+)=(.*)$') {
            $key = $matches[1].Trim()
            foreach ($pattern in $KeyPatterns) {
                if ($key -like $pattern) { $drop = $true; break }
            }
        }
        if (-not $drop) { $out.Add($line) }
    }

    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($Path, $out.ToArray(), $enc)
}

function Import-EnvFile {
    param([string]$Path)

    # Return parsed values only. Build scripts read TAG/REGISTRY from the hashtable;
    # do not copy every api.env key into the PowerShell process (Windows 32K limit per var).
    return Get-EnvFile -Path $Path
}

function Get-RegistryHostPortParts {
    param([string]$Reg)

    $hostPort = ($Reg -replace '^https?://', '').TrimEnd('/')
    $hostOnly = $hostPort
    $port = 5000
    if ($hostPort -match '^(.+):(\d+)$') {
        $hostOnly = $Matches[1]
        $port = [int]$Matches[2]
    }
    return @{
        HostPort = $hostPort
        Host     = $hostOnly
        Port     = $port
    }
}

function Test-RegistryUsesTls {
    param(
        [string]$Reg,
        [bool]$ForceTls = $false
    )

    if ($ForceTls) { return $true }
    if ($env:SCAFFOLD_REGISTRY_TLS -match '^(1|true|yes)$') { return $true }
    $parts = Get-RegistryHostPortParts -Reg $Reg
    if ($parts.Port -eq 443) { return $true }
    if ($Reg -match '^https://') { return $true }
    return $false
}

function Get-DockerRegistryCertsDir {
    param([string]$HostPort)

    $dockerHome = if ($env:DOCKER_CONFIG) {
        $env:DOCKER_CONFIG
    } else {
        Join-Path $HOME '.docker'
    }
    return (Join-Path (Join-Path $dockerHome 'certs.d') $HostPort)
}

function Install-DockerRegistryTlsTrust {
    param(
        [string]$Reg,
        [bool]$Tls = $false,
        [int]$TimeoutSec = 12
    )

    $parts = Get-RegistryHostPortParts -Reg $Reg
    $hostPort = $parts.HostPort
    if (-not (Test-RegistryUsesTls -Reg $Reg -ForceTls $Tls)) {
        return $null
    }

    $dir = Get-DockerRegistryCertsDir -HostPort $hostPort
    $caPath = Join-Path $dir 'ca.crt'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    Write-Host "→ Fetching TLS cert for $hostPort (self-signed OK)…" -ForegroundColor Yellow

    $pem = $null
    $openssl = Get-Command openssl -ErrorAction SilentlyContinue
    if ($openssl) {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $openssl.Source
            $psi.Arguments = "s_client -connect $($parts.Host):$($parts.Port) -servername $($parts.Host) -showcerts"
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $p = [System.Diagnostics.Process]::Start($psi)
            $p.StandardInput.Close()
            $outTask = $p.StandardOutput.ReadToEndAsync()
            $errTask = $p.StandardError.ReadToEndAsync()
            if (-not $p.WaitForExit($TimeoutSec * 1000)) {
                try { $p.Kill() } catch { }
            }
            $raw = [string]$outTask.Result + [string]$errTask.Result
            if ($raw -match '(?s)(-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----)') {
                $pem = $Matches[1].Trim() + "`n"
            }
        } finally {
            $ErrorActionPreference = $prevEap
        }
    }

    if (-not $pem) {
        $py = Get-Command python3 -ErrorAction SilentlyContinue
        if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
        if ($py) {
            $code = @"
import ssl, socket, sys, base64
host, port = sys.argv[1], int(sys.argv[2])
ctx = ssl._create_unverified_context()
with socket.create_connection((host, port), timeout=$TimeoutSec) as sock:
    with ctx.wrap_socket(sock, server_hostname=host) as ssock:
        der = ssock.getpeercert(binary_form=True)
b64 = ''.join(base64.encodebytes(der).decode('ascii').splitlines())
print('-----BEGIN CERTIFICATE-----')
for i in range(0, len(b64), 64):
    print(b64[i:i+64])
print('-----END CERTIFICATE-----')
"@
            $pemOut = & $py.Source -c $code $parts.Host $parts.Port 2>$null
            if ($pemOut) { $pem = (($pemOut | Out-String).Trim() + "`n") }
        }
    }

    if (-not $pem -or $pem -notmatch 'BEGIN CERTIFICATE') {
        throw "Could not fetch TLS certificate from $($parts.Host):$($parts.Port). Install openssl or python3, or copy /opt/registry/certs/domain.crt from the VPS to $caPath"
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($caPath, $pem.Trim() + "`n", $utf8NoBom)

    # Also write ca.pem — some Docker Desktop builds look for either name.
    $pemPath = Join-Path $dir 'ca.pem'
    [System.IO.File]::WriteAllText($pemPath, $pem.Trim() + "`n", $utf8NoBom)

    Write-Host "Docker trust file ready → $caPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Do NOT double-click the .crt (macOS Keychain error -25294 is normal and unused)." -ForegroundColor Yellow
    Write-Host "Docker Desktop reads ~/.docker/certs.d/ — just Restart Docker Desktop, then retry push." -ForegroundColor Yellow
    Write-Host ""

    # Optional: add to login keychain for Docker Desktop Mac (never open Keychain GUI).
    # Failure here is OK — certs.d is enough for most registry login/push cases.
    if ($IsMacOS -or $env:OS -ne 'Windows_NT') {
        $security = Get-Command security -ErrorAction SilentlyContinue
        if ($security) {
            $loginKc = Join-Path $HOME 'Library/Keychains/login.keychain-db'
            if (-not (Test-Path -LiteralPath $loginKc)) {
                $loginKc = Join-Path $HOME 'Library/Keychains/login.keychain'
            }
            if (Test-Path -LiteralPath $loginKc) {
                Write-Host "→ Also trying login keychain trust (optional for Docker Desktop)…" -ForegroundColor DarkGray
                $prevEap = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                try {
                    $secOut = & $security.Source add-trusted-cert -d -r trustRoot -k $loginKc $caPath 2>&1 | Out-String
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Login keychain trust OK." -ForegroundColor Green
                    } else {
                        Write-Host "Keychain trust skipped/failed (ignore Error -25294): $($secOut.Trim())" -ForegroundColor DarkGray
                        Write-Host "certs.d file is still valid — restart Docker Desktop." -ForegroundColor DarkGray
                    }
                } finally {
                    $ErrorActionPreference = $prevEap
                    $global:LASTEXITCODE = 0
                }
            }
        }
    }

    return $caPath
}

function Test-RegistryHttpCode {
    param(
        [string]$Uri,
        [bool]$InsecureTls,
        [int]$TimeoutSec = 8
    )

    # Prefer curl: handles self-signed reliably on macOS/Linux/Windows.
    $curlCmd = Get-Command curl -ErrorAction SilentlyContinue
    if ($curlCmd -and $curlCmd.Source -notmatch 'System32\\curl\.exe$') {
        # On Windows, prefer curl.exe over the Invoke-WebRequest alias when available.
    }
    $curlExe = $null
    foreach ($name in @('curl.exe', 'curl')) {
        $c = Get-Command $name -ErrorAction SilentlyContinue
        if ($c -and $c.CommandType -ne 'Alias') { $curlExe = $c.Source; break }
    }
    if ($curlExe) {
        $args = [System.Collections.Generic.List[string]]::new()
        if ($InsecureTls) { $args.Add('-k') }
        $nullOut = if ($env:OS -eq 'Windows_NT' -or $IsWindows) { 'NUL' } else { '/dev/null' }
        $args.AddRange([string[]]@('-sS', '-o', $nullOut, '-w', '%{http_code}', '--connect-timeout', "$TimeoutSec", '--max-time', "$TimeoutSec", $Uri))
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $codeText = & $curlExe @args 2>$null
            if ($codeText -match '^\d{3}$') { return [int]$codeText }
        } finally {
            $ErrorActionPreference = $prevEap
        }
    }

    # PowerShell 7+ / .NET Core: ServicePointManager callback does NOT bypass HttpWebRequest TLS.
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $handler = [System.Net.Http.HttpClientHandler]::new()
        if ($InsecureTls) {
            $handler.ServerCertificateCustomValidationCallback = { $true }
        }
        $client = [System.Net.Http.HttpClient]::new($handler)
        $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
        try {
            $resp = $client.GetAsync($Uri).GetAwaiter().GetResult()
            return [int]$resp.StatusCode
        } finally {
            $client.Dispose()
            $handler.Dispose()
        }
    }

    if ($InsecureTls) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }
    try {
        $req = [System.Net.HttpWebRequest]::Create($Uri)
        $req.Method = 'GET'
        $req.Timeout = $TimeoutSec * 1000
        $req.ReadWriteTimeout = $TimeoutSec * 1000
        $req.Proxy = $null
        $resp = $req.GetResponse()
        $code = [int]$resp.StatusCode
        $resp.Close()
        return $code
    } finally {
        if ($InsecureTls) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
}

function Test-RegistryReachable {
    param(
        [string]$Reg,
        [int]$TimeoutSec = 8,
        [bool]$Tls = $false
    )

    $parts = Get-RegistryHostPortParts -Reg $Reg
    $hostPort = $parts.HostPort
    $useTls = Test-RegistryUsesTls -Reg $Reg -ForceTls $Tls
    $scheme = if ($useTls) { 'https' } else { 'http' }
    $uri = "${scheme}://$hostPort/v2/"
    Write-Host "Checking $uri ..." -ForegroundColor DarkGray

    $tcpOk = $false
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($parts.Host, $parts.Port, $null, $null)
        $tcpOk = $iar.AsyncWaitHandle.WaitOne($TimeoutSec * 1000, $false)
        if ($tcpOk) { $client.EndConnect($iar) }
        $client.Close()
    } catch {
        $tcpOk = $false
    }

    if (-not $tcpOk) {
        Write-Host "Registry not reachable at $uri (TCP connect failed)" -ForegroundColor Red
        Write-Host "  Check firewall, registry container, and that $hostPort is correct." -ForegroundColor Yellow
        throw "Registry TCP connect failed: $hostPort"
    }

    if ($useTls) {
        try {
            Install-DockerRegistryTlsTrust -Reg $Reg -Tls $true -TimeoutSec $TimeoutSec | Out-Null
        } catch {
            Write-Host "  Warning: could not install Docker certs.d trust yet: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    try {
        $code = Test-RegistryHttpCode -Uri $uri -InsecureTls:$useTls -TimeoutSec $TimeoutSec
        if ($code -eq 200) {
            Write-Host "Registry reachable at $uri" -ForegroundColor DarkGray
            return
        }
        if ($code -eq 401 -or $code -eq 403) {
            Write-Host "Registry OK at $uri ($code without/with auth is expected)" -ForegroundColor DarkGray
            return
        }
        throw "HTTP $code"
    } catch {
        $msg = $_.Exception.Message
        Write-Host "Registry not responding at $uri" -ForegroundColor Red
        if ($msg -match 'timed out|timeout') {
            Write-Host "  TCP port is open but $scheme did not respond." -ForegroundColor Yellow
            if (-not $useTls) {
                Write-Host "  On VPS: curl -s http://127.0.0.1:8585/v2/  and  docker ps | grep registry" -ForegroundColor Yellow
                Write-Host "  If local curl works, open firewall: sudo ufw allow 8585/tcp" -ForegroundColor Yellow
            } else {
                Write-Host "  On VPS: curl -k https://127.0.0.1/v2/  and  docker ps | grep registry" -ForegroundColor Yellow
                Write-Host "  Open firewall: sudo ufw allow 443/tcp" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  $msg" -ForegroundColor Yellow
            if (-not $useTls) {
                Write-Host "  Registry is HTTP-only. Add `"insecure-registries`": [`"$hostPort`"] in Docker Desktop (not https)." -ForegroundColor Yellow
            } else {
                $certsDir = Get-DockerRegistryCertsDir -HostPort $hostPort
                Write-Host "  Self-signed TLS: ensure $certsDir/ca.crt exists, then restart Docker Desktop." -ForegroundColor Yellow
            }
        }
        throw
    }
}

function Assert-DockerInsecureRegistry {
    param(
        [string]$Reg,
        [bool]$Tls = $false
    )

    if (Test-RegistryUsesTls -Reg $Reg -ForceTls $Tls) {
        Write-Host "Registry $Reg uses TLS — skipping insecure-registries check." -ForegroundColor DarkGray
        return
    }

    $hostPort = (Get-RegistryHostPortParts -Reg $Reg).HostPort
    if ($hostPort -match '^127\.|^localhost|^::1') { return }

    $raw = docker info --format '{{json .RegistryConfig}}' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "docker info failed: $raw" }

    $cfg = $raw | ConvertFrom-Json
    $entry = $cfg.IndexConfigs.$hostPort
    if ($entry -and -not $entry.Secure) { return }

    Write-Host ""
    Write-Host "Docker will push to https://$hostPort but your registry is HTTP-only." -ForegroundColor Red
    Write-Host ""
    Write-Host "One-time fix (Docker Desktop):" -ForegroundColor Yellow
    Write-Host "  Settings -> Docker Engine -> add to JSON:" -ForegroundColor Yellow
    Write-Host "    `"insecure-registries`": [`"$hostPort`"]" -ForegroundColor Cyan
    Write-Host "  Apply & Restart, then run this script again." -ForegroundColor Yellow
    Write-Host ""
    throw "Registry $hostPort is not configured as an insecure registry in Docker"
}

function Test-DockerRegistryCredentials {
    param(
        [string]$Reg,
        [string]$Username,
        [string]$Password,
        [bool]$Tls = $false,
        [int]$TimeoutSec = 10
    )

    $parts = Get-RegistryHostPortParts -Reg $Reg
    $hostPort = $parts.HostPort
    $useTls = Test-RegistryUsesTls -Reg $Reg -ForceTls $Tls
    $scheme = if ($useTls) { 'https' } else { 'http' }
    $uri = "${scheme}://$hostPort/v2/"

    $curlExe = $null
    foreach ($name in @('curl.exe', 'curl')) {
        $c = Get-Command $name -ErrorAction SilentlyContinue
        if ($c -and $c.CommandType -ne 'Alias') { $curlExe = $c.Source; break }
    }
    if (-not $curlExe) { return $null }

    $args = [System.Collections.Generic.List[string]]::new()
    if ($useTls) { $args.Add('-k') }
    $nullOut = if ($env:OS -eq 'Windows_NT' -or $IsWindows) { 'NUL' } else { '/dev/null' }
    $args.AddRange([string[]]@(
        '-sS', '-o', $nullOut, '-w', '%{http_code}',
        '--connect-timeout', "$TimeoutSec", '--max-time', "$TimeoutSec",
        '-u', "${Username}:${Password}",
        $uri
    ))
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $codeText = & $curlExe @args 2>$null
        if ($codeText -match '^\d{3}$') { return [int]$codeText }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    return $null
}

function Connect-DockerRegistry {
    param(
        [string]$Reg,
        [string]$Username = '',
        [string]$Password = '',
        [bool]$Tls = $false
    )

    $hostPort = (Get-RegistryHostPortParts -Reg $Reg).HostPort
    if (Test-RegistryUsesTls -Reg $Reg -ForceTls $Tls) {
        Install-DockerRegistryTlsTrust -Reg $Reg -Tls $true | Out-Null
    }

    $Username = if ($null -eq $Username) { '' } else { $Username.Trim() }
    $Password = if ($null -eq $Password) { '' } else { $Password.Trim() }

    if (-not $Username -or -not $Password) {
        Write-Host "No registry credentials provided for $hostPort (anonymous push if registry allows)." -ForegroundColor DarkGray
        return
    }

    $probe = Test-DockerRegistryCredentials -Reg $Reg -Username $Username -Password $Password -Tls $Tls
    if ($probe -eq 401 -or $probe -eq 403) {
        Write-Host "Registry rejected user='$Username' (HTTP $probe)." -ForegroundColor Red
        Write-Host "TLS is OK — the password in GUI secrets does not match htpasswd on the VPS." -ForegroundColor Yellow
        Write-Host "Fix: Deploy → Server → set Registry password → Save → Install / repair registry on VPS" -ForegroundColor Yellow
        Write-Host "    (Install rewrites /opt/registry/auth/htpasswd from the password you just saved.)" -ForegroundColor Yellow
        throw "Registry login unauthorized for $hostPort (user=$Username). Re-save registry password and re-run Install registry on VPS."
    }

    Write-Host "→ docker login $hostPort (user=$Username)…" -ForegroundColor Yellow
    # Do not pipe a PowerShell string (it appends a trailing newline and breaks passwords).
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCmd) { throw 'docker CLI not found on PATH' }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $dockerCmd.Source
    $psi.Arguments = "login `"$hostPort`" --username `"$Username`" --password-stdin"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $proc.StandardInput.Write($Password)  # no trailing newline
    $proc.StandardInput.Close()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    if ($stdout) { Write-Host $stdout.TrimEnd() }
    if ($stderr) { Write-Host $stderr.TrimEnd() }
    if ($proc.ExitCode -ne 0) {
        $certsDir = Get-DockerRegistryCertsDir -HostPort $hostPort
        if ($probe -eq 200) {
            throw "docker login failed for $hostPort despite HTTP 200 probe. Check Docker Desktop TLS trust ($certsDir/ca.crt) and restart Docker."
        }
        throw "docker login failed for $hostPort (user=$Username). If TLS was OK earlier, re-save Registry password and run Sync registry password / Install registry on VPS. Certs: $certsDir/ca.crt"
    }
    Write-Host "Logged in to registry $hostPort" -ForegroundColor Green
}

function Resolve-DefaultNginxConfigPath {
    param([string]$DeployDir)

    if (-not $DeployDir) { return $null }

    $hintFile = Join-Path $DeployDir '.scaffold-nginx-path'
    if (Test-Path -LiteralPath $hintFile) {
        $p = (Get-Content -LiteralPath $hintFile -Raw -Encoding UTF8).Trim()
        if ($p -and (Test-Path -LiteralPath $p)) {
            return (Resolve-Path -LiteralPath $p).Path
        }
    }

    $rootFile = Join-Path $DeployDir '.scaffold-root'
    if (-not (Test-Path -LiteralPath $rootFile)) { return $null }

    $root = (Get-Content -LiteralPath $rootFile -Raw -Encoding UTF8).Trim()
    if (-not $root) { return $null }

    $cfgPath = Join-Path $root 'scaffold-config.psd1'
    $localPath = Join-Path $root 'scaffold-config.local.psd1'
    if (-not (Test-Path -LiteralPath $cfgPath)) { return $null }

    $cfg = Import-PowerShellDataFile $cfgPath
    if (Test-Path -LiteralPath $localPath) {
        $local = Import-PowerShellDataFile $localPath
        foreach ($key in $local.Keys) {
            $cfg[$key] = $local[$key]
        }
    }

    $nginxPath = $null
    if ($cfg.ContainsKey('NginxConfigPath') -and $cfg.NginxConfigPath) {
        $nginxPath = [string]$cfg.NginxConfigPath
        if (-not [System.IO.Path]::IsPathRooted($nginxPath)) {
            $nginxPath = Join-Path $root $nginxPath
        }
    } else {
        $nginxPath = Join-Path (Join-Path $root 'nginx') 'nginx.conf'
    }

    if ($nginxPath -and (Test-Path -LiteralPath $nginxPath)) {
        return (Resolve-Path -LiteralPath $nginxPath).Path
    }

    return $null
}

function Invoke-DockerPushWithRetry {
    param(
        [Parameter(Mandatory)]
        [string]$Image,

        [int]$MaxAttempts = 5,
        [int]$DelaySec = 8
    )

    Write-Host "→ Pushing $Image (up to $MaxAttempts attempts; slow links may retry)…" -ForegroundColor Yellow
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
            Write-Host "  push attempt $attempt/$MaxAttempts…" -ForegroundColor DarkGray
            $out = & docker push $Image 2>&1 | ForEach-Object { "$_" }
            $code = $LASTEXITCODE
            $out | ForEach-Object { Write-Host $_ }
            if ($code -eq 0) {
                Write-Host "Pushed $Image" -ForegroundColor Green
                return
            }

            $joined = ($out -join "`n")
            $retryable = $joined -match 'timeout|TLS handshake|connection reset|connection refused|i/o timeout|EOF|temporarily unavailable|502|503|504|unexpected EOF'
            if (-not $retryable -or $attempt -ge $MaxAttempts) {
                Write-Host ""
                Write-Host "Push failed after $attempt attempt(s)." -ForegroundColor Red
                Write-Host "On slow VPS links, set Docker Desktop → Docker Engine JSON:" -ForegroundColor Yellow
                Write-Host '  "max-concurrent-uploads": 1,' -ForegroundColor Cyan
                Write-Host '  "max-concurrent-downloads": 2' -ForegroundColor Cyan
                Write-Host "Then Apply & Restart and retry Build & push (layers already uploaded are skipped)." -ForegroundColor Yellow
                throw "push failed"
            }

            $wait = $DelaySec * $attempt
            Write-Host "  transient push error — waiting ${wait}s before retry…" -ForegroundColor Yellow
            Start-Sleep -Seconds $wait
        }
    } finally {
        $ErrorActionPreference = $prev
        $global:LASTEXITCODE = 0
    }
}

function Ensure-BuildxBuilder {
    param([string]$BuilderName)

    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $selected = $false
        foreach ($name in @($BuilderName, 'desktop-linux', 'default')) {
            docker buildx use $name 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Using buildx builder: $name" -ForegroundColor DarkGray
                $selected = $true
                break
            }
        }
        if (-not $selected) {
            docker buildx create --name $BuilderName --use 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'No usable buildx builder found' }
        }
        docker buildx inspect --bootstrap 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'buildx bootstrap failed' }
    } finally {
        $ErrorActionPreference = $prev
    }
}

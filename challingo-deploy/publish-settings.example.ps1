# Example: run from challingo-deploy folder after editing paths/ports/domain.

.\Set-PublishSettings.ps1 `
    -Domain example.com `
    -ApiPort 8080 `
    -WebPort 3000 `
    -PostgresPort 5434 `
    -TlsMode Http `
    -Registry 203.0.113.10:8585 `
    -Tag 1.0.1 `
    -NginxPriority First `
    -UploadMaxBodySize 50M `
    # -NginxConfigPath omitted → uses scaffold nginx/nginx.conf via .scaffold-nginx-path

# HTTPS with Let's Encrypt on 443:
# .\Set-PublishSettings.ps1 `
#     -Domain example.com `
#     -ApiPort 8080 `
#     -WebPort 3000 `
#     -TlsMode Https `
#     -ApiProxyStyle PreservePrefix `
#     -NginxConfigPath '/etc/nginx/nginx.conf'

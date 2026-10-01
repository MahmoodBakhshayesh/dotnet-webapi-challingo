using System.Text.Json;
using Microsoft.Extensions.Options;
using Challingo.Core.Settings;

namespace Challingo.Api.Extensions;

public sealed class MaintenanceMiddleware(RequestDelegate next, IOptions<MaintenanceOptions> options)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var maintenance = options.Value;
        if (!maintenance.Enabled)
        {
            await next(context);
            return;
        }

        var path = context.Request.Path.Value ?? "";
        if (path.StartsWith("/health", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("/swagger", StringComparison.OrdinalIgnoreCase))
        {
            await next(context);
            return;
        }

        if (!string.IsNullOrWhiteSpace(maintenance.BypassKey)
            && context.Request.Headers.TryGetValue("X-Maintenance-Bypass", out var bypass)
            && bypass == maintenance.BypassKey)
        {
            await next(context);
            return;
        }

        context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
        context.Response.ContentType = "application/json";
        var body = JsonSerializer.Serialize(new
        {
            status = 503,
            message = maintenance.Message
        });
        await context.Response.WriteAsync(body);
    }
}

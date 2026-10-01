using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Challingo.Core.Settings;

namespace Challingo.Api.Extensions;

/// <summary>
/// When Idempotency:Enabled and a mutating request includes the configured header,
/// caches the first response and replays it for duplicate keys.
/// </summary>
public sealed class IdempotencyMiddleware(
    RequestDelegate next,
    IMemoryCache cache,
    IOptions<IdempotencyOptions> options,
    ILogger<IdempotencyMiddleware> logger)
{
    private static readonly HashSet<string> MutatingMethods = new(StringComparer.OrdinalIgnoreCase)
    {
        HttpMethods.Post, HttpMethods.Put, HttpMethods.Patch, HttpMethods.Delete
    };

    public async Task InvokeAsync(HttpContext context)
    {
        var opts = options.Value;
        if (!opts.Enabled || !MutatingMethods.Contains(context.Request.Method))
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

        var headerName = string.IsNullOrWhiteSpace(opts.HeaderName) ? "Idempotency-Key" : opts.HeaderName.Trim();
        if (!context.Request.Headers.TryGetValue(headerName, out var keyValues))
        {
            await next(context);
            return;
        }

        var rawKey = keyValues.ToString().Trim();
        if (string.IsNullOrWhiteSpace(rawKey) || rawKey.Length > 128)
        {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsync(
                JsonSerializer.Serialize(new { status = 400, message = $"Invalid {headerName} header." }));
            return;
        }

        var userPart = context.User?.Identity?.IsAuthenticated == true
            ? (context.User.FindFirst("sub")?.Value
               ?? context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
               ?? context.User.Identity?.Name
               ?? "auth")
            : "anon";

        var cacheKey = $"idem:{userPart}:{context.Request.Method}:{path}:{rawKey}";

        if (cache.TryGetValue(cacheKey, out CachedIdempotentResponse? cached) && cached is not null)
        {
            logger.LogDebug("Idempotency replay for {Key}", cacheKey);
            context.Response.StatusCode = cached.StatusCode;
            context.Response.ContentType = cached.ContentType;
            context.Response.Headers["X-Idempotency-Replayed"] = "true";
            await context.Response.WriteAsync(cached.Body);
            return;
        }

        var originalBody = context.Response.Body;
        await using var buffer = new MemoryStream();
        context.Response.Body = buffer;

        try
        {
            await next(context);

            buffer.Seek(0, SeekOrigin.Begin);
            var bodyText = await new StreamReader(buffer, Encoding.UTF8, detectEncodingFromByteOrderMarks: false, leaveOpen: true).ReadToEndAsync();
            buffer.Seek(0, SeekOrigin.Begin);

            if (context.Response.StatusCode is >= 200 and < 300
                && buffer.Length <= Math.Max(1024, opts.MaxBodyBytes))
            {
                var ttl = TimeSpan.FromHours(Math.Clamp(opts.TtlHours, 1, 168));
                cache.Set(
                    cacheKey,
                    new CachedIdempotentResponse(
                        context.Response.StatusCode,
                        context.Response.ContentType ?? "application/json",
                        bodyText),
                    new MemoryCacheEntryOptions
                    {
                        AbsoluteExpirationRelativeToNow = ttl
                    });
            }

            await buffer.CopyToAsync(originalBody);
        }
        finally
        {
            context.Response.Body = originalBody;
        }
    }

    private sealed record CachedIdempotentResponse(int StatusCode, string ContentType, string Body);
}

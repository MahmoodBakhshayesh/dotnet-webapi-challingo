using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Http.Resilience;
using Polly;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Http;

public static class ScaffoldHttpResilienceExtensions
{
    /// <summary>
    /// Adds standard resilience (timeout, retry with exponential backoff + jitter, circuit breaker)
    /// when Http:Enabled is true. No-op when disabled.
    /// </summary>
    public static IHttpClientBuilder AddScaffoldHttpResilience(
        this IHttpClientBuilder builder,
        IConfiguration configuration)
    {
        var opts = configuration.GetSection("Http").Get<HttpResilienceOptions>() ?? new HttpResilienceOptions();
        return builder.AddScaffoldHttpResilience(opts);
    }

    public static IHttpClientBuilder AddScaffoldHttpResilience(
        this IHttpClientBuilder builder,
        HttpResilienceOptions opts)
    {
        if (!opts.Enabled)
            return builder;

        var attemptSeconds = Math.Clamp(opts.TimeoutSeconds, 1, 120);
        var retryCount = Math.Clamp(opts.RetryCount, 0, 5);
        var baseDelayMs = Math.Clamp(opts.RetryBaseDelayMs, 50, 10_000);
        var breakFailures = Math.Clamp(opts.CircuitBreakFailures, 2, 100);
        var breakSeconds = Math.Clamp(opts.CircuitBreakSeconds, 5, 300);

        builder.AddStandardResilienceHandler(o =>
        {
            o.AttemptTimeout.Timeout = TimeSpan.FromSeconds(attemptSeconds);
            o.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(attemptSeconds * (retryCount + 1) + 5);

            o.Retry.MaxRetryAttempts = retryCount;
            o.Retry.Delay = TimeSpan.FromMilliseconds(baseDelayMs);
            o.Retry.BackoffType = DelayBackoffType.Exponential;
            o.Retry.UseJitter = true;

            o.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(Math.Max(30, attemptSeconds * 2));
            o.CircuitBreaker.FailureRatio = 0.5;
            o.CircuitBreaker.MinimumThroughput = breakFailures;
            o.CircuitBreaker.BreakDuration = TimeSpan.FromSeconds(breakSeconds);
        });

        return builder;
    }
}

namespace Challingo.Api.Extensions;

public sealed class RequestCorrelationMiddleware(RequestDelegate next)
{
    public const string HeaderName = "X-Request-Id";

    public async Task InvokeAsync(HttpContext context)
    {
        var requestId = context.Request.Headers[HeaderName].FirstOrDefault()
            ?? context.TraceIdentifier;
        context.TraceIdentifier = requestId;
        context.Response.Headers[HeaderName] = requestId;
        using (Serilog.Context.LogContext.PushProperty("RequestId", requestId))
        {
            await next(context);
        }
    }
}

using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

public sealed class GlobalExceptionHandler(IProblemDetailsService problemDetailsService, IHostEnvironment env) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var actionContext = new ActionContext
        {
            HttpContext = httpContext,
            RouteData = httpContext.GetRouteData(),
            ActionDescriptor = new Microsoft.AspNetCore.Mvc.Abstractions.ActionDescriptor()
        };

        var result = AppResponse.InternalError(
            exception,
            statusCode: 500,
            includeExceptionDetails: env.IsDevelopment()
        );

        await result.ExecuteResultAsync(actionContext);
        return true;
    }
}

using Microsoft.AspNetCore.Mvc;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;
using System.Reflection;

public sealed class AppResponseEnvelopeOperationFilter : IOperationFilter
{
    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        // If dev explicitly documented responses, don't override.
        // (You can remove this block if you want to always force envelope.)
        if (context.ApiDescription.SupportedResponseTypes.Any(r =>
            r.ApiResponseFormats?.Any() == true && r.Type != null &&
            (HasProducesResponseTypeAttribute(context.MethodInfo))))
        {
            return;
        }

        var methodReturn = context.MethodInfo.ReturnType;
        var innerType = UnwrapReturnType(methodReturn);

        // If we can't infer a model type (pure IActionResult), fall back to object
        var successBodyType = innerType ?? typeof(object);

        // OpenApi 2.x: Responses/Content are nullable
        if (operation.Responses is null)
            return;

        foreach (var (statusCode, response) in operation.Responses.ToList())
        {
            // only wrap application/json responses
            if (response.Content is null || !response.Content.TryGetValue("application/json", out var mediaType))
                continue;

            if (IsSuccessStatusCode(statusCode))
            {
                var envelopeType = typeof(AppResponse<>).MakeGenericType(successBodyType);
                mediaType.Schema = context.SchemaGenerator.GenerateSchema(envelopeType, context.SchemaRepository);
            }
            else
            {
                // errors typically don't have a typed body
                var envelopeType = typeof(AppResponse<>).MakeGenericType(typeof(object));
                mediaType.Schema = context.SchemaGenerator.GenerateSchema(envelopeType, context.SchemaRepository);
            }
        }
    }

    static bool IsSuccessStatusCode(string statusCode)
        => statusCode.StartsWith("2") || statusCode.StartsWith("3");

    static bool HasProducesResponseTypeAttribute(MethodInfo method)
        => method.GetCustomAttributes(true).OfType<ProducesResponseTypeAttribute>().Any();

    static Type? UnwrapReturnType(Type t)
    {
        // Task<T>
        if (t.IsGenericType && t.GetGenericTypeDefinition() == typeof(Task<>))
            t = t.GetGenericArguments()[0];

        // ValueTask<T>
        if (t.IsGenericType && t.GetGenericTypeDefinition() == typeof(ValueTask<>))
            t = t.GetGenericArguments()[0];

        // ActionResult<T>
        if (t.IsGenericType && t.GetGenericTypeDefinition() == typeof(ActionResult<>))
            return t.GetGenericArguments()[0];

        // AppResponse<T>
        if (t.IsGenericType && t.GetGenericTypeDefinition().Name.StartsWith("AppResponse`"))
            return t.GetGenericArguments()[0];

        // Plain T (rare, but if you return DTO directly)
        if (t != typeof(IActionResult) && !typeof(IActionResult).IsAssignableFrom(t))
            return t;

        // IActionResult -> unknown
        return null;
    }
}

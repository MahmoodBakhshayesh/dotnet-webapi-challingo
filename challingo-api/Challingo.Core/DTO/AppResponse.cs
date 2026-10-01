using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Newtonsoft.Json;
using System.Net;

#region Payloads (what gets serialized)

public sealed class AppResponsePayload<T>
{
    [JsonProperty("status", Order = 1)]
    public int Status { get; }

    [JsonProperty("message", Order = 2)]
    public string Message { get; }

    [JsonProperty("problem", Order = 3, NullValueHandling = NullValueHandling.Ignore)]
    public ProblemDetails? Problem { get; }

    [JsonProperty("body", Order = 4, NullValueHandling = NullValueHandling.Ignore)]
    public T? Body { get; }

    public AppResponsePayload(int status, string message, T? body, ProblemDetails? problem)
    {
        Status = status;
        Message = message;
        Body = body;
        Problem = problem;
    }
}

#endregion

#region Result types (NOT serialized)

public abstract class AppResponseBase : ActionResult
{
    [JsonIgnore] // never leak internal fields if someone accidentally serializes this
    public int StatusCode { get; }

    [JsonIgnore]
    public string Message { get; }

    [JsonIgnore]
    protected bool IsSuccess => StatusCode < 400;

    [JsonIgnore]
    protected int Status => IsSuccess ? StatusCode : -StatusCode;

    protected AppResponseBase(int statusCode, string message)
    {
        StatusCode = statusCode;
        Message = string.IsNullOrWhiteSpace(message) ? DefaultMessage(statusCode) : message;
    }

    public override async Task ExecuteResultAsync(ActionContext context)
    {
        var (payload, location) = CreatePayload(context);

        if (!string.IsNullOrWhiteSpace(location))
            context.HttpContext.Response.Headers.Location = location;

        var result = new ObjectResult(payload)
        {
            StatusCode = StatusCode
        };

        await result.ExecuteResultAsync(context);
    }

    /// <summary>
    /// Returns: payload object + optional redirect location header value
    /// </summary>
    protected abstract (object payload, string? location) CreatePayload(ActionContext context);

    protected static string DefaultMessage(int statusCode)
        => statusCode switch
        {
            (int)HttpStatusCode.OK => "Done",
            (int)HttpStatusCode.Created => "Created",
            (int)HttpStatusCode.NoContent => "Done",
            (int)HttpStatusCode.BadRequest => "Request error",
            (int)HttpStatusCode.Unauthorized => "Unauthorized",
            (int)HttpStatusCode.Forbidden => "Forbidden",
            (int)HttpStatusCode.NotFound => "Not found",
            (int)HttpStatusCode.Conflict => "Conflict",
            (int)HttpStatusCode.UnprocessableEntity => "Validation error",
            (int)HttpStatusCode.InternalServerError => "Internal error",
            _ => "Done"
        };
}

public sealed class AppResponse<T> : AppResponseBase
{
    [JsonIgnore] public T? Body { get; }
    [JsonIgnore] public ProblemDetails? Problem { get; }
    [JsonIgnore] private string? Location { get; }

    private AppResponse(int statusCode, string message, T? body, ProblemDetails? problem, string? location = null)
        : base(statusCode, message)
    {
        Body = body;
        Problem = problem;
        Location = location;

        if (!IsSuccess && Problem is not null)
        {
            Problem.Title ??= Message;
            Problem.Detail ??= Message;
            Problem.Status ??= StatusCode;
        }
    }

    protected override (object payload, string? location) CreatePayload(ActionContext context)
    {
        if (Problem is not null)
            Problem.Extensions["traceId"] = context.HttpContext.TraceIdentifier;

        var payload = new AppResponsePayload<T>(
            status: Status,
            message: Message,
            body: IsSuccess ? Body : default,
            problem: IsSuccess ? null : Problem
        );

        return (payload, Location);
    }

    // -------- FACTORIES --------

    public static AppResponse<T> Ok(T? body = default, string? message = null, int statusCode = 200)
        => new(statusCode, message ?? DefaultMessage(statusCode), body, problem: null);

    public static AppResponse<T> Redirect(string location, T? body = default, string? message = null, int statusCode = 302)
        => new(statusCode, message ?? DefaultMessage(statusCode), body, problem: null, location: location);

    public static AppResponse<T> RequestError(ProblemDetails problem, string? message = null, int statusCode = 400)
    {
        problem.Status = statusCode;
        var finalMessage = message ?? problem.Title ?? DefaultMessage(statusCode);
        problem.Title = finalMessage;
        problem.Detail ??= finalMessage;

        return new(statusCode, finalMessage, body: default, problem);
    }

    public static AppResponse<T> RequestError(ModelStateDictionary modelState, string? message = null, int statusCode = 400)
    {
        var pd = new ValidationProblemDetails(modelState) { Status = statusCode };
        var finalMessage = message ?? DefaultMessage(statusCode);
        pd.Title = finalMessage;
        pd.Detail = finalMessage;

        return new(statusCode, finalMessage, body: default, pd);
    }

    public static AppResponse<T> RequestError(string message, int statusCode = 400, string? type = null)
    {
        var pd = new ProblemDetails
        {
            Status = statusCode,
            Title = message,
            Detail = message,
            Type = type
        };

        return new(statusCode, message, body: default, pd);
    }

    public static AppResponse<T> InternalError(Exception ex, string? message = null, int statusCode = 500, bool includeExceptionDetails = false)
    {
        var finalMessage = message ?? "Internal error";

        var pd = new ProblemDetails
        {
            Status = statusCode,
            Title = finalMessage,
            Detail = finalMessage
        };

        if (includeExceptionDetails)
        {
            pd.Extensions["exception"] = ex.GetType().FullName;
            pd.Extensions["exceptionMessage"] = ex.Message;
        }

        return new(statusCode, finalMessage, body: default, pd);
    }
}

#endregion

#region Convenience wrapper

public static class AppResponse
{
    public static AppResponse<T> Ok<T>(T? body = default, string? message = null, int statusCode = 200)
        => AppResponse<T>.Ok(body, message, statusCode);

    public static AppResponse<object?> Ok(string? message = null, int statusCode = 200)
        => AppResponse<object?>.Ok(null, message, statusCode);

    // Strongly recommended: expose list as IReadOnlyList<T> in API contract
    public static AppResponse<IReadOnlyList<T>> OkList<T>(IEnumerable<T> body, string? message = null, int statusCode = 200)
        => AppResponse<IReadOnlyList<T>>.Ok(body.ToList(), message, statusCode);

    public static AppResponse<T> Redirect<T>(string location, T? body = default, string? message = null, int statusCode = 302)
        => AppResponse<T>.Redirect(location, body, message, statusCode);

    public static AppResponse<object?> Redirect(string location, string? message = null, int statusCode = 302)
        => AppResponse<object?>.Redirect(location, null, message, statusCode);

    public static AppResponse<object?> RequestError(ProblemDetails problem, string? message = null, int statusCode = 400)
        => AppResponse<object?>.RequestError(problem, message, statusCode);

    public static AppResponse<object?> RequestError(ModelStateDictionary modelState, string? message = null, int statusCode = 400)
        => AppResponse<object?>.RequestError(modelState, message, statusCode);

    public static AppResponse<object?> RequestError(string message, int statusCode = 400, string? type = null)
        => AppResponse<object?>.RequestError(message, statusCode, type);

    public static AppResponse<object?> NotFound(string message = "Not found", string? type = null)
        => AppResponse<object?>.RequestError(message, statusCode: 404, type: type);

    public static AppResponse<object?> Unauthorized(string message = "Unauthorized", string? type = null)
        => AppResponse<object?>.RequestError(message, statusCode: 401, type: type);

    public static AppResponse<object?> Forbidden(string message = "Forbidden", string? type = null)
        => AppResponse<object?>.RequestError(message, statusCode: 403, type: type);

    public static AppResponse<object?> InternalError(Exception ex, string? message = null, int statusCode = 500, bool includeExceptionDetails = false)
        => AppResponse<object?>.InternalError(ex, message, statusCode, includeExceptionDetails);
}

#endregion

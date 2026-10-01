using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Sms;

/// <summary>
/// sms.ir REST client — OTP via POST https://api.sms.ir/v1/send/verify (x-api-key header).
/// </summary>
public sealed class SmsIrSmsSender(
    HttpClient http,
    IOptions<SmsOptions> options,
    ILogger<SmsIrSmsSender> logger) : ISmsSender
{
    private const string VerifyUrl = "https://api.sms.ir/v1/send/verify";
    private const string BulkUrl = "https://api.sms.ir/v1/send/bulk";

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public async Task SendOtpAsync(string phoneNumber, string code, CancellationToken ct = default)
    {
        var sms = options.Value;
        if (string.IsNullOrWhiteSpace(sms.SmsIrApiKey))
        {
            throw new InvalidOperationException("Sms:SmsIrApiKey is not configured.");
        }

        if (sms.SmsIrVerifyTemplateId is { } templateId and > 0)
        {
            await SendVerifyAsync(phoneNumber, templateId, sms.SmsIrVerifyCodeParameterName, code, ct);
            return;
        }

        var message = sms.OtpMessageTemplate.Replace("{code}", code, StringComparison.Ordinal);
        await SendAsync(phoneNumber, message, ct);
    }

    public async Task SendAsync(string phoneNumber, string message, CancellationToken ct = default)
    {
        var sms = options.Value;
        if (string.IsNullOrWhiteSpace(sms.SmsIrApiKey))
        {
            throw new InvalidOperationException("Sms:SmsIrApiKey is not configured.");
        }

        if (sms.SmsIrLineNumber is not { } lineNumber || lineNumber <= 0)
        {
            logger.LogWarning(
                "sms.ir bulk send skipped: SmsIrLineNumber not set. Phone={Phone}",
                phoneNumber);
            return;
        }

        var mobile = SmsIrMobile.Normalize(phoneNumber);
        var payload = new SmsIrBulkRequest(lineNumber, message, [mobile]);
        using var request = CreateRequest(HttpMethod.Post, BulkUrl);
        request.Content = JsonContent.Create(payload, options: JsonOpts);

        var response = await http.SendAsync(request, ct);
        await EnsureSuccessAsync(response, "bulk send", ct);
    }

    private async Task SendVerifyAsync(
        string phoneNumber,
        int templateId,
        string parameterName,
        string code,
        CancellationToken ct)
    {
        var mobile = SmsIrMobile.Normalize(phoneNumber);
        var payload = new SmsIrVerifyRequest(
            mobile,
            templateId,
            [new SmsIrVerifyParameter(parameterName, code)]);

        using var request = CreateRequest(HttpMethod.Post, VerifyUrl);
        request.Content = JsonContent.Create(payload, options: JsonOpts);

        logger.LogDebug(
            "sms.ir verify send mobile={Mobile} templateId={TemplateId} param={Param}",
            mobile,
            templateId,
            parameterName);

        var response = await http.SendAsync(request, ct);
        await EnsureSuccessAsync(response, "verify send", ct);
    }

    private HttpRequestMessage CreateRequest(HttpMethod method, string url)
    {
        var request = new HttpRequestMessage(method, url);
        request.Headers.TryAddWithoutValidation("x-api-key", options.Value.SmsIrApiKey);
        request.Headers.TryAddWithoutValidation("Accept", "application/json");
        return request;
    }

    private async Task EnsureSuccessAsync(
        HttpResponseMessage response,
        string operation,
        CancellationToken ct)
    {
        var body = await response.Content.ReadAsStringAsync(ct);
        if (response.IsSuccessStatusCode)
        {
            logger.LogInformation("sms.ir {Operation} succeeded ({Status})", operation, (int)response.StatusCode);
            return;
        }

        logger.LogError(
            "sms.ir {Operation} failed ({Status}): {Body}",
            operation,
            (int)response.StatusCode,
            body);
        throw new InvalidOperationException(
            $"sms.ir {operation} failed ({(int)response.StatusCode}): {body}");
    }

    private sealed record SmsIrVerifyParameter(string Name, string Value);

    private sealed record SmsIrVerifyRequest(
        string Mobile,
        int TemplateId,
        SmsIrVerifyParameter[] Parameters);

    private sealed record SmsIrBulkRequest(
        long LineNumber,
        string MessageText,
        string[] Mobiles);
}

namespace Challingo.Core.Settings;

public sealed class SmsOptions
{
    /// <summary>SmsIr | LogOnly</summary>
    public string Provider { get; set; } = "LogOnly";

    /// <summary>API key from https://app.sms.ir/developer/list — sent as x-api-key header.</summary>
    public string? SmsIrApiKey { get; set; }

    /// <summary>Dedicated line for bulk send when verify template is not used.</summary>
    public long? SmsIrLineNumber { get; set; }

    /// <summary>sms.ir verify template id (POST /v1/send/verify).</summary>
    public int? SmsIrVerifyTemplateId { get; set; }

    /// <summary>Template parameter name without #, e.g. CODE.</summary>
    public string SmsIrVerifyCodeParameterName { get; set; } = "CODE";

    /// <summary>Fallback OTP text when verify template id is not set.</summary>
    public string OtpMessageTemplate { get; set; } = "کد ورود Challingo: {code}";
}

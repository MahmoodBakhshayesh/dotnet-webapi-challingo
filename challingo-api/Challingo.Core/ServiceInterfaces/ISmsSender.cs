namespace Challingo.Core.ServiceInterfaces;

public interface ISmsSender
{
    Task SendAsync(string phoneNumber, string message, CancellationToken ct = default);

    /// <summary>OTP via sms.ir verify template when SmsIrVerifyTemplateId is configured.</summary>
    Task SendOtpAsync(string phoneNumber, string code, CancellationToken ct = default);
}

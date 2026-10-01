namespace Challingo.Core.ServiceInterfaces;

public interface IOtpService
{
    Task SendOtpAsync(string channelKey, Guid? userId = null, CancellationToken ct = default);
    Task<bool> VerifyOtpAsync(string channelKey, string code, CancellationToken ct = default);
}

namespace Challingo.Core.ServiceInterfaces;

/// <summary>Signs and checks attempt tokens (HMAC over attempt id + user id).</summary>
public interface IAttemptTokenService
{
    string Create(Guid attemptId, Guid userId);
    bool IsValid(string? token, Guid attemptId, Guid userId);
}

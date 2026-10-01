namespace Challingo.Core.Messaging;

public static class EmailOtpHelper
{
    public static string OtpKey(string email) =>
        $"email:{email.Trim().ToLowerInvariant()}";

    public static bool TryParseEmailFromOtpKey(string otpKey, out string email)
    {
        email = "";
        if (!otpKey.StartsWith("email:", StringComparison.OrdinalIgnoreCase))
            return false;
        email = otpKey["email:".Length..].Trim();
        return email.Contains('@');
    }
}

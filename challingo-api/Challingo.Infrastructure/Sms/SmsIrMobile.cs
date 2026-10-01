namespace Challingo.Infrastructure.Sms;

internal static class SmsIrMobile
{
    /// <summary>Normalize to sms.ir format (e.g. 9120000000 — no leading 0 or +98).</summary>
    public static string Normalize(string phoneNumber)
    {
        var digits = new string(phoneNumber.Where(char.IsDigit).ToArray());
        if (digits.StartsWith("98", StringComparison.Ordinal) && digits.Length >= 12)
        {
            digits = digits[2..];
        }

        if (digits.StartsWith('0') && digits.Length >= 11)
        {
            digits = digits[1..];
        }

        return digits;
    }
}

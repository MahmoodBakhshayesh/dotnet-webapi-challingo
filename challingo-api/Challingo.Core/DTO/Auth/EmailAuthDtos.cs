namespace Challingo.Core.DTO.Auth;

public class RequestEmailOtpRequest
{
    public string Email { get; set; } = "";
}

public class VerifyEmailOtpRequest
{
    public string Email { get; set; } = "";
    public string Code { get; set; } = "";
}

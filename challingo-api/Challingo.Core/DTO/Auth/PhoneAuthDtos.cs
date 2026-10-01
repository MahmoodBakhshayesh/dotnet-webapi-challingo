namespace Challingo.Core.DTO.Auth;

public class CheckPhoneRequest
{
    public required string PhoneNumber { get; set; }
}

public class CheckPhoneResponse
{
    public bool Exists { get; set; }
    public bool IsConfirmed { get; set; }
    public bool RequiresRegistration { get; set; }
    public bool CanLoginWithPassword { get; set; }
    public bool CanLoginWithOtp { get; set; }
}

public class RegisterPhoneRequest
{
    public required string PhoneNumber { get; set; }
}

public class ConfirmOtpRequest
{
    public required string PhoneNumber { get; set; }
    public required string Code { get; set; }
}

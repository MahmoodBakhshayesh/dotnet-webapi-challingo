using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.Auth;
using Challingo.Core.DTO.LoginDto;

namespace Challingo.Core.ServiceInterfaces;

public interface IEmailAuthService
{
    Task<ActionResult> RequestLoginOtpAsync(RequestEmailOtpRequest request);
    Task<ActionResult<UserLoginResponse>> VerifyLoginOtpAsync(VerifyEmailOtpRequest request);
    Task<ActionResult> RegisterAsync(RequestEmailOtpRequest request);
    Task<ActionResult<UserLoginResponse>> ConfirmRegisterAsync(VerifyEmailOtpRequest request);
}

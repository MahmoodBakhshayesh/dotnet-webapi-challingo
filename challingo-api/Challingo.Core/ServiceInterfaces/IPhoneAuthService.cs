using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.Auth;
using Challingo.Core.DTO.LoginDto;

namespace Challingo.Core.ServiceInterfaces;

public interface IPhoneAuthService
{
    Task<ActionResult<CheckPhoneResponse>> CheckPhoneAsync(CheckPhoneRequest request);
    Task<ActionResult> RegisterAsync(RegisterPhoneRequest request);
    Task<ActionResult<UserLoginResponse>> ConfirmRegisterAsync(ConfirmOtpRequest request);
    Task<ActionResult> RequestLoginOtpAsync(CheckPhoneRequest request);
    Task<ActionResult<UserLoginResponse>> ConfirmLoginOtpAsync(ConfirmOtpRequest request);
}

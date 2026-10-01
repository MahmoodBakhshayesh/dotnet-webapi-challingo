using Microsoft.AspNetCore.Identity.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Challingo.Core.DTO.Auth;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.DTO.Token;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Api.Controllers;

public class AuthController(
    IAuthService authService,
    IPhoneAuthService phoneAuthService,
    IEmailAuthService emailAuthService,
    IGoogleAuthService googleAuthService) : AppController
{
    [EnableRateLimiting("auth-otp")]
    [HttpPost("google")]
    public Task<ActionResult<UserLoginResponse>> GoogleLogin(GoogleLoginRequest request) =>
        googleAuthService.LoginWithIdTokenAsync(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("otp/request")]
    public Task<ActionResult> RequestEmailOtp(RequestEmailOtpRequest request) =>
        emailAuthService.RequestLoginOtpAsync(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("otp/verify")]
    public Task<ActionResult<UserLoginResponse>> VerifyEmailOtp(VerifyEmailOtpRequest request) =>
        emailAuthService.VerifyLoginOtpAsync(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("register/email")]
    public Task<ActionResult> RegisterEmail(RequestEmailOtpRequest request) =>
        emailAuthService.RegisterAsync(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("register/email/confirm")]
    public Task<ActionResult<UserLoginResponse>> ConfirmRegisterEmail(VerifyEmailOtpRequest request) =>
        emailAuthService.ConfirmRegisterAsync(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("check-phone")]
    public Task<ActionResult<CheckPhoneResponse>> CheckPhone(CheckPhoneRequest request) =>
        phoneAuthService.CheckPhoneAsync(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("register")]
    public Task<ActionResult> Register(RegisterPhoneRequest request) =>
        phoneAuthService.RegisterAsync(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("register/confirm")]
    public Task<ActionResult<UserLoginResponse>> ConfirmRegister(ConfirmOtpRequest request) =>
        phoneAuthService.ConfirmRegisterAsync(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("login/otp/request")]
    public Task<ActionResult> RequestLoginOtp(CheckPhoneRequest request) =>
        phoneAuthService.RequestLoginOtpAsync(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("login/otp/confirm")]
    public Task<ActionResult<UserLoginResponse>> ConfirmLoginOtp(ConfirmOtpRequest request) =>
        phoneAuthService.ConfirmLoginOtpAsync(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("login")]
    public Task<ActionResult<UserLoginResponse>> Login(UserLoginRequest request) =>
        authService.Login(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("refresh")]
    public Task<ActionResult<TokenResponse>> Refresh(RefreshRequest request) =>
        authService.Refresh(request);

    [EnableRateLimiting("auth-otp")]
    [HttpPost("logout")]
    public Task<ActionResult> Logout() =>
        authService.Logout();
}

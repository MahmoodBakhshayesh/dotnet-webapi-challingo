using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Auth;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.Messaging;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

public sealed class EmailAuthService(
    IPhoneAuthRepository phoneAuth,
    IOtpService otpService,
    IAuthSessionService authSession,
    IOptions<AuthOptions> authOptions) : IEmailAuthService
{
    public Task<ActionResult> RequestLoginOtpAsync(RequestEmailOtpRequest request)
    {
        if (!authOptions.Value.EnableEmailAuth)
            return Task.FromResult<ActionResult>(AppResponse.RequestError("Email authentication is disabled."));
        return RequestLoginOtpCoreAsync(request);
    }

    public Task<ActionResult<UserLoginResponse>> VerifyLoginOtpAsync(VerifyEmailOtpRequest request)
    {
        if (!authOptions.Value.EnableEmailAuth)
            return Task.FromResult<ActionResult<UserLoginResponse>>(AppResponse.RequestError("Email authentication is disabled."));
        return VerifyLoginOtpCoreAsync(request);
    }

    public Task<ActionResult> RegisterAsync(RequestEmailOtpRequest request)
    {
        if (!authOptions.Value.EnableEmailAuth)
            return Task.FromResult<ActionResult>(AppResponse.RequestError("Email authentication is disabled."));
        return RegisterCoreAsync(request);
    }

    public Task<ActionResult<UserLoginResponse>> ConfirmRegisterAsync(VerifyEmailOtpRequest request)
    {
        if (!authOptions.Value.EnableEmailAuth)
            return Task.FromResult<ActionResult<UserLoginResponse>>(AppResponse.RequestError("Email authentication is disabled."));
        return ConfirmRegisterCoreAsync(request);
    }

    private async Task<ActionResult> RequestLoginOtpCoreAsync(RequestEmailOtpRequest request)
    {
        var email = NormalizeEmail(request.Email);
        if (string.IsNullOrEmpty(email) || !email.Contains('@'))
            return AppResponse.RequestError("Invalid email address.");

        var user = await phoneAuth.FindByEmailAsync(email);
        if (user == null)
            return AppResponse.NotFound("No account with this email.");

        await otpService.SendOtpAsync(EmailOtpHelper.OtpKey(email), user.Id);
        return AppResponse.Ok(message: "OTP sent.");
    }

    private async Task<ActionResult<UserLoginResponse>> VerifyLoginOtpCoreAsync(VerifyEmailOtpRequest request)
    {
        var email = NormalizeEmail(request.Email);
        if (string.IsNullOrEmpty(email) || !email.Contains('@'))
            return AppResponse.RequestError("Invalid email address.");

        if (!await otpService.VerifyOtpAsync(EmailOtpHelper.OtpKey(email), request.Code))
            return AppResponse.RequestError("Invalid or expired OTP.");

        var user = await phoneAuth.FindByEmailAsync(email);
        if (user == null)
            return AppResponse.NotFound();

        return await authSession.IssueTokensAsync(user);
    }

    private async Task<ActionResult> RegisterCoreAsync(RequestEmailOtpRequest request)
    {
        var email = NormalizeEmail(request.Email);
        if (string.IsNullOrEmpty(email) || !email.Contains('@'))
            return AppResponse.RequestError("Invalid email address.");

        var existing = await phoneAuth.FindByEmailAsync(email);
        if (existing != null)
            return AppResponse.RequestError("This email is already registered.", 409);

        await otpService.SendOtpAsync(EmailOtpHelper.OtpKey(email));
        return AppResponse.Ok(message: "OTP sent.");
    }

    private async Task<ActionResult<UserLoginResponse>> ConfirmRegisterCoreAsync(VerifyEmailOtpRequest request)
    {
        var email = NormalizeEmail(request.Email);
        if (string.IsNullOrEmpty(email) || !email.Contains('@'))
            return AppResponse.RequestError("Invalid email address.");

        if (!await otpService.VerifyOtpAsync(EmailOtpHelper.OtpKey(email), request.Code))
            return AppResponse.RequestError("Invalid or expired OTP.");

        var user = await phoneAuth.FindByEmailAsync(email);
        if (user == null)
            user = await phoneAuth.CreateEmailUserAsync(email);

        return await authSession.IssueTokensAsync(user);
    }

    private static string NormalizeEmail(string email) =>
        email.Trim().ToLowerInvariant();
}

using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Auth;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

public sealed class PhoneAuthService(
    IPhoneAuthRepository phoneAuth,
    IOtpService otpService,
    IAuthSessionService authSession,
    IOptions<AuthOptions> authOptions) : IPhoneAuthService
{
    public Task<ActionResult<CheckPhoneResponse>> CheckPhoneAsync(CheckPhoneRequest request)
    {
        if (!authOptions.Value.EnablePhoneAuth)
            return Task.FromResult<ActionResult<CheckPhoneResponse>>(AppResponse.RequestError("Phone authentication is disabled."));
        return CheckPhoneCoreAsync(request);
    }

    public Task<ActionResult> RegisterAsync(RegisterPhoneRequest request)
    {
        if (!authOptions.Value.EnablePhoneAuth)
            return Task.FromResult<ActionResult>(AppResponse.RequestError("Phone authentication is disabled."));
        return RegisterCoreAsync(request);
    }

    public Task<ActionResult<UserLoginResponse>> ConfirmRegisterAsync(ConfirmOtpRequest request)
    {
        if (!authOptions.Value.EnablePhoneAuth)
            return Task.FromResult<ActionResult<UserLoginResponse>>(AppResponse.RequestError("Phone authentication is disabled."));
        return ConfirmRegisterCoreAsync(request);
    }

    public Task<ActionResult> RequestLoginOtpAsync(CheckPhoneRequest request)
    {
        if (!authOptions.Value.EnablePhoneAuth)
            return Task.FromResult<ActionResult>(AppResponse.RequestError("Phone authentication is disabled."));
        return RequestLoginOtpCoreAsync(request);
    }

    public Task<ActionResult<UserLoginResponse>> ConfirmLoginOtpAsync(ConfirmOtpRequest request)
    {
        if (!authOptions.Value.EnablePhoneAuth)
            return Task.FromResult<ActionResult<UserLoginResponse>>(AppResponse.RequestError("Phone authentication is disabled."));
        return ConfirmLoginCoreAsync(request);
    }

    private async Task<ActionResult<CheckPhoneResponse>> CheckPhoneCoreAsync(CheckPhoneRequest request)
    {
        var user = await phoneAuth.FindByPhoneAsync(request.PhoneNumber);
        if (user == null)
        {
            return AppResponse.Ok(new CheckPhoneResponse
            {
                Exists = false,
                RequiresRegistration = true,
                CanLoginWithOtp = true
            });
        }

        var hasPassword = await phoneAuth.HasPasswordAsync(user);
        return AppResponse.Ok(new CheckPhoneResponse
        {
            Exists = true,
            IsConfirmed = user.PhoneNumberConfirmed,
            RequiresRegistration = false,
            CanLoginWithPassword = hasPassword,
            CanLoginWithOtp = true
        });
    }

    private async Task<ActionResult> RegisterCoreAsync(RegisterPhoneRequest request)
    {
        var existing = await phoneAuth.FindByPhoneAsync(request.PhoneNumber);
        if (existing != null)
            return AppResponse.RequestError("Phone already registered.", 409);

        await otpService.SendOtpAsync(request.PhoneNumber);
        return AppResponse.Ok(message: "OTP sent.");
    }

    private async Task<ActionResult<UserLoginResponse>> ConfirmRegisterCoreAsync(ConfirmOtpRequest request)
    {
        if (!await otpService.VerifyOtpAsync(request.PhoneNumber, request.Code))
            return AppResponse.RequestError("Invalid or expired OTP.");

        var user = await phoneAuth.FindByPhoneAsync(request.PhoneNumber);
        if (user == null)
            user = await phoneAuth.CreatePhoneUserAsync(request.PhoneNumber);

        return await authSession.IssueTokensAsync(user);
    }

    private async Task<ActionResult> RequestLoginOtpCoreAsync(CheckPhoneRequest request)
    {
        var user = await phoneAuth.FindByPhoneAsync(request.PhoneNumber);
        if (user == null)
            return AppResponse.NotFound("No account with this phone number.");

        await otpService.SendOtpAsync(request.PhoneNumber, user.Id);
        return AppResponse.Ok(message: "OTP sent.");
    }

    private async Task<ActionResult<UserLoginResponse>> ConfirmLoginCoreAsync(ConfirmOtpRequest request)
    {
        if (!await otpService.VerifyOtpAsync(request.PhoneNumber, request.Code))
            return AppResponse.RequestError("Invalid or expired OTP.");

        var user = await phoneAuth.FindByPhoneAsync(request.PhoneNumber);
        if (user == null)
            return AppResponse.NotFound();

        return await authSession.IssueTokensAsync(user);
    }
}

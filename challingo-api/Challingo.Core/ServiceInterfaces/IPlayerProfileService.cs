using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.Auth;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.DTO.Players;

namespace Challingo.Core.ServiceInterfaces;

public interface IPlayerProfileService
{
    Task<ActionResult<UserLoginResponse>> CreateGuestAsync(CreateGuestRequest request);
    Task<ActionResult<MeResponse>> GetMeAsync(Guid userId);
    Task<ActionResult<MeResponse>> UpdateMeAsync(Guid userId, UpdateMeRequest request);
    Task<ActionResult<MeResponse>> SetTimeZoneAsync(Guid userId, SetTimeZoneRequest request);

    /// <summary>Guest upgrade, step 1: email a code to an address not yet in use.</summary>
    Task<ActionResult> RequestEmailLinkAsync(Guid userId, RequestEmailOtpRequest request);

    /// <summary>Guest upgrade, step 2: confirm the code; the same account (and its progress) gets the email.</summary>
    Task<ActionResult<UserLoginResponse>> ConfirmEmailLinkAsync(Guid userId, VerifyEmailOtpRequest request);
}

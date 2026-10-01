using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Challingo.Api.Extensions;
using Challingo.Core.DTO.Auth;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.DTO.Players;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Api.Controllers;

/// <summary>The signed-in player's own profile (guests included).</summary>
[Authorize]
public class MeController(IPlayerProfileService profiles) : AppController
{
    [HttpGet]
    public async Task<ActionResult<MeResponse>> Get() =>
        User.GetUserId() is { } id ? await profiles.GetMeAsync(id) : Unauthorized();

    [HttpPut]
    public async Task<ActionResult<MeResponse>> Update(UpdateMeRequest request) =>
        User.GetUserId() is { } id ? await profiles.UpdateMeAsync(id, request) : Unauthorized();

    [HttpPut("timezone")]
    public async Task<ActionResult<MeResponse>> SetTimeZone(SetTimeZoneRequest request) =>
        User.GetUserId() is { } id ? await profiles.SetTimeZoneAsync(id, request) : Unauthorized();

    /// <summary>Guest upgrade: send a code to the email that will be attached to this account.</summary>
    [EnableRateLimiting("auth-otp")]
    [HttpPost("email/request")]
    public async Task<ActionResult> RequestEmailLink(RequestEmailOtpRequest request) =>
        User.GetUserId() is { } id ? await profiles.RequestEmailLinkAsync(id, request) : Unauthorized();

    /// <summary>Guest upgrade: confirm the code; returns new tokens for the same account.</summary>
    [EnableRateLimiting("auth-otp")]
    [HttpPost("email/confirm")]
    public async Task<ActionResult<UserLoginResponse>> ConfirmEmailLink(VerifyEmailOtpRequest request) =>
        User.GetUserId() is { } id ? await profiles.ConfirmEmailLinkAsync(id, request) : Unauthorized();
}

using Microsoft.AspNetCore.Mvc;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Auth;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.DTO.Players;
using Challingo.Core.Messaging;
using Challingo.Core.Players;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Core.Services;

public sealed class PlayerProfileService(
    IPlayerProfileRepository profiles,
    IAccountRepository accounts,
    IPhoneAuthRepository userLookup,
    IOtpService otpService,
    IAuthSessionService authSession,
    TimeProvider clock) : IPlayerProfileService
{
    public async Task<ActionResult<UserLoginResponse>> CreateGuestAsync(CreateGuestRequest request)
    {
        var user = await accounts.CreateGuestUserAsync();
        var zone = PlayerTimeZones.TryNormalize(request.TimeZoneId, out var canonical) ? canonical : PlayerTimeZones.Utc;
        await profiles.AddAsync(NewProfile(user, isGuest: true, zone));
        return await authSession.IssueTokensAsync(user);
    }

    public async Task<ActionResult<MeResponse>> GetMeAsync(Guid userId)
    {
        var (user, profile) = await LoadAsync(userId);
        return user is null ? AppResponse.NotFound() : AppResponse.Ok(ToMe(user, profile!));
    }

    public async Task<ActionResult<MeResponse>> UpdateMeAsync(Guid userId, UpdateMeRequest request)
    {
        var name = request.DisplayName?.Trim();
        if (!PlayerProfileRules.IsValidDisplayName(name))
            return AppResponse.RequestError("Display name must be 3 to 20 letters, digits, spaces, '-' or '_'.");

        var (user, profile) = await LoadAsync(userId);
        if (user is null)
            return AppResponse.NotFound();

        profile!.DisplayName = name!;
        await profiles.SaveAsync(profile);
        return AppResponse.Ok(ToMe(user, profile));
    }

    public async Task<ActionResult<MeResponse>> SetTimeZoneAsync(Guid userId, SetTimeZoneRequest request)
    {
        if (!PlayerTimeZones.TryNormalize(request.TimeZoneId, out var zone))
            return AppResponse.RequestError("Unknown time zone.");

        var (user, profile) = await LoadAsync(userId);
        if (user is null)
            return AppResponse.NotFound();
        if (zone == profile!.TimeZoneId)
            return AppResponse.Ok(ToMe(user, profile));

        var now = clock.GetUtcNow().UtcDateTime;
        // A profile still on the sign-up default (UTC, never changed) sets its real zone for free.
        var isFirstSet = profile.TimeZoneChangedAtUtc is null && profile.TimeZoneId == PlayerTimeZones.Utc;
        if (!isFirstSet)
        {
            var next = PlayerProfileRules.NextTimeZoneChangeAtUtc(profile);
            if (next is { } allowedAt && now < allowedAt)
                return AppResponse.RequestError($"Time zone can be changed again after {allowedAt:yyyy-MM-dd HH:mm} UTC.", 429);

            profile.PreviousTimeZoneId = profile.TimeZoneId;
            profile.TimeZoneChangedAtUtc = now;
        }

        profile.TimeZoneId = zone;
        profile.CountryCode = PlayerTimeZones.CountryFor(zone);
        await profiles.SaveAsync(profile);
        return AppResponse.Ok(ToMe(user, profile));
    }

    public async Task<ActionResult> RequestEmailLinkAsync(Guid userId, RequestEmailOtpRequest request)
    {
        var email = NormalizeEmail(request.Email);
        if (email is null)
            return AppResponse.RequestError("Invalid email address.");

        var (user, profile) = await LoadAsync(userId);
        if (user is null)
            return AppResponse.NotFound();
        if (!profile!.IsGuest)
            return AppResponse.RequestError("This account already has an email.", 409);
        if (await userLookup.FindByEmailAsync(email) is not null)
            return AppResponse.RequestError("This email is already registered. Sign in with it instead.", 409);

        await otpService.SendOtpAsync(EmailOtpHelper.OtpKey(email), user.Id);
        return AppResponse.Ok(message: "OTP sent.");
    }

    public async Task<ActionResult<UserLoginResponse>> ConfirmEmailLinkAsync(Guid userId, VerifyEmailOtpRequest request)
    {
        var email = NormalizeEmail(request.Email);
        if (email is null)
            return AppResponse.RequestError("Invalid email address.");
        if (!await otpService.VerifyOtpAsync(EmailOtpHelper.OtpKey(email), request.Code))
            return AppResponse.RequestError("Invalid or expired OTP.");

        var (user, profile) = await LoadAsync(userId);
        if (user is null)
            return AppResponse.NotFound();
        if (!profile!.IsGuest)
            return AppResponse.RequestError("This account already has an email.", 409);
        if (await userLookup.FindByEmailAsync(email) is not null)
            return AppResponse.RequestError("This email is already registered. Sign in with it instead.", 409);

        var updated = await accounts.AttachEmailAsync(userId, email);
        if (updated is null)
            return AppResponse.NotFound();

        profile.IsGuest = false;
        await profiles.SaveAsync(profile);
        // The user name changed to the email, so issue fresh tokens.
        return await authSession.IssueTokensAsync(updated);
    }

    /// <summary>Loads the account and its profile, creating the profile on first use (e.g. after email sign-up).</summary>
    private async Task<(AppUser? User, PlayerProfile? Profile)> LoadAsync(Guid userId)
    {
        var user = await accounts.FindByIdAsync(userId);
        if (user is null)
            return (null, null);

        var profile = await profiles.GetByUserIdAsync(userId);
        if (profile is null)
        {
            profile = NewProfile(user, isGuest: string.IsNullOrEmpty(user.Email), PlayerTimeZones.Utc);
            await profiles.AddAsync(profile);
        }
        return (user, profile);
    }

    private MeResponse ToMe(AppUser user, PlayerProfile profile)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var next = PlayerProfileRules.NextTimeZoneChangeAtUtc(profile);
        return new MeResponse
        {
            UserId = user.Id,
            DisplayName = profile.DisplayName,
            IsGuest = profile.IsGuest,
            Email = user.Email,
            TimeZoneId = profile.TimeZoneId,
            CountryCode = profile.CountryCode,
            LocalDate = PlayerTimeZones.LocalDate(PlayerProfileRules.EffectiveTimeZone(profile, now), now),
            NextTimeZoneChangeAtUtc = next > now ? next : null,
        };
    }

    private static PlayerProfile NewProfile(AppUser user, bool isGuest, string zone) => new()
    {
        Id = Guid.CreateVersion7(),
        UserId = user.Id,
        DisplayName = PlayerProfileRules.DefaultDisplayName(),
        IsGuest = isGuest,
        TimeZoneId = zone,
        CountryCode = PlayerTimeZones.CountryFor(zone),
    };

    private static string? NormalizeEmail(string? email)
    {
        var e = email?.Trim().ToLowerInvariant();
        return string.IsNullOrEmpty(e) || !e.Contains('@') ? null : e;
    }
}

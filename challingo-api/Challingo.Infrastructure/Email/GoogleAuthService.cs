using System.Net;
using System.Text;
using System.Text.Json;
using Google.Apis.Auth;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Auth;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Email;

public sealed class GoogleAuthService(
    IOptions<GoogleAuthOptions> googleOptions,
    IPhoneAuthRepository phoneAuth,
    IAuthSessionService authSession,
    ILogger<GoogleAuthService> logger) : IGoogleAuthService
{
    public async Task<ActionResult<UserLoginResponse>> LoginWithIdTokenAsync(GoogleLoginRequest request)
    {
        var clientIds = googleOptions.Value.GetAudienceClientIds();
        if (clientIds.Length == 0)
            return AppResponse.RequestError("Google sign-in is not configured.");

        if (string.IsNullOrWhiteSpace(request.IdToken))
            return AppResponse.RequestError("Google ID token is required.");

        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await GoogleJsonWebSignature.ValidateAsync(
                request.IdToken,
                new GoogleJsonWebSignature.ValidationSettings { Audience = clientIds });
        }
        catch (InvalidJwtException ex)
        {
            logger.LogWarning(
                ex,
                "Google ID token rejected. Token aud={TokenAud}, configuredCount={ConfiguredCount}",
                TryReadJwtAudience(request.IdToken),
                clientIds.Length);
            return AppResponse.RequestError(
                "Invalid Google sign-in token. Ensure the Web OAuth client ID matches Google__ClientId on the API.");
        }
        catch (Exception ex) when (IsGoogleReachabilityFailure(ex))
        {
            logger.LogError(ex, "Google token verification failed: cannot reach Google certificate endpoint");
            return AppResponse.RequestError(
                "Google sign-in verification failed: API cannot reach googleapis.com (outbound HTTPS blocked?).");
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Google ID token validation failed");
            return AppResponse.RequestError("Invalid Google sign-in token.");
        }

        var email = payload.Email?.Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
            return AppResponse.RequestError("Google account must include a verified email.");

        if (!payload.EmailVerified)
            return AppResponse.RequestError("Google email is not verified.");

        var user = await phoneAuth.FindByEmailAsync(email);
        if (user == null)
            user = await phoneAuth.CreateEmailUserAsync(email);

        return await authSession.IssueTokensAsync(user);
    }

    private static bool IsGoogleReachabilityFailure(Exception ex)
    {
        for (var current = ex; current is not null; current = current.InnerException)
        {
            if (current is HttpRequestException or WebException or TaskCanceledException or IOException)
                return true;
        }

        return false;
    }

    private static string? TryReadJwtAudience(string jwt)
    {
        try
        {
            var parts = jwt.Split('.');
            if (parts.Length < 2)
                return null;

            var payload = parts[1];
            var pad = (4 - payload.Length % 4) % 4;
            if (pad > 0)
                payload += new string('=', pad);

            var json = Encoding.UTF8.GetString(
                Convert.FromBase64String(payload.Replace('-', '+').Replace('_', '/')));
            using var doc = JsonDocument.Parse(json);
            if (!doc.RootElement.TryGetProperty("aud", out var aud))
                return null;

            return aud.ValueKind switch
            {
                JsonValueKind.String => aud.GetString(),
                JsonValueKind.Array => string.Join(',', aud.EnumerateArray().Select(e => e.GetString())),
                _ => aud.ToString(),
            };
        }
        catch
        {
            return null;
        }
    }
}

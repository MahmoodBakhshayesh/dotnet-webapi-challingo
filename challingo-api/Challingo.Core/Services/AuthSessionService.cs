using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.DTO.Token;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

public sealed class AuthSessionService(
    IAuthRepository authRepository,
    ITokenProviderService tokenProvider,
    IOptions<JwtAuthOptions> jwtOptions) : IAuthSessionService
{
    public async Task<ActionResult<UserLoginResponse>> IssueTokensAsync(AppUser user)
    {
        var roles = await authRepository.GetUserRoles(user);
        var token = tokenProvider.Create(new TokenRequest(user.Id, user.UserName!, roles));
        var refresh = new RefreshToken
        {
            Id = Guid.CreateVersion7(),
            UserId = user.Id,
            Token = token.RefreshToken,
            ExpireAtUtc = DateTime.UtcNow.AddDays(jwtOptions.Value.RefreshTokenExpirationDays)
        };
        await authRepository.AddRefreshToken(refresh);
        return AppResponse.Ok(new UserLoginResponse
        {
            Username = user.UserName!,
            Email = user.Email,
            PhoneNumber = user.PhoneNumber,
            Roles = roles,
            Token = token
        });
    }
}

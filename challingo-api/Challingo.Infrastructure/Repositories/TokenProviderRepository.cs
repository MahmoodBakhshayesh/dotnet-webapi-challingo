using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Challingo.Core.Settings;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Token;

namespace Challingo.Infrastructure.Repositories
{
    public sealed class TokenProviderRepository(IOptions<JwtAuthOptions> options): ITokenProviderRepository
    {
        private readonly JwtAuthOptions _jwtAuthOptions = options.Value;

        public TokenResponse Create(TokenRequest tokenRequest)
        {
            return new TokenResponse { AccessToken = GenerateAccessToken(tokenRequest), RefreshToken = GenerateRefreshToken() };
        }

        private string GenerateAccessToken(TokenRequest tokenRequest)
        {
            var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtAuthOptions.Key));
            var credintials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

            List<Claim> claims = [
                    new (JwtRegisteredClaimNames.Sub,tokenRequest.UserId.ToString()),
                new (JwtRegisteredClaimNames.Name,tokenRequest.Username),
                ..tokenRequest.Roles.Select(r=>new Claim(ClaimTypes.Role,r))
                ];

            var tokenDesciptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(claims),
                Expires = DateTime.UtcNow.AddMinutes(_jwtAuthOptions.ExpirationInMinutes),
                SigningCredentials = credintials,
                Issuer = _jwtAuthOptions.Issuer,
                Audience = _jwtAuthOptions.Audience
            };

            var handler = new JsonWebTokenHandler();

            string accessToken = handler.CreateToken(tokenDesciptor);

            return accessToken;

        }

        private string GenerateRefreshToken()
        {
            byte[] randomBytes = RandomNumberGenerator.GetBytes(32);
            return Convert.ToBase64String(randomBytes);
        }
    }

}

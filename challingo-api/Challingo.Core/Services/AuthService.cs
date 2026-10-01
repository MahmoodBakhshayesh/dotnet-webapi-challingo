using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using System;
using System.Collections.Generic;
using System.Text;
using Challingo.Core.Settings;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.DTO.Token;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Core.Services
{
    public class AuthService(IAuthRepository authRepository, ITokenProviderService tokenProvider, IOptions<JwtAuthOptions> options, SignInManager<AppUser> signInManager) : IAuthService
    {
        public async Task<ActionResult<UserLoginResponse>> Login(UserLoginRequest request)
        {

            AppUser? user = await authRepository.FindUserByUsername(request.Username);
            if (user == null)
            {
                return AppResponse.NotFound("Login Faild!\nUsername or Password is Wrong!");
            }

            bool validPassword = await authRepository.CheckUserPassword(user, request.Password);
            if (!validPassword)
            {
                return AppResponse.NotFound("Login Faild!\nUsername or Password is Wrong!");
            }

            var roles = await authRepository.GetUserRoles(user);
            //var roles = user.UserRoles.Select(x => x.Role.Name!).ToList();

            TokenRequest tokenRequest = new(UserId: user.Id, Username: user.UserName!, Roles: roles);
            TokenResponse token = tokenProvider.Create(tokenRequest);


            var refreshToken = new RefreshToken { Id = Guid.CreateVersion7(), UserId = user.Id, Token = token.RefreshToken, ExpireAtUtc = DateTime.UtcNow.AddDays(options.Value.RefreshTokenExpirationDays) };

            await authRepository.AddRefreshToken(refreshToken);

            var response = new UserLoginResponse { Email = user.Email, PhoneNumber = user.PhoneNumber, Username = user.UserName!, Roles = roles, Token = token };

            return AppResponse.Ok(response);
        }
        public async Task<ActionResult<TokenResponse>> Refresh(RefreshRequest request)
        {
            RefreshToken? refreshToken = await authRepository.FindRefreshToken(request.RefreshToken);
            if (refreshToken == null)
            {
                return AppResponse.NotFound("Invalid Refresh Token!");
            }

            bool validateToken = await authRepository.ValidateRefreshToken(refreshToken);
            if (!validateToken)
            {
                return AppResponse.NotFound("Refresh Token is Expired!");
            }

            var user = refreshToken.User;
            var roles = await authRepository.GetUserRoles(user);

            TokenRequest tRequest = new(UserId: user.Id, Username: user.UserName!, Roles: roles);
            TokenResponse token = tokenProvider.Create(tRequest);

            refreshToken.Token = token.RefreshToken;
            refreshToken.ExpireAtUtc = DateTime.UtcNow.AddDays(options.Value.RefreshTokenExpirationDays);

            await authRepository.UpdateRefreshToken(refreshToken);
            return AppResponse.Ok(new { Token = token });
        }


        async Task<ActionResult> IAuthService.Logout()
        {
            await signInManager.SignOutAsync();
            return AppResponse.Ok();
        }
    }



    }

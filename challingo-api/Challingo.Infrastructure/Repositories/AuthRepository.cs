
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Text;
using Challingo.Infrastructure.DbContexts;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.DTO.Token;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Infrastructure.Repositories
{
    public class AuthRepository(AppDbContext dbContext, UserManager<AppUser> userManager) : IAuthRepository
    {


        public async Task<AppUser?> FindUserByUsername(string username)
        {
            var user = await userManager.FindByNameAsync(username);
            return user;
        }

        public async Task<bool> CheckUserPassword(AppUser user, string password)
        {
            var validPassword = await userManager.CheckPasswordAsync(user, password);
            return validPassword;
        }

        public async Task<IEnumerable<string>> GetUserRoles(AppUser user)
        {
            var roles = await userManager.GetRolesAsync(user);
            return roles;
        }

        public async Task AddRefreshToken(RefreshToken token)
        {
            dbContext.RefreshTokens.Add(token);
            await dbContext.SaveChangesAsync();
        }

        public async Task<RefreshToken?> FindRefreshToken(string token)
        {
            var refreshToken = await dbContext.RefreshTokens.Where(x => x.Token == token).Include(x => x.User).FirstOrDefaultAsync();
            return refreshToken;

        }

        public Task<bool> ValidateRefreshToken(RefreshToken token)
        {
            if (DateTime.UtcNow > token.ExpireAtUtc)
            {
                return Task.FromResult(false);
            }
            return Task.FromResult(true);
        }

        public async Task UpdateRefreshToken(RefreshToken token)
        {
            //RefreshToken? old = await FindRefreshToken(token.Token);
            var old = await dbContext.RefreshTokens.Where(x => x.Id == token.Id).FirstOrDefaultAsync();

            if (old == null)
            {
                throw new Exception("Invalid Refresh token");
            }
            old.Token = token.Token;
            old.ExpireAtUtc = token.ExpireAtUtc;
            await dbContext.SaveChangesAsync();
           
        }
    }
}

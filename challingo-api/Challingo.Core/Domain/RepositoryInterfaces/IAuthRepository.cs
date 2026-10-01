using Microsoft.AspNetCore.Identity.Data;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Text;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.DTO.Token;

namespace Challingo.Core.Domain.RepositoryInterfaces
{
    public interface IAuthRepository
    {
        public Task<AppUser?> FindUserByUsername(string username);
        public Task<bool> CheckUserPassword(AppUser user, string password);
        public Task<IEnumerable<string>> GetUserRoles(AppUser user);
        public Task AddRefreshToken(RefreshToken token);
        public Task<RefreshToken?> FindRefreshToken(string token);
        public Task<bool> ValidateRefreshToken(RefreshToken token);
        public Task UpdateRefreshToken(RefreshToken token);
    }
}

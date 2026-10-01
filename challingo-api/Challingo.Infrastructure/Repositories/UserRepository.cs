using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;
using Challingo.Infrastructure.DbContexts;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.UserDto;

namespace Challingo.Infrastructure.Repositories
{
    public class UserRepository(AppDbContext dbContext,UserManager<AppUser> userManager) : IUserRepository
    {

        public async Task<IEnumerable<UserResponse>> GetUsers()
        {
            var users =await dbContext.Users.Select(u => new UserResponse
            {
                Id = u.Id,
                Email = u.Email!,
                UserName = u.UserName!,
                PhoneNumber = u.PhoneNumber!,
                Roles = u.UserRoles.Select(ur => ur.Role.Name!).ToList()
            }).ToListAsync();
            return users;
        }
    }
}

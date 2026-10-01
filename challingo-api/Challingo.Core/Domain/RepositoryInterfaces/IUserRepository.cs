using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Text;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.DTO.UserDto;

namespace Challingo.Core.Domain.RepositoryInterfaces
{
    public interface IUserRepository
    {
        Task<IEnumerable<UserResponse>> GetUsers();

    }
}

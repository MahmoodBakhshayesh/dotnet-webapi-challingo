using Microsoft.AspNetCore.Mvc;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.DTO.LoginDto;

namespace Challingo.Core.ServiceInterfaces;

public interface IAuthSessionService
{
    Task<ActionResult<UserLoginResponse>> IssueTokensAsync(AppUser user);
}

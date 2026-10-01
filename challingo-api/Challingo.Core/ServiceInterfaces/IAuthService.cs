using Microsoft.AspNetCore.Identity.Data;
using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.LoginDto;
using Challingo.Core.DTO.Token;

namespace Challingo.Core.ServiceInterfaces
{
    public interface IAuthService
    {
        Task<ActionResult<UserLoginResponse>> Login(UserLoginRequest request);
        Task<ActionResult<TokenResponse>> Refresh(RefreshRequest request);
        Task<ActionResult> Logout();
    }
}

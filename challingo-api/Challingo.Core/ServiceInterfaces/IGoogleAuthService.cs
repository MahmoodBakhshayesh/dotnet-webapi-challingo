using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.Auth;
using Challingo.Core.DTO.LoginDto;

namespace Challingo.Core.ServiceInterfaces;

public interface IGoogleAuthService
{
    Task<ActionResult<UserLoginResponse>> LoginWithIdTokenAsync(GoogleLoginRequest request);
}

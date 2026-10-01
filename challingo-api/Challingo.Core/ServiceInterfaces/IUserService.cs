using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.UserDto;

namespace Challingo.Core.ServiceInterfaces
{
    public interface IUserService
    {
        Task<ActionResult<IReadOnlyList<UserResponse>>> GetUsers();
        Task<ActionResult<UserResponse>> GetUser(Guid id);
        Task<ActionResult<UserResponse>> AddUser(AddUserRequest request);
        Task<ActionResult<UserResponse>> UpdateUser(Guid id, UpdateUserRequest request);
        Task<IActionResult> DeleteUser(Guid id);
    }
}

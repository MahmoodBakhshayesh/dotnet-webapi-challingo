using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.UserDto;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Api.Controllers
{
    [Authorize(Roles = Roles.Admin)]
    public class UsersController(IUserService userService) : AppController
    {
        [HttpGet]
        public Task<ActionResult<IReadOnlyList<UserResponse>>> GetUsers()
            => userService.GetUsers();

        [HttpGet("{id:guid}")]
        public Task<ActionResult<UserResponse>> GetUser(Guid id)
            => userService.GetUser(id);

        [HttpPost]
        public Task<ActionResult<UserResponse>> AddUser(AddUserRequest request)
            => userService.AddUser(request);

        [HttpPut("{id:guid}")]
        public Task<ActionResult<UserResponse>> UpdateUser(Guid id, UpdateUserRequest request)
            => userService.UpdateUser(id, request);

        [HttpDelete("{id:guid}")]
        public Task<IActionResult> DeleteUser(Guid id)
            => userService.DeleteUser(id);
    }
}

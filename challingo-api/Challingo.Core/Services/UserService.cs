using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.UserDto;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services
{
    public class UserService(
        IUserRepository userRepository,
        UserManager<AppUser> userManager) : IUserService
    {
        public async Task<ActionResult<IReadOnlyList<UserResponse>>> GetUsers()
        {
            var users = await userRepository.GetUsers();
            return AppResponse.OkList(users);
        }

        public async Task<ActionResult<UserResponse>> GetUser(Guid id)
        {
            var user = await userManager.FindByIdAsync(id.ToString());
            if (user is null) return AppResponse.NotFound("User not found");
            return AppResponse.Ok(await ToResponse(user));
        }

        public async Task<ActionResult<UserResponse>> AddUser(AddUserRequest request)
        {
            if (request.Password != request.PasswordConfirm)
                return AppResponse.RequestError("Password and confirmation do not match");

            var newUser = new AppUser
            {
                Email = request.Email,
                UserName = request.UserName,
                PhoneNumber = request.PhoneNumber,
            };

            var addUserResult = await userManager.CreateAsync(newUser, request.Password);
            if (!addUserResult.Succeeded)
                return IdentityFail(addUserResult, "Could not create user");

            var roleNames = NormalizeRoleNames(request.Roles);
            foreach (var role in roleNames)
            {
                if (!await userManager.IsInRoleAsync(newUser, role))
                {
                    var addRole = await userManager.AddToRoleAsync(newUser, role);
                    if (!addRole.Succeeded)
                        return IdentityFail(addRole, $"Could not assign role '{role}'");
                }
            }

            return AppResponse.Ok(await ToResponse(newUser), statusCode: StatusCodes.Status201Created);
        }

        public async Task<ActionResult<UserResponse>> UpdateUser(Guid id, UpdateUserRequest request)
        {
            var user = await userManager.FindByIdAsync(id.ToString());
            if (user is null) return AppResponse.NotFound("User not found");

            if (request.Email is not null) user.Email = request.Email;
            if (request.PhoneNumber is not null) user.PhoneNumber = request.PhoneNumber;

            var update = await userManager.UpdateAsync(user);
            if (!update.Succeeded)
                return IdentityFail(update, "Could not update user");

            if (!string.IsNullOrWhiteSpace(request.Password))
            {
                var token = await userManager.GeneratePasswordResetTokenAsync(user);
                var reset = await userManager.ResetPasswordAsync(user, token, request.Password);
                if (!reset.Succeeded)
                    return IdentityFail(reset, "Could not set password");
            }

            if (request.Roles is not null)
            {
                var current = await userManager.GetRolesAsync(user);
                var desired = NormalizeRoleNames(request.Roles);
                var toRemove = current.Where(r => !desired.Contains(r, StringComparer.OrdinalIgnoreCase)).ToList();
                var toAdd = desired.Where(r => !current.Contains(r, StringComparer.OrdinalIgnoreCase)).ToList();

                if (toRemove.Count > 0)
                {
                    var remove = await userManager.RemoveFromRolesAsync(user, toRemove);
                    if (!remove.Succeeded)
                        return IdentityFail(remove, "Could not update roles");
                }
                if (toAdd.Count > 0)
                {
                    var add = await userManager.AddToRolesAsync(user, toAdd);
                    if (!add.Succeeded)
                        return IdentityFail(add, "Could not update roles");
                }
            }

            return AppResponse.Ok(await ToResponse(user));
        }

        public async Task<IActionResult> DeleteUser(Guid id)
        {
            var user = await userManager.FindByIdAsync(id.ToString());
            if (user is null) return AppResponse.NotFound("User not found");

            var result = await userManager.DeleteAsync(user);
            if (!result.Succeeded)
                return IdentityFail(result, "Could not delete user");

            return AppResponse.Ok(statusCode: StatusCodes.Status204NoContent);
        }

        private static List<string> NormalizeRoleNames(IEnumerable<string>? roles)
        {
            var list = (roles ?? [])
                .Select(r => r?.Trim())
                .Where(r => !string.IsNullOrWhiteSpace(r))
                .Select(r => r!)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
            if (list.Count == 0) list.Add(Roles.Member);
            return list;
        }

        private async Task<UserResponse> ToResponse(AppUser user)
        {
            var roles = await userManager.GetRolesAsync(user);
            return new UserResponse
            {
                Id = user.Id,
                UserName = user.UserName ?? "",
                Email = user.Email,
                PhoneNumber = user.PhoneNumber,
                Roles = roles.ToList(),
            };
        }

        private static AppResponse<object?> IdentityFail(IdentityResult result, string detail)
        {
            var extensions = new Dictionary<string, object?>
            {
                ["errors"] = result.Errors.ToDictionary(e => e.Code, e => e.Description),
            };
            return AppResponse.RequestError(new ProblemDetails
            {
                Detail = detail,
                Status = StatusCodes.Status400BadRequest,
                Extensions = extensions!,
            });
        }
    }
}

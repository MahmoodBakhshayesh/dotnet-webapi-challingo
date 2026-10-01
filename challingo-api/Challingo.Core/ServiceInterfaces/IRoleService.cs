using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.RoleDto;

namespace Challingo.Core.ServiceInterfaces;

public interface IRoleService
{
    Task<ActionResult<IReadOnlyList<RoleResponse>>> GetRoles();
    Task<ActionResult<RoleResponse>> GetRole(Guid id);
    Task<ActionResult<RoleResponse>> CreateRole(CreateRoleRequest request);
    Task<ActionResult<RoleResponse>> UpdateRole(Guid id, UpdateRoleRequest request);
    Task<IActionResult> DeleteRole(Guid id);
}

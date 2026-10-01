using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.RoleDto;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Api.Controllers;

[Authorize(Roles = Roles.Admin)]
public class RolesController(IRoleService roleService) : AppController
{
    [HttpGet]
    public Task<ActionResult<IReadOnlyList<RoleResponse>>> GetRoles()
        => roleService.GetRoles();

    [HttpGet("{id:guid}")]
    public Task<ActionResult<RoleResponse>> GetRole(Guid id)
        => roleService.GetRole(id);

    [HttpPost]
    public Task<ActionResult<RoleResponse>> CreateRole(CreateRoleRequest request)
        => roleService.CreateRole(request);

    [HttpPut("{id:guid}")]
    public Task<ActionResult<RoleResponse>> UpdateRole(Guid id, UpdateRoleRequest request)
        => roleService.UpdateRole(id, request);

    [HttpDelete("{id:guid}")]
    public Task<IActionResult> DeleteRole(Guid id)
        => roleService.DeleteRole(id);
}

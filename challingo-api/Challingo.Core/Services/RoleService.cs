using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.DTO.RoleDto;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

public class RoleService(RoleManager<AppRole> roleManager) : IRoleService
{
    private static readonly HashSet<string> SystemRoleNames = new(StringComparer.OrdinalIgnoreCase)
    {
        Roles.Admin,
        Roles.Member,
        Roles.Operator,
        Roles.Supervisor,
    };

    public async Task<ActionResult<IReadOnlyList<RoleResponse>>> GetRoles()
    {
        var roles = roleManager.Roles.OrderBy(r => r.Name).ToList();
        var list = new List<RoleResponse>();
        foreach (var role in roles)
        {
            list.Add(await ToResponse(role));
        }
        return AppResponse.OkList(list);
    }

    public async Task<ActionResult<RoleResponse>> GetRole(Guid id)
    {
        var role = await roleManager.FindByIdAsync(id.ToString());
        if (role is null) return AppResponse.NotFound("Role not found");
        return AppResponse.Ok(await ToResponse(role));
    }

    public async Task<ActionResult<RoleResponse>> CreateRole(CreateRoleRequest request)
    {
        var name = (request.Name ?? "").Trim();
        if (string.IsNullOrWhiteSpace(name))
            return AppResponse.RequestError("Role name is required");

        if (await roleManager.RoleExistsAsync(name))
            return AppResponse.RequestError($"Role '{name}' already exists");

        var role = new AppRole { Name = name };
        var create = await roleManager.CreateAsync(role);
        if (!create.Succeeded)
            return IdentityFail(create, "Could not create role");

        await ReplacePermissions(role, request.Permissions);
        return AppResponse.Ok(await ToResponse(role), statusCode: StatusCodes.Status201Created);
    }

    public async Task<ActionResult<RoleResponse>> UpdateRole(Guid id, UpdateRoleRequest request)
    {
        var role = await roleManager.FindByIdAsync(id.ToString());
        if (role is null) return AppResponse.NotFound("Role not found");

        var isSystem = IsSystemRole(role.Name);
        if (!string.IsNullOrWhiteSpace(request.Name))
        {
            var nextName = request.Name.Trim();
            if (isSystem && !string.Equals(nextName, role.Name, StringComparison.OrdinalIgnoreCase))
                return AppResponse.RequestError("System roles cannot be renamed");

            if (!string.Equals(nextName, role.Name, StringComparison.OrdinalIgnoreCase)
                && await roleManager.RoleExistsAsync(nextName))
                return AppResponse.RequestError($"Role '{nextName}' already exists");

            role.Name = nextName;
            var update = await roleManager.UpdateAsync(role);
            if (!update.Succeeded)
                return IdentityFail(update, "Could not update role");
        }

        // Admin always has full access conceptually — still allow storing grants for clarity.
        await ReplacePermissions(role, request.Permissions);
        return AppResponse.Ok(await ToResponse(role));
    }

    public async Task<IActionResult> DeleteRole(Guid id)
    {
        var role = await roleManager.FindByIdAsync(id.ToString());
        if (role is null) return AppResponse.NotFound("Role not found");
        if (IsSystemRole(role.Name))
            return AppResponse.RequestError("System roles cannot be deleted");

        var result = await roleManager.DeleteAsync(role);
        if (!result.Succeeded)
            return IdentityFail(result, "Could not delete role");

        return AppResponse.Ok(statusCode: StatusCodes.Status204NoContent);
    }

    private static bool IsSystemRole(string? name) =>
        !string.IsNullOrWhiteSpace(name) && SystemRoleNames.Contains(name);

    private async Task<RoleResponse> ToResponse(AppRole role)
    {
        var claims = await roleManager.GetClaimsAsync(role);
        var permissions = PermissionResources.All.Select(resource =>
        {
            var dto = new RolePermissionDto { Resource = resource };
            foreach (var claim in claims.Where(c => c.Type == PermissionClaims.ClaimType))
            {
                if (!PermissionClaims.TryParse(claim.Value, out var res, out var action)) continue;
                if (!string.Equals(res, resource, StringComparison.OrdinalIgnoreCase)) continue;
                switch (action)
                {
                    case PermissionActions.Create: dto.Create = true; break;
                    case PermissionActions.Read: dto.Read = true; break;
                    case PermissionActions.Update: dto.Update = true; break;
                    case PermissionActions.Delete: dto.Delete = true; break;
                }
            }
            return dto;
        }).ToList();

        return new RoleResponse
        {
            Id = role.Id,
            Name = role.Name ?? "",
            IsSystem = IsSystemRole(role.Name),
            Permissions = permissions,
        };
    }

    private async Task ReplacePermissions(AppRole role, List<RolePermissionDto>? permissions)
    {
        var existing = await roleManager.GetClaimsAsync(role);
        foreach (var claim in existing.Where(c => c.Type == PermissionClaims.ClaimType))
        {
            await roleManager.RemoveClaimAsync(role, claim);
        }

        if (permissions is null) return;

        foreach (var grant in permissions)
        {
            if (string.IsNullOrWhiteSpace(grant.Resource)) continue;
            if (!PermissionResources.All.Contains(grant.Resource, StringComparer.OrdinalIgnoreCase))
                continue;

            var resource = PermissionResources.All.First(r =>
                string.Equals(r, grant.Resource, StringComparison.OrdinalIgnoreCase));

            async Task Add(string action, bool enabled)
            {
                if (!enabled) return;
                await roleManager.AddClaimAsync(
                    role,
                    new Claim(PermissionClaims.ClaimType, PermissionClaims.Format(resource, action)));
            }

            await Add(PermissionActions.Create, grant.Create);
            await Add(PermissionActions.Read, grant.Read);
            await Add(PermissionActions.Update, grant.Update);
            await Add(PermissionActions.Delete, grant.Delete);
        }
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

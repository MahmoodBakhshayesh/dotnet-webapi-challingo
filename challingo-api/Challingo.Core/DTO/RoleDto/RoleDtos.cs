namespace Challingo.Core.DTO.RoleDto;

public class RolePermissionDto
{
    public required string Resource { get; set; }
    public bool Create { get; set; }
    public bool Read { get; set; }
    public bool Update { get; set; }
    public bool Delete { get; set; }
}

public class RoleResponse
{
    public Guid Id { get; set; }
    public required string Name { get; set; }
    public bool IsSystem { get; set; }
    public List<RolePermissionDto> Permissions { get; set; } = [];
}

public class CreateRoleRequest
{
    public required string Name { get; set; }
    public List<RolePermissionDto> Permissions { get; set; } = [];
}

public class UpdateRoleRequest
{
    public string? Name { get; set; }
    public List<RolePermissionDto> Permissions { get; set; } = [];
}

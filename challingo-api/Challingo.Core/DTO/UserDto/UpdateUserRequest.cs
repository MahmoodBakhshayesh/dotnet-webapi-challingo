namespace Challingo.Core.DTO.UserDto;

public class UpdateUserRequest
{
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Password { get; set; }
    /// <summary>Role names to assign (replaces existing roles when provided).</summary>
    public List<string>? Roles { get; set; }
}

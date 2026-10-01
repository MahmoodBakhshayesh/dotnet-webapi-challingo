
namespace Challingo.Core.DTO.UserDto
{
    public class UserResponse
    {
        public Guid Id { get; set; }
        public required string UserName { get; set; }
        public string? Email { get; set; }
        public string? PhoneNumber { get; set; }
        public List<string> Roles { get; set; } = [];
    }
}

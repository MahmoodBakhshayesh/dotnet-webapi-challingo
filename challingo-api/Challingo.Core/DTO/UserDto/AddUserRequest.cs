namespace Challingo.Core.DTO.UserDto
{
    public class AddUserRequest
    {
        public required string UserName { get; set; }
        public required string Password { get; set; }
        public required string PasswordConfirm { get; set; }

        public string? Email { get; set; }

        public string? PhoneNumber { get; set; }

        /// <summary>Role names to assign. Defaults to Member when empty.</summary>
        public List<string>? Roles { get; set; }

        public Guid? OrganizationId { get; set; }
    }
}

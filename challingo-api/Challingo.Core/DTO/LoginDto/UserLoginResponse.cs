using Challingo.Core.DTO.Token;
namespace Challingo.Core.DTO.LoginDto
{
    public class UserLoginResponse
    {
        public required string Username {  get; set; }
        public  string? Email {  get; set; }
        public  string? PhoneNumber {  get; set; }
        public required IEnumerable<string> Roles {  get; set; }

        public required TokenResponse Token { get; set; }

    }
}


namespace Challingo.Core.DTO.Token
{
    public sealed record TokenRequest(Guid UserId, string Username, IEnumerable<string> Roles);

}

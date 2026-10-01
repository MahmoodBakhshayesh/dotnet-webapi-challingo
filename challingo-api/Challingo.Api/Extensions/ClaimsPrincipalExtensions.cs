using System.Security.Claims;

namespace Challingo.Api.Extensions;

public static class ClaimsPrincipalExtensions
{
    /// <summary>The signed-in user's id from the JWT <c>sub</c> claim (or NameIdentifier when claims are mapped).</summary>
    public static Guid? GetUserId(this ClaimsPrincipal user)
    {
        var value = user.FindFirst("sub")?.Value ?? user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(value, out var id) ? id : null;
    }
}

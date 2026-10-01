using Microsoft.AspNetCore.Identity;
using Challingo.Core.Domain.IdentityEntities;

public class AppUserRole : IdentityUserRole<Guid>
{
    public virtual AppUser User { get; set; } = default!;
    public virtual AppRole Role { get; set; } = default!;
}
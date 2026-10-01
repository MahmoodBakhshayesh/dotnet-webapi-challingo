using Challingo.Core.Domain.IdentityEntities;

namespace Challingo.Core.Domain.RepositoryInterfaces;

/// <summary>Identity accounts for players: guests and upgrading a guest to an email account.</summary>
public interface IAccountRepository
{
    Task<AppUser?> FindByIdAsync(Guid userId, CancellationToken ct = default);
    Task<AppUser> CreateGuestUserAsync(CancellationToken ct = default);

    /// <summary>Puts a confirmed email on an existing account (email becomes the user name). Null if the user is gone.</summary>
    Task<AppUser?> AttachEmailAsync(Guid userId, string email, CancellationToken ct = default);
}

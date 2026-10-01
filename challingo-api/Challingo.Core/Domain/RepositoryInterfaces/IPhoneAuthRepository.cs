using Challingo.Core.Domain.IdentityEntities;

namespace Challingo.Core.Domain.RepositoryInterfaces;

public interface IPhoneAuthRepository
{
    Task<AppUser?> FindByPhoneAsync(string phoneNumber, CancellationToken ct = default);
    Task<AppUser?> FindByEmailAsync(string email, CancellationToken ct = default);
    Task<AppUser> CreateEmailUserAsync(string email, CancellationToken ct = default);
    Task<AppUser> CreatePhoneUserAsync(string phoneNumber, CancellationToken ct = default);
    Task<bool> HasPasswordAsync(AppUser user, CancellationToken ct = default);
}

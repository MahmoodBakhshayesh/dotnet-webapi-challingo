using Microsoft.AspNetCore.Identity;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Repositories;

public sealed class AccountRepository(UserManager<AppUser> userManager) : IAccountRepository
{
    public Task<AppUser?> FindByIdAsync(Guid userId, CancellationToken ct = default) =>
        userManager.FindByIdAsync(userId.ToString());

    public async Task<AppUser> CreateGuestUserAsync(CancellationToken ct = default)
    {
        var user = new AppUser { UserName = $"guest-{Guid.NewGuid():N}" };
        EnsureSucceeded(await userManager.CreateAsync(user), "create guest");
        EnsureSucceeded(await userManager.AddToRoleAsync(user, Roles.Member), "assign guest role");
        return user;
    }

    public async Task<AppUser?> AttachEmailAsync(Guid userId, string email, CancellationToken ct = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
            return null;

        user.Email = email;
        user.EmailConfirmed = true;
        user.UserName = email;
        EnsureSucceeded(await userManager.UpdateAsync(user), "attach email");
        return user;
    }

    private static void EnsureSucceeded(IdentityResult result, string action)
    {
        if (!result.Succeeded)
            throw new InvalidOperationException(
                $"Could not {action}: {string.Join("; ", result.Errors.Select(e => e.Description))}");
    }
}

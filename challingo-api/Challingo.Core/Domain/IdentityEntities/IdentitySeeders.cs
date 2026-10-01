using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Settings;

public static class IdentitySeeders
{
    /// <summary>
    /// Roles to seed. Overwritten at project create time based on feature flags
    /// (see Set-ApiIdentityRoles in Scaffold-Lib).
    /// Default: Admin + Member only.
    /// </summary>
    private static readonly string[] SeedRoles =
    {
        Roles.Admin,
        Roles.Member,
    };

    public static async Task SeedAsync(RoleManager<AppRole> roleManager)
    {
        foreach (var role in SeedRoles)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new AppRole { Name = role });
            }
        }
    }

    public static async Task SeedAdminUserAsync(
        UserManager<AppUser> userManager,
        RoleManager<AppRole> roleManager,
        IOptions<AuthOptions> authOptions)
    {
        var auth = authOptions.Value;
        var adminEmail = auth.SeedAdminEmail?.Trim();
        var adminPassword = auth.SeedAdminPassword;

        if (string.IsNullOrWhiteSpace(adminEmail) || string.IsNullOrWhiteSpace(adminPassword))
        {
            throw new InvalidOperationException(
                "Auth:SeedAdminEmail and Auth:SeedAdminPassword must be configured to seed the admin user.");
        }

        var at = adminEmail.IndexOf('@');
        var adminUsername = at > 0 ? adminEmail[..at] : "admin";
        if (string.IsNullOrWhiteSpace(adminUsername))
            adminUsername = "admin";

        var adminUser = await userManager.FindByEmailAsync(adminEmail);

        if (adminUser == null)
        {
            adminUser = new AppUser
            {
                UserName = adminUsername,
                Email = adminEmail,
                EmailConfirmed = true
            };

            await userManager.CreateAsync(adminUser, adminPassword);
            await userManager.AddToRoleAsync(adminUser, Roles.Admin);
        }
    }
}

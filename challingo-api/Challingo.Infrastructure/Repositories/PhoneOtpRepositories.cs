using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.Services;
using Challingo.Core.Settings;
using Challingo.Infrastructure.DbContexts;

namespace Challingo.Infrastructure.Repositories;

public sealed class PhoneOtpRepository(AppDbContext db) : IPhoneOtpRepository
{
    public async Task AddAsync(PhoneOtpChallenge challenge, CancellationToken ct = default)
    {
        db.PhoneOtpChallenges.Add(challenge);
        await db.SaveChangesAsync(ct);
    }

    public Task<PhoneOtpChallenge?> GetLatestPendingAsync(string channelKey, CancellationToken ct = default) =>
        db.PhoneOtpChallenges
            .Where(x => x.PhoneNumber == channelKey
                && x.Status == OtpChallengeStatus.Pending
                && x.ExpiresAtUtc > DateTime.UtcNow)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(ct);

    public async Task<PhoneOtpChallenge?> FindValidAsync(string channelKey, string code, CancellationToken ct = default)
    {
        var hash = OtpHash.Hash(code);
        return await db.PhoneOtpChallenges
            .Where(x => x.PhoneNumber == channelKey && x.CodeHash == hash
                && x.Status == OtpChallengeStatus.Pending && x.ExpiresAtUtc > DateTime.UtcNow)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(ct);
    }

    public async Task RecordFailedAttemptAsync(string channelKey, CancellationToken ct = default)
    {
        var challenge = await db.PhoneOtpChallenges
            .Where(x => x.PhoneNumber == channelKey && x.Status == OtpChallengeStatus.Pending)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(ct);
        if (challenge == null) return;
        challenge.AttemptCount++;
        await db.SaveChangesAsync(ct);
    }

    public async Task MarkUsedAsync(PhoneOtpChallenge challenge, CancellationToken ct = default)
    {
        challenge.Status = OtpChallengeStatus.Verified;
        challenge.VerifiedAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync(ct);
    }
}

public sealed class PhoneAuthRepository(AppDbContext db, UserManager<AppUser> userManager) : IPhoneAuthRepository
{
    public Task<AppUser?> FindByPhoneAsync(string phoneNumber, CancellationToken ct = default) =>
        db.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phoneNumber, ct);

    public Task<AppUser?> FindByEmailAsync(string email, CancellationToken ct = default)
    {
        var normalized = email.Trim().ToLowerInvariant();
        return db.Users.FirstOrDefaultAsync(
            u => u.Email != null && u.Email.ToLower() == normalized,
            ct);
    }

    public async Task<AppUser> CreateEmailUserAsync(string email, CancellationToken ct = default)
    {
        var normalized = email.Trim().ToLowerInvariant();
        var user = new AppUser
        {
            UserName = normalized,
            Email = normalized,
            EmailConfirmed = true
        };
        await userManager.CreateAsync(user);
        await userManager.AddToRoleAsync(user, Roles.Member);
        return user;
    }

    public async Task<AppUser> CreatePhoneUserAsync(string phoneNumber, CancellationToken ct = default)
    {
        var user = new AppUser
        {
            UserName = phoneNumber,
            PhoneNumber = phoneNumber,
            PhoneNumberConfirmed = true
        };
        await userManager.CreateAsync(user);
        await userManager.AddToRoleAsync(user, Roles.Member);
        return user;
    }

    public Task<bool> HasPasswordAsync(AppUser user, CancellationToken ct = default) =>
        userManager.HasPasswordAsync(user);
}

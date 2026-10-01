using Microsoft.EntityFrameworkCore;
using Npgsql;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Infrastructure.DbContexts;

namespace Challingo.Infrastructure.Repositories;

public sealed class GroupRepository(AppDbContext db) : IGroupRepository
{
    public async Task<bool> TryAddAsync(Group group, CancellationToken ct = default)
    {
        db.Groups.Add(group);
        try
        {
            await db.SaveChangesAsync(ct);
            return true;
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            db.Entry(group).State = EntityState.Detached;
            foreach (var member in group.Members)
                db.Entry(member).State = EntityState.Detached;
            return false;
        }
    }

    public Task<Group?> GetAsync(Guid groupId, CancellationToken ct = default) =>
        db.Groups.FirstOrDefaultAsync(g => g.Id == groupId, ct);

    public Task<Group?> GetByCodeAsync(string inviteCode, CancellationToken ct = default) =>
        db.Groups.FirstOrDefaultAsync(g => g.InviteCode == inviteCode, ct);

    public async Task<List<(Group Group, int MemberCount)>> ListForUserAsync(Guid userId, CancellationToken ct = default) =>
        (await db.GroupMembers.AsNoTracking()
            .Where(m => m.UserId == userId)
            .OrderByDescending(m => m.JoinedAtUtc)
            .Join(db.Groups, m => m.GroupId, g => g.Id, (m, g) => new { Group = g, Count = g.Members.Count })
            .ToListAsync(ct))
        .Select(x => (x.Group, x.Count)).ToList();

    public Task<List<GroupMember>> GetMembersAsync(Guid groupId, CancellationToken ct = default) =>
        db.GroupMembers.AsNoTracking().Where(m => m.GroupId == groupId).ToListAsync(ct);

    public Task<bool> IsMemberAsync(Guid groupId, Guid userId, CancellationToken ct = default) =>
        db.GroupMembers.AnyAsync(m => m.GroupId == groupId && m.UserId == userId, ct);

    public Task<int> CountMembersAsync(Guid groupId, CancellationToken ct = default) =>
        db.GroupMembers.CountAsync(m => m.GroupId == groupId, ct);

    public async Task<bool> TryAddMemberAsync(GroupMember member, CancellationToken ct = default) =>
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO "GroupMembers" ("GroupId", "UserId", "JoinedAtUtc")
            VALUES ({member.GroupId}, {member.UserId}, {member.JoinedAtUtc})
            ON CONFLICT DO NOTHING
            """, ct) == 1;

    public Task RemoveMemberAsync(Guid groupId, Guid userId, CancellationToken ct = default) =>
        db.GroupMembers.Where(m => m.GroupId == groupId && m.UserId == userId).ExecuteDeleteAsync(ct);

    public Task SaveAsync(Group group, CancellationToken ct = default) => db.SaveChangesAsync(ct);
}

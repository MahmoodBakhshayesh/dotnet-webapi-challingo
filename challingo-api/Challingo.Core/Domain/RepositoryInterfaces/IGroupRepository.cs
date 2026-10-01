using Challingo.Core.Domain.Entities;

namespace Challingo.Core.Domain.RepositoryInterfaces;

public interface IGroupRepository
{
    /// <summary>Adds the group with its owner as first member; false if the invite code is taken.</summary>
    Task<bool> TryAddAsync(Group group, CancellationToken ct = default);

    Task<Group?> GetAsync(Guid groupId, CancellationToken ct = default);
    Task<Group?> GetByCodeAsync(string inviteCode, CancellationToken ct = default);

    /// <summary>The player's groups with member counts, newest membership first.</summary>
    Task<List<(Group Group, int MemberCount)>> ListForUserAsync(Guid userId, CancellationToken ct = default);

    Task<List<GroupMember>> GetMembersAsync(Guid groupId, CancellationToken ct = default);
    Task<bool> IsMemberAsync(Guid groupId, Guid userId, CancellationToken ct = default);
    Task<int> CountMembersAsync(Guid groupId, CancellationToken ct = default);

    /// <summary>False when already a member.</summary>
    Task<bool> TryAddMemberAsync(GroupMember member, CancellationToken ct = default);

    Task RemoveMemberAsync(Guid groupId, Guid userId, CancellationToken ct = default);
    Task SaveAsync(Group group, CancellationToken ct = default);
}

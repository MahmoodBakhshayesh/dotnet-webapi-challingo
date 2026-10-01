using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Competition;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

/// <summary>Groups: an invite link makes a shared board. No duels, no member or group limits.</summary>
public sealed class GroupService(
    IGroupRepository groups,
    ICompetitionRepository competition,
    IOptions<CompetitionOptions> options,
    TimeProvider clock) : IGroupService
{
    // No 0/O, 1/I/L: codes are read aloud and typed.
    private const string CodeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private const int CodeLength = 8;

    public async Task<ActionResult<List<GroupDto>>> ListAsync(Guid userId) =>
        AppResponse.Ok((await groups.ListForUserAsync(userId)).Select(g => ToDto(g.Group, g.MemberCount, userId)).ToList());

    public async Task<ActionResult<GroupDto>> CreateAsync(Guid userId, CreateGroupRequest request)
    {
        var name = request.Name?.Trim() ?? "";
        if (name.Length is < 2 or > 30)
            return AppResponse.RequestError("Group name must be 2 to 30 characters.");

        var now = clock.GetUtcNow().UtcDateTime;
        for (var tries = 0; tries < 5; tries++)
        {
            var group = new Group
            {
                Id = Guid.CreateVersion7(),
                Name = name,
                InviteCode = NewCode(),
                OwnerUserId = userId,
            };
            group.Members.Add(new GroupMember { GroupId = group.Id, UserId = userId, JoinedAtUtc = now });
            if (await groups.TryAddAsync(group))
                return AppResponse.Ok(ToDto(group, 1, userId));
        }
        return AppResponse.RequestError("Could not create the group. Try again.", 409);
    }

    public async Task<ActionResult<GroupInviteDto>> PreviewInviteAsync(Guid userId, string code)
    {
        var group = await groups.GetByCodeAsync(Normalize(code));
        if (group is null)
            return AppResponse.NotFound("Invite not found.");
        return AppResponse.Ok(new GroupInviteDto
        {
            Name = group.Name,
            MemberCount = await groups.CountMembersAsync(group.Id),
            AlreadyMember = await groups.IsMemberAsync(group.Id, userId),
        });
    }

    public async Task<ActionResult<GroupDto>> JoinAsync(Guid userId, JoinGroupRequest request)
    {
        var group = await groups.GetByCodeAsync(Normalize(request.Code));
        if (group is null)
            return AppResponse.NotFound("Invite not found.");
        await groups.TryAddMemberAsync(new GroupMember { GroupId = group.Id, UserId = userId, JoinedAtUtc = clock.GetUtcNow().UtcDateTime });
        return AppResponse.Ok(ToDto(group, await groups.CountMembersAsync(group.Id), userId));
    }

    public async Task<ActionResult<GroupDetailDto>> GetAsync(Guid userId, Guid groupId)
    {
        var group = await groups.GetAsync(groupId);
        if (group is null || !await groups.IsMemberAsync(groupId, userId))
            return AppResponse.NotFound("Group not found.");

        var members = await groups.GetMembersAsync(groupId);
        var players = await competition.GetPlayersAsync(members.Select(m => m.UserId).ToList());
        return AppResponse.Ok(new GroupDetailDto
        {
            Group = ToDto(group, members.Count, userId),
            Members = members
                .Select(m =>
                {
                    players.TryGetValue(m.UserId, out var p);
                    return new GroupMemberDto
                    {
                        DisplayName = p.DisplayName ?? "Player",
                        CountryCode = p.CountryCode,
                        IsOwner = m.UserId == group.OwnerUserId,
                        IsMe = m.UserId == userId,
                        JoinedAtUtc = m.JoinedAtUtc,
                    };
                })
                .OrderBy(m => m.JoinedAtUtc)
                .ToList(),
        });
    }

    public async Task<ActionResult> LeaveAsync(Guid userId, Guid groupId)
    {
        var group = await groups.GetAsync(groupId);
        if (group is null || !await groups.IsMemberAsync(groupId, userId))
            return AppResponse.NotFound("Group not found.");

        await groups.RemoveMemberAsync(groupId, userId);
        var remaining = await groups.GetMembersAsync(groupId);
        if (remaining.Count == 0)
        {
            group.IsDeleted = true;
            await groups.SaveAsync(group);
        }
        else if (group.OwnerUserId == userId)
        {
            // The longest-standing member takes over.
            group.OwnerUserId = remaining.OrderBy(m => m.JoinedAtUtc).First().UserId;
            await groups.SaveAsync(group);
        }
        return AppResponse.Ok();
    }

    private GroupDto ToDto(Group group, int memberCount, Guid userId) => new()
    {
        GroupId = group.Id,
        Name = group.Name,
        InviteCode = group.InviteCode,
        InviteUrl = options.Value.InviteBaseUrl + group.InviteCode,
        MemberCount = memberCount,
        IsOwner = group.OwnerUserId == userId,
    };

    private static string NewCode() =>
        string.Create(CodeLength, 0, (span, _) =>
        {
            for (var i = 0; i < span.Length; i++)
                span[i] = CodeAlphabet[RandomNumberGenerator.GetInt32(CodeAlphabet.Length)];
        });

    /// <summary>Accepts the bare code or a full invite link; case-insensitive.</summary>
    internal static string Normalize(string? code)
    {
        var value = (code ?? "").Trim();
        var slash = value.LastIndexOf('/');
        if (slash >= 0)
            value = value[(slash + 1)..];
        return value.ToUpperInvariant();
    }
}

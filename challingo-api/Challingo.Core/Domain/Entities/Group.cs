namespace Challingo.Core.Domain.Entities;

/// <summary>Friends, family, office…: the same boards, filtered to the members. No limits on groups.</summary>
public class Group : BaseEntity
{
    public string Name { get; set; } = "";

    /// <summary>Short shareable code (also used in invite links).</summary>
    public string InviteCode { get; set; } = "";
    public Guid OwnerUserId { get; set; }
    public List<GroupMember> Members { get; set; } = [];
}

public class GroupMember
{
    public Guid GroupId { get; set; }
    public Guid UserId { get; set; }
    public DateTime JoinedAtUtc { get; set; }
}

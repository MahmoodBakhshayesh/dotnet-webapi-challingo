namespace Challingo.Core.Settings;

public static class Roles
{
    public const string Admin = nameof(Admin);
    public const string Member = nameof(Member);
    /// <summary>Staff lead over operators within an organization (seeded when Supervisors feature is enabled).</summary>
    public const string Supervisor = nameof(Supervisor);
    /// <summary>Day-to-day staff / operator (seeded when Operator panel is enabled).</summary>
    public const string Operator = nameof(Operator);
}

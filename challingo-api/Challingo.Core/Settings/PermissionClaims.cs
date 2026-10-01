namespace Challingo.Core.Settings;

public static class PermissionResources
{
    public const string Users = "Users";
    public const string Organizations = "Organizations";
    public const string Roles = "Roles";

    public static readonly string[] All = [Users, Organizations, Roles];
}

public static class PermissionActions
{
    public const string Create = "Create";
    public const string Read = "Read";
    public const string Update = "Update";
    public const string Delete = "Delete";

    public static readonly string[] All = [Create, Read, Update, Delete];
}

public static class PermissionClaims
{
    public const string ClaimType = "perm";

    public static string Format(string resource, string action) => $"{resource}.{action}";

    public static bool TryParse(string value, out string resource, out string action)
    {
        resource = "";
        action = "";
        var parts = value.Split('.', 2);
        if (parts.Length != 2) return false;
        resource = parts[0];
        action = parts[1];
        return true;
    }
}

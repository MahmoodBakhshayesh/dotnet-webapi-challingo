export const queryKeys = {
  organizations: ["organizations"] as const,
  organization: (id: string) => ["organizations", id] as const,
  profile: ["users", "me"] as const,
  users: ["users"] as const,
  roles: ["roles"] as const,
};

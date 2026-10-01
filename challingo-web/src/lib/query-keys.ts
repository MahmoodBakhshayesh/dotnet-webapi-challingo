export const queryKeys = {
  organizations: ["organizations"] as const,
  organization: (id: string) => ["organizations", id] as const,
  profile: ["users", "me"] as const,
  users: ["users"] as const,
  roles: ["roles"] as const,
  content: (gameKey: string, status?: number) => ["content", gameKey, status ?? "all"] as const,
  contentAll: ["content"] as const,
  games: ["games"] as const,
};

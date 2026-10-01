import { AuthGuard } from "@/features/auth/components/auth-guard";
import { MainShell } from "@/components/layout/main-shell";
import { PostAuthRouteGuard } from "@/components/layout/post-auth-route-guard";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <AuthGuard>
      <PostAuthRouteGuard>
        <MainShell>{children}</MainShell>
      </PostAuthRouteGuard>
    </AuthGuard>
  );
}

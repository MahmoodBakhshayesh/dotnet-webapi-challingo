import { LocaleSwitcher } from "@/components/locale-switcher";

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen flex-col bg-gradient-to-b from-muted/40 to-background">
      <div className="flex shrink-0 justify-end px-4 pt-4 md:px-8 md:pt-6">
        <LocaleSwitcher />
      </div>
      <div className="flex flex-1 flex-col items-center justify-center px-4 pb-10">
        {children}
      </div>
    </div>
  );
}

import type { DesktopConnectionConfig } from "@/features/auth/connectionConfig";
import {
  PasswordSignInPanel,
  type SignInCommand,
} from "@/features/auth/PasswordSignInPanel";
import type { DesktopSessionManager } from "@/features/auth/session";

export interface LoginPageProps {
  command?: SignInCommand | undefined;
  config: DesktopConnectionConfig;
  onAuthenticated: () => void;
  sessionManager: DesktopSessionManager;
}

export function LoginPage({
  command,
  config,
  onAuthenticated,
  sessionManager,
}: LoginPageProps) {
  return (
    <main className="centered-page" id="main-content">
      <div className="auth-panel">
        <p className="eyebrow">Session locale</p>
        <PasswordSignInPanel
          command={command}
          config={config}
          onAuthenticated={onAuthenticated}
          sessionManager={sessionManager}
        />
      </div>
    </main>
  );
}

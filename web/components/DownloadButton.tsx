import { AppleLogo } from "./Marks";

export default function DownloadButton({ compact = false }: { compact?: boolean }) {
  if (compact) {
    return (
      <a
        href="/api/download"
        className="inline-flex items-center gap-2 rounded-full bg-signal-wash px-4 py-1.5 text-sm font-medium text-ink transition hover:brightness-95"
      >
        <AppleLogo className="h-3.5 w-3.5" />
        Get Thrum for macOS
      </a>
    );
  }

  return (
    <div className="flex flex-col items-center gap-3">
      <a
        href="/api/download"
        className="inline-flex items-center gap-2.5 rounded-full bg-signal-wash px-7 py-3.5 text-base font-medium text-ink transition hover:brightness-95"
      >
        <AppleLogo className="h-[18px] w-[18px]" />
        Get Thrum for macOS
      </a>
      <p className="font-mono text-xs text-graphite">
        Requires macOS 14. Apple silicon and Intel.
      </p>

      {/* Don't let people hit Gatekeeper cold. */}
      <details className="mt-1 w-full max-w-md text-center">
        <summary className="cursor-pointer text-xs text-graphite underline underline-offset-4">
          Unsigned build
        </summary>
        <div className="mt-3 rounded-lg border border-rule bg-white/50 p-4 text-left">
          <p className="text-xs text-graphite">
            Thrum isn&apos;t notarised yet, so macOS will refuse to open it on first
            launch. Move it to Applications, then run this once:
          </p>
          <code className="mt-2 block overflow-x-auto rounded bg-tape px-3 py-2 font-mono text-xs text-ink">
            xattr -dr com.apple.quarantine /Applications/Thrum.app
          </code>
        </div>
      </details>
    </div>
  );
}

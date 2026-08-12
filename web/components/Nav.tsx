import DownloadButton from "./DownloadButton";
import { LogoMark } from "./Marks";

export default function Nav() {
  return (
    <header className="sticky top-4 z-20 flex justify-center px-4">
      <nav
        aria-label="Main"
        className="flex items-center gap-2 rounded-full border border-rule bg-tape/85 px-2 py-2 shadow-[0_1px_2px_rgba(22,21,15,0.04)] backdrop-blur"
      >
        <span className="flex items-center gap-2 pl-3 pr-2">
          <LogoMark className="h-[7px] w-auto text-ink" />
          <span className="font-display text-xl leading-none">Thrum</span>
        </span>

        <div className="flex rounded-full bg-white/60 p-0.5" role="group" aria-label="Sections">
          <a
            href="#send"
            className="rounded-full px-3 py-1.5 text-sm text-ink transition hover:bg-white"
          >
            Send
          </a>
          <a
            href="#learn"
            className="rounded-full px-3 py-1.5 text-sm text-graphite transition hover:bg-white hover:text-ink"
          >
            Learn
          </a>
        </div>

        <DownloadButton compact />
      </nav>
    </header>
  );
}

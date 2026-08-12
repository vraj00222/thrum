import Composer from "@/components/Composer";
import DownloadButton from "@/components/DownloadButton";
import FeatureGrid from "@/components/FeatureGrid";
import Hero from "@/components/Hero";
import Nav from "@/components/Nav";

export default function Home() {
  return (
    <>
      <Nav />

      <main id="send">
        <Hero />

        {/* The demo is the hero's real argument, so it sits above the fold. */}
        <div className="px-4 pt-4">
          <Composer />
        </div>

        <div className="flex justify-center px-4 py-20">
          <DownloadButton compact />
        </div>

        <FeatureGrid />
      </main>

      <footer className="border-t border-rule">
        <div className="mx-auto flex max-w-4xl flex-wrap items-center justify-between gap-4 px-4 py-8 text-sm text-graphite">
          <span>Thrum — words you can feel.</span>
          <a
            href="https://github.com/vraj00222/thrum"
            className="underline underline-offset-4 transition hover:text-ink"
          >
            GitHub
          </a>
        </div>
      </footer>
    </>
  );
}

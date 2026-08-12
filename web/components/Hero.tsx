import CurvedText from "./CurvedText";
import DownloadButton from "./DownloadButton";

export default function Hero() {
  return (
    <div className="relative px-4 pt-16 text-center sm:pt-24">
      {/* The ribbon loops behind the type rather than sitting under it in a line. */}
      <CurvedText />

      <div className="relative">
        <p className="font-mono text-xs uppercase tracking-[0.22em] text-graphite">
          Thrum for macOS
        </p>

        <h1 className="mt-6 font-display text-[clamp(3.5rem,11vw,7.5rem)] leading-[0.92] tracking-[-0.02em]">
          Words you can
          <br />
          <em className="italic">feel.</em>
        </h1>

        <p className="mx-auto mt-7 max-w-md text-lg text-graphite">
          Type anything. Your trackpad taps it back in Morse.
        </p>

        <div className="mt-9 flex justify-center">
          <DownloadButton />
        </div>
      </div>
    </div>
  );
}

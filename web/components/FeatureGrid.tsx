const FEATURES = [
  {
    title: "Real Taptic pulses",
    body: "A dah isn't a longer buzz — the trackpad can't do that. It's a train of taps tight enough to read as one, with a different texture from a dit.",
  },
  {
    title: "Farnsworth built in",
    body: "Characters at 15 WPM, gaps stretched to whatever you can actually copy. The standard way to learn, without a second app.",
  },
  {
    title: "Send and receive",
    body: "Key it back with the spacebar and Thrum reads your rhythm, adapting to your speed rather than demanding a metronome.",
  },
];

export default function FeatureGrid() {
  return (
    <section id="learn" className="mx-auto max-w-4xl px-4 py-24">
      <div className="grid gap-12 sm:grid-cols-3">
        {FEATURES.map((feature) => (
          <div key={feature.title}>
            <h2 className="font-display text-2xl leading-tight">{feature.title}</h2>
            <p className="mt-3 text-sm leading-relaxed text-graphite">{feature.body}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

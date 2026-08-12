const LINE = "words you can feel  ·  ·—·  ·  thrum for macos  ·  ·—·  ·  ";

/**
 * The ribbon: a line of type set on a loop, sitting behind the hero. Decorative
 * only — it's aria-hidden and the same words appear as real text below it.
 */
export default function CurvedText() {
  return (
    <svg
      viewBox="0 0 900 930"
      className="pointer-events-none absolute -left-40 -top-8 hidden h-[760px] w-[740px] select-none lg:block"
      aria-hidden="true"
    >
      <path
        id="thrum-loop"
        d="M 450 90 C 195 75, 60 255, 195 375 C 322 487, 525 427, 480 277 C 438 138, 180 165, 93 375 C 9 577, 105 810, 352 877"
        fill="none"
      />
      <text className="fill-graphite/30 font-mono" fontSize="15" letterSpacing="2">
        <textPath href="#thrum-loop" startOffset="0%">
          {LINE + LINE}
        </textPath>
      </text>
    </svg>
  );
}

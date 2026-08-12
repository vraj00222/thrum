// Port of mac/Sources/ThrumCore/MorseCode.swift. Keep the two in sync — both read
// fixtures/morse-cases.json, so a divergence fails a test on one side or the other.

export type MorseToken = "dit" | "dah" | "intraGap" | "charGap" | "wordGap";

export const UNITS: Record<MorseToken, number> = {
  dit: 1,
  dah: 3,
  intraGap: 1,
  charGap: 3,
  wordGap: 7,
};

export const isPulse = (t: MorseToken) => t === "dit" || t === "dah";

export const TABLE: Record<string, string> = {
  A: ".-", B: "-...", C: "-.-.", D: "-..", E: ".", F: "..-.",
  G: "--.", H: "....", I: "..", J: ".---", K: "-.-", L: ".-..",
  M: "--", N: "-.", O: "---", P: ".--.", Q: "--.-", R: ".-.",
  S: "...", T: "-", U: "..-", V: "...-", W: ".--", X: "-..-",
  Y: "-.--", Z: "--..",
  "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
  "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.",
  ".": ".-.-.-", ",": "--..--", "?": "..--..", "'": ".----.", "!": "-.-.--",
  "/": "-..-.", "(": "-.--.", ")": "-.--.-", "&": ".-...", ":": "---...",
  ";": "-.-.-.", "=": "-...-", "+": ".-.-.", "-": "-....-", _: "..--.-",
  '"': ".-..-.", $: "...-..-", "@": ".--.-.",
};

const REVERSE: Record<string, string> = Object.fromEntries(
  Object.entries(TABLE).map(([char, code]) => [code, char]),
);

/** A run of symbols sent as one character — a letter, or a bracketed prosign. */
function units(word: string): string[] {
  const chars = [...word.toUpperCase()];
  const out: string[] = [];
  let i = 0;
  while (i < chars.length) {
    if (chars[i] === "<") {
      const close = chars.indexOf(">", i);
      if (close !== -1) {
        const code = chars
          .slice(i + 1, close)
          .map((c) => TABLE[c] ?? "")
          .join("");
        if (code) out.push(code);
        i = close + 1;
        continue;
      }
    }
    const code = TABLE[chars[i]];
    if (code) out.push(code);
    i += 1;
  }
  return out;
}

const words = (text: string) => text.split(/\s+/).filter(Boolean);

export function tokenize(text: string): MorseToken[] {
  const tokens: MorseToken[] = [];
  for (const word of words(text)) {
    const charUnits = units(word);
    if (charUnits.length === 0) continue;
    if (tokens.length > 0) tokens.push("wordGap");
    charUnits.forEach((code, u) => {
      if (u > 0) tokens.push("charGap");
      [...code].forEach((symbol, s) => {
        if (s > 0) tokens.push("intraGap");
        tokens.push(symbol === "." ? "dit" : "dah");
      });
    });
  }
  return tokens;
}

export function encodeToString(text: string): string {
  return words(text)
    .map((word) => units(word).join(" "))
    .filter(Boolean)
    .join(" / ");
}

export function decode(morse: string): string {
  return morse
    .split(/\s+/)
    .filter(Boolean)
    .map((token) => (token === "/" ? " " : (REVERSE[token] ?? "�")))
    .join("")
    .trim();
}

/** Characters we'd silently drop. Drives the inline warning under the input. */
export function unsupported(text: string): string[] {
  const out = new Set<string>();
  for (const char of text.toUpperCase()) {
    if (/\s/.test(char) || char === "<" || char === ">") continue;
    if (!TABLE[char]) out.add(char);
  }
  return [...out].sort();
}

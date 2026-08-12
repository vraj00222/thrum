// Reads the same fixtures as the Swift suite. Run: pnpm test
// Node 25 strips types natively, so this needs no test framework and no build step.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { decode, encodeToString, tokenize, unsupported, type MorseToken } from "./morse.ts";
import { duration, totalDuration, unit } from "./timing.ts";

const root = fileURLToPath(new URL("../../", import.meta.url));
const fixtures = JSON.parse(readFileSync(root + "fixtures/morse-cases.json", "utf8"));

const close = (a: number, b: number, tol = 0.001) =>
  assert.ok(Math.abs(a - b) < tol, `${a} != ${b}`);

test("encodes to match the fixtures", () => {
  for (const c of [...fixtures.roundTrip, ...fixtures.lowercaseInput, ...fixtures.prosigns]) {
    assert.equal(encodeToString(c.text), c.morse, `encoding ${c.text}`);
  }
});

test("round-trips through decode", () => {
  for (const c of [...fixtures.roundTrip, ...fixtures.lowercaseInput]) {
    assert.equal(decode(encodeToString(c.text)), c.text.toUpperCase());
  }
});

test("produces the expected token stream", () => {
  for (const c of fixtures.tokenCounts) {
    assert.deepEqual(tokenize(c.text), c.tokens as MorseToken[], `tokenizing ${c.text}`);
  }
});

test("prosigns carry no internal character gap", () => {
  for (const p of ["<SOS>", "<AR>", "<BT>", "<KN>"]) {
    const tokens = tokenize(p);
    assert.ok(!tokens.includes("charGap"), `${p} contains a character gap`);
    assert.ok(!tokens.includes("wordGap"), `${p} contains a word gap`);
  }
  // Same token count as the spelled-out form; the saving is two charGaps -> intraGaps.
  const t = { wpm: 5 };
  close(totalDuration(tokenize("SOS"), t) - totalDuration(tokenize("<SOS>"), t), 4 * unit(t));
});

test("flags unsupported characters", () => {
  for (const c of fixtures.unsupported) {
    assert.deepEqual(unsupported(c.text), c.chars, c.text);
  }
});

test("standard timing matches the fixtures", () => {
  for (const c of fixtures.timing) {
    const t = { wpm: c.wpm };
    close(unit(t) * 1000, c.unitMS);
    close(duration("dit", t) * 1000, c.ditMS);
    close(duration("dah", t) * 1000, c.dahMS);
    close(duration("charGap", t) * 1000, c.charGapMS);
    close(duration("wordGap", t) * 1000, c.wordGapMS);
  }
});

test("Farnsworth stretches only the gaps", () => {
  for (const c of fixtures.farnsworth) {
    const t = { wpm: c.wpm, farnsworthWPM: c.farnsworthWPM };
    const plain = { wpm: c.wpm };
    close(duration("dit", t) * 1000, c.ditMS);
    close(duration("dah", t) * 1000, c.dahMS);
    close(duration("charGap", t) * 1000, c.charGapMS);
    close(duration("wordGap", t) * 1000, c.wordGapMS);
    assert.equal(duration("dit", t), duration("dit", plain));
    assert.ok(duration("charGap", t) > duration("charGap", plain));
    // PARIS lands at the effective speed.
    close(totalDuration([...tokenize("PARIS"), "wordGap"], t), 60 / c.farnsworthWPM);
  }
});

import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import {
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

type Mode = "file" | "stdin" | "inline";

interface Case {
  name: string;
  data: Buffer | null;
  path: string | null;
  queries: string[];
  rich: boolean;
  modes: Mode[];
}

interface Run {
  query: string;
  flags: string[];
  mode: Mode;
}

interface Result {
  code: number | null;
  signal: string | null;
  timedOut: boolean;
  stdoutLen: number;
  stdoutSha: string;
  stdoutHead: Buffer;
  stderrLen: number;
  stderrSha: string;
  stderrHead: Buffer;
}

interface Mismatch {
  caseName: string;
  run: Run;
  input: Buffer | null;
  path: string | null;
  oldResult: Result;
  newResult: Result;
}

interface Rng {
  int(n: number): number;
  chance(p: number): boolean;
  pick<T>(items: readonly T[]): T;
}

const HEAD_BYTES = 600;
const RUN_TIMEOUT_MS = 60_000;
const INLINE_LIMIT = 4096;
const KNOWN_DIFF_LIMIT = 100_000;
const MAX_PRINTED = 20;
const ALL_MODES: Mode[] = ["file", "stdin", "inline"];
const FILE_STDIN: Mode[] = ["file", "stdin"];

function makeRng(seed: number): Rng {
  let s = seed >>> 0;
  const next = (): number => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    int: (n) => Math.floor(next() * n),
    chance: (p) => next() < p,
    pick: (items) => items[Math.floor(next() * items.length)] as never,
  };
}

const bin = (s: string): Buffer => Buffer.from(s, "latin1");
const utf8 = (s: string): string => Buffer.from(s, "utf8").toString("latin1");

const ESCAPES = ['\\"', "\\\\", "\\/", "\\b", "\\f", "\\n", "\\r", "\\t"];
const UTF8_TEXT = ["é", "日本語", "🎉", "€", "\u00a0", "ß", "𝄞", "\u2028"];
const BAD_BYTES = [
  "\x80",
  "\xbf",
  "\xc0\x80",
  "\xc1",
  "\xe0\x80\x80",
  "\xed\xa0\x80",
  "\xed\xbf\xbf",
  "\xf4\x90\x80\x80",
  "\xf8\x88\x80\x80\x80",
  "\xff",
  "\xfe",
  "\xe2\x82",
  "\xf0\x9f\x98",
  "\xc3",
];
const LITERALS = ["null", "true", "false", "NaN", "Infinity", "-Infinity"];
const VALID_NUMS = [
  "0",
  "-0",
  "1",
  "-1",
  "42",
  "4611686018427387903",
  "4611686018427387904",
  "-4611686018427387904",
  "-4611686018427387905",
  "9223372036854775807",
  "9223372036854775808",
  "-9223372036854775808",
  "-9223372036854775809",
  "18446744073709551615",
  "18446744073709551616",
  "340282366920938463463374607431768211456",
  "1" + "0".repeat(400),
  "-" + "9".repeat(100),
  "0.0",
  "-0.0",
  "0.5",
  "-0.5",
  "1.5",
  "3.14159265358979323846",
  "1e5",
  "1E5",
  "1e+5",
  "1E+5",
  "1e-5",
  "1E-5",
  "-0.0e-0",
  "1.5e+10",
  "1.0E5",
  "0e0",
  "0.0e0",
  "123456789.123456789e-123",
  "1e400",
  "1e-400",
  "NaN",
  "Infinity",
  "-Infinity",
];
const BIG_BASES = [
  2n ** 62n,
  2n ** 63n,
  2n ** 64n,
  10n ** 30n,
  10n ** 18n,
  10n ** 19n,
];
const INTERESTING = [
  '"',
  "\\",
  "/",
  "*",
  "{",
  "}",
  "[",
  "]",
  ",",
  ":",
  "\n",
  "\r",
  "\t",
  " ",
  "-",
  "+",
  ".",
  "e",
  "E",
  "u",
  "U",
  "0",
  "a",
  "N",
  "I",
  "\x80",
  "\xff",
  "#",
  "'",
];

function digits(rng: Rng, n: number): string {
  let s = "";
  for (let i = 0; i < n; i++) s += String(rng.int(10));
  return s;
}

function intPart(rng: Rng): string {
  return rng.chance(0.15) ? "0" : String(1 + rng.int(9)) + digits(rng, rng.int(25));
}

function numTok(rng: Rng): string {
  const r = rng.int(10);
  if (r < 3) return rng.pick(VALID_NUMS);
  const sign = rng.chance(0.4) ? "-" : "";
  if (r < 5) return sign + (rng.pick(BIG_BASES) + BigInt(rng.int(7) - 3)).toString();
  const frac = (): string => "." + digits(rng, 1 + rng.int(20));
  const exp = (): string =>
    rng.pick(["e", "E"]) + rng.pick(["", "+", "-"]) + digits(rng, 1 + rng.int(4));
  const ip = intPart(rng);
  if (r < 7) return sign + ip;
  if (r < 8) return sign + ip + frac();
  if (r < 9) return sign + ip + exp();
  return sign + ip + frac() + exp();
}

function asciiRun(rng: Rng, n: number): string {
  let s = "";
  while (s.length < n) {
    const c = 0x20 + rng.int(0x5f);
    if (c !== 0x22 && c !== 0x5c) s += String.fromCharCode(c);
  }
  return s;
}

function hex4(rng: Rng, v: number): string {
  const s = v.toString(16).padStart(4, "0");
  return rng.chance(0.5) ? s.toUpperCase() : s;
}

function strPiece(rng: Rng): string {
  switch (rng.int(9)) {
    case 0:
    case 1:
    case 2:
      return asciiRun(rng, 1 + rng.int(12));
    case 3:
      return rng.pick(ESCAPES);
    case 4: {
      const r = rng.int(10);
      const v =
        r < 2 ? rng.int(32) : r < 3 ? 0xdc00 + rng.int(0x400) : r < 6 ? rng.int(0xd800) : 0xe000 + rng.int(0x2000);
      return "\\u" + hex4(rng, v);
    }
    case 5:
      return "\\u" + hex4(rng, 0xd800 + rng.int(0x400)) + "\\u" + hex4(rng, 0xdc00 + rng.int(0x400));
    case 6:
      return utf8(rng.pick(UTF8_TEXT));
    case 7:
      return String.fromCharCode(1 + rng.int(31));
    default:
      return rng.pick(BAD_BYTES);
  }
}

function strBody(rng: Rng, maxPieces: number): string {
  let s = "";
  for (let n = rng.int(maxPieces + 1); n > 0; n--) s += strPiece(rng);
  return s;
}

function identKey(rng: Rng): string {
  const first = "abcxyzABCXYZ_";
  const rest = first + "0123456789";
  let s = first[rng.int(first.length)] as string;
  for (let n = rng.int(8); n > 0; n--) s += rest[rng.int(rest.length)] as string;
  return s;
}

function ws(rng: Rng, density: number): string {
  if (!rng.chance(density)) return "";
  const parts = [
    " ",
    "  ",
    "\t",
    "\n",
    "\r\n",
    "\r",
    " \n\t ",
    "//c\n",
    "// x */ \"[{\r\n",
    "/*a*/",
    "/*a\nb*/",
    "/**/",
    "/***/",
    "/* \r\n * \n */",
  ];
  let s = "";
  for (let n = 1 + rng.int(3); n > 0; n--) s += rng.pick(parts);
  return s;
}

interface Budget {
  n: number;
}

function genScalar(rng: Rng): string {
  const r = rng.int(10);
  if (r < 2) return rng.pick(LITERALS);
  if (r < 6) return numTok(rng);
  return '"' + strBody(rng, 6) + '"';
}

function genKey(rng: Rng): string {
  return rng.chance(0.3) ? identKey(rng) : '"' + strBody(rng, 3) + '"';
}

function genValue(rng: Rng, depth: number, wsd: number, budget: Budget): string {
  budget.n--;
  if (depth <= 0 || budget.n <= 0 || rng.chance(0.3)) return genScalar(rng);
  const breadth = rng.chance(0.03) ? 50 + rng.int(400) : rng.int(5);
  const items: string[] = [];
  const isArray = rng.chance(0.5);
  for (let i = 0; i < breadth; i++) {
    const v = genValue(rng, depth - 1, wsd, budget);
    items.push(
      isArray
        ? ws(rng, wsd) + v + ws(rng, wsd)
        : ws(rng, wsd) + genKey(rng) + ws(rng, wsd) + ":" + ws(rng, wsd) + v + ws(rng, wsd),
    );
  }
  const body = items.join(",");
  if (breadth === 0) return (isArray ? "[" : "{") + ws(rng, wsd) + (isArray ? "]" : "}");
  return isArray ? "[" + body + "]" : "{" + body + "}";
}

function genDoc(rng: Rng, depth: number, wsd: number, size: number): string {
  const doc = ws(rng, wsd) + genValue(rng, depth, wsd, { n: size }) + ws(rng, wsd);
  return rng.chance(0.1) ? doc + "//tail" : doc;
}

const SAMPLE_1 =
  '{"a": [1, -2.5e3, true, null, "x\\ny\\u00e9\\ud83d\\ude00"], b: {c_1: NaN, "d": -Infinity}, /* c1 */ "e": Infinity} // end';
const SAMPLE_2 =
  '[0,-0,1E+5,-0.0e-0,9223372036854775808,"\\"\\\\\\/\\b\\f\\n\\r\\t",\r\n\t// line comment\r\n{"k":"\\uD83D\\uDE00"},/* multi\nline */false]';
const SAMPLE_3 =
  '\n\n  {\n    "list": [ [], {}, [ [ 1 ] ] ],\n    key_2 : "v\\u0041\\u00E9",\n    "n": 18446744073709551616,\n    "f": 1.5e+10\n  }\n';

const MALFORMED: string[] = [
  "",
  " ",
  "\n",
  "\r\n\t ",
  "// only comment",
  "// only comment\n",
  "/* only */",
  "/* unterminated",
  "/* unterminated *",
  "/*/",
  "/",
  "/x",
  "//",
  "1 /* unterminated",
  "[1] /* unterminated",
  "01",
  "-01",
  "00",
  "1.",
  "1e",
  "1e+",
  "1.e5",
  ".5",
  "-",
  "--1",
  "+1",
  "-Inf",
  "-Infinit",
  "Infinit",
  "-NaN",
  "nan",
  "infinity",
  "NaNx",
  "tru",
  "fal",
  "nul",
  "True",
  "truee",
  "nulll",
  "1-",
  "1.5.5",
  "1e5e5",
  "0x10",
  "1_000",
  "[1,]",
  "[,]",
  "[,1]",
  "[1,,2]",
  "[1 2]",
  "[1",
  "[1,",
  "[",
  "]",
  "[]]",
  "{",
  "}",
  '{"a":1,}',
  '{"a":1',
  '{"a":1,',
  '{"a":',
  '{"a"',
  '{"a"}',
  '{"a" 1}',
  '{"a":}',
  '{"a":1 "b":2}',
  "{a 1}",
  "{a:}",
  "{1:2}",
  "{:1}",
  "{,}",
  "{'a':1}",
  "{a-b:1}",
  "{9a:1}",
  '{"a":1}}',
  '{"a":1}x',
  "1 2",
  "null null",
  "true false",
  "{} {}",
  "[] []",
  "1,",
  "x",
  "@",
  "#",
  "'a'",
  "\0",
  "[\0]",
  "\ufeff[1]",
  "\xef\xbb\xbf[1]",
  "\f1",
  "\v1",
  "\xc2\xa01",
  "\xff",
  '"',
  '"abc',
  '"abc\\',
  '"abc\\"',
  '"\\x"',
  '"\\a"',
  '"\\U0041"',
  '"\\u"',
  '"\\u1"',
  '"\\u12"',
  '"\\u123"',
  '"\\u123g"',
  '"\\uZZZZ"',
  '"\\u12"x',
  '"\\uD800"',
  '"\\uD800',
  '"\\uD800\\',
  '"\\uD800\\u',
  '"\\uD800\\u00',
  '"\\uD800x"',
  '"\\uD800\\n"',
  '"\\uD800\\u0041"',
  '"\\uD800\\uD800"',
  '"\\uD800\\uE000"',
  '"\\uDBFF\\uDBFF"',
  '"\\uD800\\uDBFF"',
  '"\\uDC00"',
  '"\\uDC00\\uDC00"',
  '{"\\uD800":1}',
  '["\\uD800\\u12"]',
  '[1, "\\uD800\\u0041"]',
  '{"a":"\\q"}',
  '{"a\\q":1}',
  '["a\nb"',
  '["\r\n',
  '"\\',
  "\n\n\n[1,\n2,\n]",
  "\r\n\r\n{\r\n\"a\": tru\r\n}",
  "[\n1,\n// c\n/* a\nb */ ?\n]",
  "/* a\nb\nc */ [1,\n2 3]",
  "// c\n// d\n@",
  "[1] // trailing\n x",
  "[1] /* c */ x",
  '"é\xff',
  "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, @ 21]",
  "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,",
  "{\"abcdefghijklmnopqrstuvwxyz\": 1234567890, \"b\": tru",
  "[" + "[".repeat(50),
  "[" + "{\"a\":".repeat(50) + "]",
  "[" + "1,".repeat(40) + "]]",
];

interface Tail {
  open: "[" | "{" | "";
  body: string;
}

const TAILS: Tail[] = [
  { open: "[", body: "01]" },
  { open: "[", body: "1.]" },
  { open: "[", body: "1e]" },
  { open: "[", body: "-]" },
  { open: "[", body: "-Inf]" },
  { open: "[", body: "tru]" },
  { open: "[", body: "nulx]" },
  { open: "[", body: "]]" },
  { open: "[", body: ",]" },
  { open: "[", body: "1,]" },
  { open: "[", body: "1 2]" },
  { open: "[", body: "1}" },
  { open: "[", body: '"\\x"]' },
  { open: "[", body: '"\\u12"]' },
  { open: "[", body: '"\\uD800x"]' },
  { open: "[", body: '"\\uD800\\u0041"]' },
  { open: "[", body: '"\\uD800"]' },
  { open: "[", body: '"\\uD800' },
  { open: "[", body: '"abc' },
  { open: "[", body: "/* unterminated" },
  { open: "[", body: "nope, nope, nope, nope, nope, nope, nope]" },
  { open: "[", body: "@" },
  { open: "[", body: "" },
  { open: "[", body: "1" },
  { open: "[", body: "1," },
  { open: "{", body: '"a" 1}' },
  { open: "{", body: "a 1}" },
  { open: "{", body: '"a"}' },
  { open: "{", body: '"a":}' },
  { open: "{", body: '"a":1,}' },
  { open: "{", body: '"a":1 "b":2}' },
  { open: "{", body: "1:2}" },
  { open: "{", body: '"a":1]' },
  { open: "{", body: '"a":"\\q"}' },
  { open: "{", body: '"a"' },
  { open: "{", body: "" },
  { open: "", body: "1 x" },
  { open: "", body: "null null" },
  { open: "", body: "{} {}" },
  { open: "", body: "[]]" },
  { open: "", body: "01" },
  { open: "", body: "tru" },
  { open: "", body: "[1,]" },
  { open: "", body: "" },
  { open: "", body: "/* unterminated" },
  { open: "", body: '"\\uD800\\uZZZZ"' },
];

const BOUNDARIES = [512, 1024, 4096, 65536];

function padPrefix(rng: Rng, open: Tail["open"], kind: number, target: number): string {
  let s = open;
  const unit =
    kind === 1
      ? () => rng.pick([" ", "\n", "\r\n", "\t", "  \n", "// c\n", "/* a\nb */"])
      : kind === 2 && open === "["
        ? () => rng.pick(["1,", "22,", '"a",', "[],", "{},", "null,", "1.5e3,"])
        : kind === 2 && open === "{"
          ? () => rng.pick(['"k":1,', "a:2,", '"k":"v",', '"k":[],'])
          : kind === 3
            ? () => "/*" + asciiRun(rng, 40).replaceAll("*/", "..") + "*/"
            : () => rng.pick([" ", "\t"]);
  for (;;) {
    const u = unit();
    if (s.length + u.length > target - 1) break;
    s += u;
  }
  while (s.length < target) s += " ";
  return s;
}

function interleaved(prefix: string, extraLines: number): string {
  return "\n".repeat(extraLines) + prefix;
}

function buildCases(rng: Rng, benchDir: string, fixturesPath: string, skipHuge: boolean): Case[] {
  const cases: Case[] = [];
  const add = (name: string, data: Buffer | string, opts: Partial<Case> = {}): void => {
    cases.push({
      name,
      data: typeof data === "string" ? bin(data) : data,
      path: null,
      queries: ["."],
      rich: false,
      modes: ALL_MODES,
      ...opts,
    });
  };

  VALID_NUMS.forEach((n, i) => {
    add(`num-top-${i}`, n, { rich: true });
    add(`num-arr-${i}`, `[1, ${n} ,${n}]`, { rich: true });
    add(`num-obj-${i}`, `{"a":${n},b:${n}}`);
  });
  const badNums = ["01", "-01", "1.", "1e", "1e+", ".5", "-", "-Inf", "tru", "NaNx", "1.e5", "0x1", "1__0"];
  badNums.forEach((n, i) => {
    for (const [ctx, doc] of [["top", n], ["arr", `[${n}]`], ["arr2", `[1,${n},2]`], ["obj", `{"a":${n}}`], ["tail", `${n}]`]] as const) {
      add(`badnum-${ctx}-${i}`, doc, { rich: ctx === "top" });
    }
  });

  ESCAPES.forEach((e, i) => add(`escape-${i}`, `"a${e}b"`, { rich: true }));
  for (let v = 0; v < 0x10000; v += 0x111) {
    add(`uescape-${v.toString(16)}`, `["\\u${hex4(rng, v)}"]`);
  }
  for (const c of ["\\u00e9", "\\u00E9", "\\u0000", "\\uD83D\\uDE00", "\\ud83d\\ude00", "\\uDBFF\\uDFFF", "\\uD800\\uDC00", "\\uDC00", "\\uDFFF", "\\uE000", "\\uFFFF", "\\uFEFF"]) {
    add(`uescape-lit-${c}`, `"x${c}y"`, { rich: true });
    add(`uescape-key-${c}`, `{"${c}":1}`);
  }
  for (let b = 0; b < 256; b++) add(`rawbyte-${b}`, `["a${String.fromCharCode(b)}b"]`, { modes: FILE_STDIN });
  for (let b = 0; b < 256; b++) add(`rawbyte-top-${b}`, `${String.fromCharCode(b)}`, { modes: FILE_STDIN });

  add("crlf-doc", '{\r\n  "a": 1,\r\n  "b": [1,\r\n2]\r\n}\r\n', { rich: true });
  add("tabs-doc", '\t{\t"a"\t:\t1\t}\t', { rich: true });
  add("comment-eof", "[1,2]//tail", { rich: true });
  add("comment-eof-nl", "[1,2]//tail\n", { rich: true });
  add("comment-block-nl", "[1,/*a\nb\nc*/2]", { rich: true });
  add("comment-leading", "// head\n/* h2 */ [1]", { rich: true });
  add("comment-in-obj", '{ /*a*/ "a" /*b*/ : /*c*/ 1 /*d*/ , // e\n "b": 2 // f\n }', { rich: true });
  add("comment-at-value", "[1, // x\n 2, /* y */ 3]", { rich: true });
  add("comment-only-eof", "//x", { rich: true });
  add("ident-keys", "{foo:1,_bar:2,Baz9:3,true:4,null:5,NaN:6,Infinity:7}", { rich: true });
  add("ident-key-ws", "{ foo : 1 , bar : [ a ] }");
  add("dup-keys", '{"a":1,"a":2,a:3}', { rich: true });
  add("empty-key", '{"":1}', { rich: true });
  add("empty-containers", '[[],{},[[]],{"a":{}},[{}]]', { rich: true });
  add("nul-in-string", Buffer.from([0x5b, 0x22, 0x61, 0x00, 0x62, 0x22, 0x5d]), { modes: FILE_STDIN });
  add("nul-after", Buffer.from([0x31, 0x00]), { modes: FILE_STDIN });
  add("nul-before", Buffer.from([0x00, 0x31]), { modes: FILE_STDIN });

  MALFORMED.forEach((m, i) => add(`malformed-${i}`, m, { rich: true }));

  for (let i = 0; i < 160; i++) {
    const depth = 1 + rng.int(7);
    const wsd = rng.pick([0, 0, 0.1, 0.4, 0.9]);
    add(`valid-${i}`, genDoc(rng, depth, wsd, 40 + rng.int(600)), { rich: i % 3 === 0 });
  }
  for (let i = 0; i < 60; i++) {
    const wsd = rng.pick([0, 0.3]);
    add(`valid-medium-${i}`, genDoc(rng, 8, wsd, 4000 + rng.int(20000)), { modes: FILE_STDIN });
  }

  for (const d of [10, 100, 1000, 3000, 10_000, 100_000]) {
    const queries = d > 10_000 ? ["length"] : ["."];
    add(`deep-array-${d}`, "[".repeat(d) + "1" + "]".repeat(d), { modes: FILE_STDIN, queries });
    add(`deep-object-${d}`, '{"a":'.repeat(d) + "1" + "}".repeat(d), { modes: FILE_STDIN, queries });
    add(`deep-mixed-${d}`, '[{"a":'.repeat(d) + "1" + "}]".repeat(d), { modes: FILE_STDIN, queries });
    add(`deep-array-trunc-${d}`, "[".repeat(d), { modes: FILE_STDIN });
    add(`deep-array-bad-${d}`, "[".repeat(d) + "01" + "]".repeat(d), { modes: FILE_STDIN });
  }
  add("wide-array-100k", "[" + Array.from({ length: 100_000 }, (_, i) => String(i)).join(",") + "]", { modes: FILE_STDIN });
  add("wide-object-20k-quoted", "{" + Array.from({ length: 20_000 }, (_, i) => `"key${i}":${i}`).join(",") + "}", { modes: FILE_STDIN });
  add("wide-object-20k-ident", "{" + Array.from({ length: 20_000 }, (_, i) => `key${i}:${i}`).join(",") + "}", { modes: FILE_STDIN });
  add("wide-array-empty-elems", "[" + "[],".repeat(50_000) + "[]]", { modes: FILE_STDIN });

  [
    ["S1", SAMPLE_1],
    ["S2", SAMPLE_2],
    ["S3", SAMPLE_3],
  ].forEach(([label, sample]) => {
    const s = sample as string;
    for (let n = 0; n <= s.length; n++) add(`trunc-${label}-${n}`, s.slice(0, n));
  });

  const mutationSamples = [SAMPLE_1, SAMPLE_2, SAMPLE_3];
  for (let i = 0; i < 5; i++) mutationSamples.push(genDoc(rng, 3, 0.3, 30));
  mutationSamples.forEach((sample, si) => {
    for (let i = 0; i < 60; i++) {
      let m = sample;
      for (let k = rng.chance(0.2) ? 2 : 1; k > 0; k--) {
        const at = rng.int(m.length + 1);
        switch (rng.int(5)) {
          case 0:
            m = m.slice(0, at) + rng.pick(INTERESTING) + m.slice(at + 1);
            break;
          case 1:
            m = m.slice(0, at) + m.slice(at + 1);
            break;
          case 2:
            m = m.slice(0, at) + rng.pick(INTERESTING) + m.slice(at);
            break;
          case 3:
            m = m.slice(0, at) + String.fromCharCode(1 + rng.int(255)) + m.slice(at + 1);
            break;
          default:
            m = m.slice(0, at) + (m[at + 1] ?? "") + (m[at] ?? "") + m.slice(at + 2);
        }
      }
      add(`mutate-${si}-${i}`, m);
    }
  });

  TAILS.forEach((tail, ti) => {
    for (const boundary of BOUNDARIES) {
      for (let k = 0; k < 2; k++) {
        const pos = boundary - rng.int(40);
        const kind = (ti + k) % 4;
        const lines = k === 1 ? 1 + rng.int(3) : 0;
        const prefix = interleaved(padPrefix(rng, tail.open, kind, pos), lines);
        add(`pad-${ti}-${boundary}-${k}`, prefix + tail.body, { modes: prefix.length < INLINE_LIMIT ? ALL_MODES : FILE_STDIN });
      }
    }
  });

  const mb = (n: number): number => n * 1024 * 1024;
  const bigValid = (): string => {
    const parts: string[] = [];
    let size = 0;
    while (size < mb(3)) {
      const d = genDoc(rng, 3, 0.1, 30).trim().replace(/\/\/tail$/, "");
      parts.push(d);
      size += d.length + 1;
    }
    return "[" + parts.join(",\n") + "]";
  };
  const big = bigValid();
  add("big-valid", big, { modes: FILE_STDIN });
  add("big-junk-after", big + "\n]]", { modes: FILE_STDIN });
  add("big-trunc-odd", big.slice(0, big.length - 777), { modes: FILE_STDIN });
  add("big-trunc-half", big.slice(0, big.length >> 1), { modes: FILE_STDIN });
  const bigMutated = big.slice(0, mb(2) + 123) + "@" + big.slice(mb(2) + 124);
  add("big-mutated-at-2mb", bigMutated, { modes: FILE_STDIN });
  add("big-nums", "[" + Array.from({ length: 400_000 }, () => numTok(rng)).join(",") + "]", { modes: FILE_STDIN });
  add("big-string", '"' + Array.from({ length: 200_000 }, () => strPiece(rng)).join("") + '"', { modes: FILE_STDIN });
  add("big-string-unterminated", '["' + "x".repeat(mb(3)), { modes: FILE_STDIN });
  add("big-ws-then-error", " ".repeat(mb(2)) + "x", { modes: FILE_STDIN });
  add("big-ws-then-value", "\n".repeat(mb(2)) + "[1]", { modes: FILE_STDIN });
  add("big-ws-only", " \n".repeat(mb(1)), { modes: FILE_STDIN });
  add("big-comment", "/*" + "x\n".repeat(mb(1)) + "*/ [1]", { modes: FILE_STDIN });
  add("big-comment-unterminated", "[1] /*" + "x".repeat(mb(3)), { modes: FILE_STDIN });
  add("big-line-comment-eof", "[1]//" + "x".repeat(mb(3)), { modes: FILE_STDIN });
  add("big-lines-error", "[\n" + "1,\n".repeat(300_000) + "@\n]", { modes: FILE_STDIN });
  add("big-crlf", "[\r\n" + "1,\r\n".repeat(300_000) + "2]", { modes: FILE_STDIN });
  add("big-ident-keys", "{" + Array.from({ length: 200_000 }, (_, i) => `k${i}:${i}`).join(",") + "}", { modes: FILE_STDIN });

  const fixtures = readFileSync(fixturesPath, "latin1");
  const unescape = (lit: string): string =>
    lit.startsWith("{|")
      ? lit.slice(2, -2)
      : lit.slice(1, -1).replace(/\\(.)/g, (_m, c: string) => ({ n: "\n", t: "\t", r: "\r" })[c as "n"] ?? c);
  const fixtureLiteral = /\{\|[\s\S]*?\|\}|"(?:[^"\\\n]|\\.)*"/g;
  const toBuf = (lit: string): Buffer => Buffer.from(Buffer.from(unescape(lit), "latin1").toString("utf8"), "utf8");
  const fixtureQueries = [".", "length", "keys"];
  let nFixtures = 0;
  for (const m of fixtures.matchAll(/^let (\w*_json\w*) =\s*(\{\|[\s\S]*?\|\}|"(?:[^"\\\n]|\\.)*")/gm)) {
    add(`fixture-${m[1]}`, toBuf(m[2] as string), { queries: fixtureQueries });
    nFixtures++;
  }
  const snippetBlock = /let snippets =\s*\[([\s\S]*?)\n\s*\]/.exec(fixtures);
  if (snippetBlock) {
    const snippets = (snippetBlock[1] as string).match(fixtureLiteral)?.map((l) => unescape(l)) ?? [];
    const joined = snippets.join("");
    add("fixture-json_string", joined, { queries: fixtureQueries });
    add("fixture-json_string_crlf", snippets.join("\r\n"), { queries: fixtureQueries });
    add("fixture-json_string_newline", joined + "\n", { queries: fixtureQueries });
    nFixtures += 3;
  }
  if (nFixtures < 40) throw new Error(`only ${nFixtures} fixtures found in ${fixturesPath}`);

  for (const f of readdirSync(benchDir).filter((n) => n.endsWith(".json")).sort()) {
    const path = join(benchDir, f);
    const huge = statSync(path).size > mb(10);
    if (huge && skipHuge) continue;
    cases.push({
      name: `benchmark-${f}`,
      data: null,
      path,
      queries: [".", "length", "keys"],
      rich: false,
      modes: huge ? ["file"] : FILE_STDIN,
    });
  }
  return cases;
}

function plan(c: Case, data: Buffer): Run[] {
  const inlineOk =
    c.modes.includes("inline") &&
    data.length < INLINE_LIMIT &&
    data[0] !== 0x2d &&
    !data.includes(0) &&
    Buffer.from(data.toString("utf8"), "utf8").equals(data);
  const modes = c.modes.filter((m) => m !== "inline" || inlineOk);
  const runs: Run[] = [];
  for (const query of c.queries) {
    for (const flags of c.rich ? [["-c"], []] : [["-c"]]) {
      for (const mode of modes) runs.push({ query, flags, mode });
    }
    if (!c.rich) runs.push({ query, flags: [], mode: "file" });
  }
  return runs;
}

function exec(binary: string, args: string[], stdin: Buffer | null, cwd: string): Promise<Result> {
  return new Promise((resolveRun, reject) => {
    const child = spawn(binary, args, { cwd, stdio: [stdin ? "pipe" : "ignore", "pipe", "pipe"] });
    const out = createHash("sha256");
    const err = createHash("sha256");
    let outLen = 0;
    let errLen = 0;
    const outHead: Buffer[] = [];
    const errHead: Buffer[] = [];
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, RUN_TIMEOUT_MS);
    const collect = (hash: ReturnType<typeof createHash>, head: Buffer[], len: () => number, bump: (n: number) => void) => (chunk: Buffer): void => {
      hash.update(chunk);
      if (len() < HEAD_BYTES) head.push(chunk.subarray(0, HEAD_BYTES - len()));
      bump(chunk.length);
    };
    const { stdout, stderr } = child;
    if (!stdout || !stderr) {
      clearTimeout(timer);
      reject(new Error(`no output pipes for ${binary}`));
      return;
    }
    stdout.on("data", collect(out, outHead, () => outLen, (n) => (outLen += n)));
    stderr.on("data", collect(err, errHead, () => errLen, (n) => (errLen += n)));
    if (stdin && child.stdin) {
      child.stdin.on("error", () => {});
      child.stdin.end(stdin);
    }
    child.on("error", (e) => {
      clearTimeout(timer);
      reject(e);
    });
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      resolveRun({
        code,
        signal,
        timedOut,
        stdoutLen: outLen,
        stdoutSha: out.digest("hex"),
        stdoutHead: Buffer.concat(outHead),
        stderrLen: errLen,
        stderrSha: err.digest("hex"),
        stderrHead: Buffer.concat(errHead),
      });
    });
  });
}

const same = (a: Result, b: Result): boolean =>
  a.code === b.code &&
  a.signal === b.signal &&
  a.timedOut === b.timedOut &&
  a.stdoutLen === b.stdoutLen &&
  a.stdoutSha === b.stdoutSha &&
  a.stderrLen === b.stderrLen &&
  a.stderrSha === b.stderrSha;

async function matchesOldInline(oldBin: string, run: Run, data: Buffer, filePath: string, newResult: Result, cwd: string): Promise<boolean> {
  if (data.length >= KNOWN_DIFF_LIMIT || data[0] === 0x2d || data.includes(0)) return false;
  const script = 'x=$(cat "$1"; printf x); x=${x%x}; shift; exec "$0" "$@" "$x"';
  const inline = await exec("bash", ["-c", script, oldBin, filePath, ...run.flags, run.query], null, cwd);
  return same(inline, newResult);
}

function esc(b: Buffer, max: number): string {
  let s = "";
  for (const byte of b.subarray(0, max)) {
    if (byte === 0x5c) s += "\\\\";
    else if (byte === 0x0a) s += "\\n";
    else if (byte === 0x0d) s += "\\r";
    else if (byte === 0x09) s += "\\t";
    else if (byte >= 0x20 && byte < 0x7f) s += String.fromCharCode(byte);
    else s += "\\x" + byte.toString(16).padStart(2, "0");
  }
  return b.length > max ? `${s}... (${b.length} bytes)` : s;
}

function describe(r: Result): string {
  const status = r.timedOut ? "TIMEOUT" : r.signal ? `signal=${r.signal}` : `exit=${r.code}`;
  return [
    `${status}`,
    `    stdout ${r.stdoutLen}B sha=${r.stdoutSha.slice(0, 12)}: ${esc(r.stdoutHead, 300)}`,
    `    stderr ${r.stderrLen}B sha=${r.stderrSha.slice(0, 12)}: ${esc(r.stderrHead, 300)}`,
  ].join("\n");
}

function classify(r: Result): string {
  const head = r.stdoutHead.toString("latin1");
  const at = head.indexOf("JSON parse error:");
  if (at >= 0) {
    const detail = head.slice(at).split("\n")[1] ?? "";
    return "error: " + detail.replace(/ '[\s\S]*$/, "").replace(/\d+/g, "N");
  }
  if (r.timedOut) return "timeout";
  if (r.code !== 0 || r.stderrLen > 0) return "other failure";
  return "ok";
}

function parseArgs(argv: string[]): { oldBin: string; newBin: string; seed: number; dir: string; workers: number; skipHuge: boolean } {
  const positional: string[] = [];
  let seed = 20260711;
  let dir = process.env["TMPDIR"] ?? tmpdir();
  let workers = 4;
  let skipHuge = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i] as string;
    if (a === "--seed") seed = Number(argv[++i]);
    else if (a === "--dir") dir = argv[++i] as string;
    else if (a === "--workers") workers = Number(argv[++i]);
    else if (a === "--skip-huge") skipHuge = true;
    else positional.push(a);
  }
  if (positional.length !== 2 || !Number.isInteger(seed) || !Number.isInteger(workers) || workers < 1) {
    console.error("usage: node scripts/json-reader-diff.ts <old-bin> <new-bin> [--seed N] [--dir D] [--workers N] [--skip-huge]");
    process.exit(2);
  }
  return { oldBin: resolve(positional[0] as string), newBin: resolve(positional[1] as string), seed, dir: resolve(dir), workers, skipHuge };
}

async function main(): Promise<void> {
  const { oldBin, newBin, seed, dir, workers, skipHuge } = parseArgs(process.argv.slice(2));
  const root = fileURLToPath(new URL("..", import.meta.url));
  console.log(`seed ${seed}`);
  console.log(`old ${oldBin}`);
  console.log(`new ${newBin}`);

  mkdirSync(dir, { recursive: true });
  const work = mkdtempSync(join(dir, "json-reader-diff-"));
  const casesDir = join(work, "cases");
  const cwd = join(work, "cwd");
  const mismatchDir = join(work, "mismatches");
  for (const d of [casesDir, cwd, mismatchDir]) mkdirSync(d);

  const rng = makeRng(seed);
  const cases = buildCases(rng, join(root, "benchmarks"), join(root, "source/jotason/test/Fixtures.ml"), skipHuge);
  console.log(`generated ${cases.length} cases in ${work}`);

  const started = Date.now();
  let runs = 0;
  let knownRefill = 0;
  let done = 0;
  const mismatches: Mismatch[] = [];
  const mismatchCases = new Set<string>();
  const kinds = new Map<string, number>();
  const samples = new Map<string, string[]>();
  let next = 0;

  const runCase = async (c: Case, index: number): Promise<void> => {
    const filePath = c.path ?? join(casesDir, `c${index}.json`);
    if (!c.path) writeFileSync(filePath, c.data as Buffer);
    const data = c.data ?? readFileSync(filePath);
    try {
      for (const run of plan(c, data)) {
        const args = [...run.flags, run.query];
        if (run.mode === "file") args.push(filePath);
        if (run.mode === "inline") args.push(data.toString("utf8"));
        const stdin = run.mode === "stdin" ? data : null;
        const [a, b] = await Promise.all([exec(oldBin, args, stdin, cwd), exec(newBin, args, stdin, cwd)]);
        runs++;
        const kind = classify(a);
        kinds.set(kind, (kinds.get(kind) ?? 0) + 1);
        if (kind === "timeout" || kind === "other failure") {
          const seen = samples.get(kind) ?? [];
          if (seen.length < 5) samples.set(kind, [...seen, `${c.name} ${run.flags.join(" ")} ${run.query} ${run.mode}: ${esc(a.stdoutHead, 80)} ${esc(a.stderrHead, 80)}`]);
        }
        if (!same(a, b) && run.mode !== "inline" && (await matchesOldInline(oldBin, run, data, filePath, b, cwd))) {
          knownRefill++;
        } else if (!same(a, b)) {
          mismatches.push({ caseName: c.name, run, input: c.path ? null : data, path: c.path, oldResult: a, newResult: b });
          mismatchCases.add(c.name);
        }
      }
    } finally {
      if (!c.path) rmSync(filePath, { force: true });
    }
  };

  const worker = async (): Promise<void> => {
    for (;;) {
      const i = next++;
      const c = cases[i];
      if (!c) return;
      await runCase(c, i);
      if (++done % 500 === 0) console.error(`  ${done}/${cases.length} cases, ${runs} runs, ${mismatches.length} mismatches`);
    }
  };
  await Promise.all(Array.from({ length: workers }, worker));

  const seconds = ((Date.now() - started) / 1000).toFixed(1);
  const report: string[] = [];
  mismatches.forEach((m) => {
    const label = `${m.caseName} [${m.run.flags.join(" ")} ${JSON.stringify(m.run.query)} via ${m.run.mode}]`;
    const input = m.input ? `input (${m.input.length} bytes): ${esc(m.input, 200)}` : `input file: ${m.path}`;
    report.push(`MISMATCH ${label}\n  ${input}\n  old: ${describe(m.oldResult)}\n  new: ${describe(m.newResult)}`);
    if (m.input && !existsInDir(mismatchDir, m.caseName)) {
      writeFileSync(join(mismatchDir, `${m.caseName.replace(/[^\w.-]/g, "_")}.bin`), m.input);
    }
  });
  writeFileSync(join(mismatchDir, "report.txt"), report.join("\n\n") + "\n");
  for (const r of report.slice(0, MAX_PRINTED)) console.log(`\n${r}`);
  if (report.length > MAX_PRINTED) console.log(`\n... ${report.length - MAX_PRINTED} more in ${join(mismatchDir, "report.txt")}`);

  console.log("\nbaseline outcome distribution (old binary):");
  for (const [k, v] of [...kinds].sort((x, y) => y[1] - x[1])) console.log(`  ${String(v).padStart(7)}  ${k}`);
  for (const [k, v] of samples) for (const line of v) console.log(`  sample ${k}: ${line}`);
  console.log(`\nseed ${seed}`);
  console.log(`cases: ${cases.length}`);
  console.log(`runs: ${runs}`);
  console.log(`known: refill range fix: ${knownRefill} runs`);
  console.log(`mismatching runs: ${mismatches.length}`);
  console.log(`mismatching cases: ${mismatchCases.size}`);
  console.log(`runtime: ${seconds}s`);
  if (mismatches.length > 0) {
    console.log(`mismatching inputs saved in ${mismatchDir}`);
    process.exit(1);
  }
  rmSync(work, { recursive: true, force: true });
}

function existsInDir(dirPath: string, caseName: string): boolean {
  return readdirSync(dirPath).includes(`${caseName.replace(/[^\w.-]/g, "_")}.bin`);
}

main().catch((e: unknown) => {
  console.error(e);
  process.exit(2);
});

// Generate natural neural VO clips (edge-tts) for each narration line + a durations manifest.
// Run: node demo/gen-vo.mjs   → demo/vo/<id>.mp3 + demo/vo/durations.json
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const lines = JSON.parse(readFileSync(join(here, "lines.json"), "utf8"));
const outDir = join(here, "vo");
mkdirSync(outDir, { recursive: true });

const VOICE = "en-US-BrianMultilingualNeural"; // warm, natural, conversational
const RATE = "-4%";

const durations = {};
for (const { id, text } of lines) {
  const mp3 = join(outDir, `${id}.mp3`);
  execFileSync("edge-tts", ["--voice", VOICE, `--rate=${RATE}`, "--text", text, "--write-media", mp3], { stdio: "ignore" });
  const d = execFileSync("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "default=nk=1:nw=1", mp3], { encoding: "utf8" }).trim();
  durations[id] = Math.round(parseFloat(d) * 1000) / 1000;
  console.log(`${id.padEnd(11)} ${durations[id]}s`);
}
writeFileSync(join(outDir, "durations.json"), JSON.stringify(durations, null, 2));
console.log("total VO:", Object.values(durations).reduce((a, b) => a + b, 0).toFixed(1), "s → demo/vo/durations.json");

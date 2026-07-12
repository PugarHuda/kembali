// Mux the neural VO clips onto the recorded demo video, each placed at its logged timestamp.
// Run after `npm run demo`:  node demo/mux.mjs  → ../media/kembali-demo.mp4
import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const offsets = JSON.parse(readFileSync(join(here, "offsets.json"), "utf8"));

// find the recorded webm (Playwright names the dir after the test title)
const outRoot = join(here, "output");
let webm = null;
for (const d of readdirSync(outRoot)) {
  const cand = join(outRoot, d, "video.webm");
  if (existsSync(cand)) { webm = cand; break; }
}
if (!webm) throw new Error("no demo/output/**/video.webm — run `npm run demo` first");

const inputs = ["-y", "-i", webm];
const filters = [];
const mixLabels = [];
offsets.forEach(({ id, offset }, i) => {
  const clip = join(here, "vo", `${id}.mp3`);
  if (!existsSync(clip)) throw new Error(`missing VO clip ${clip} — run node demo/gen-vo.mjs`);
  inputs.push("-i", clip);
  const inIdx = i + 1; // input 0 is the video
  filters.push(`[${inIdx}:a]adelay=${offset}:all=1[a${i}]`);
  mixLabels.push(`[a${i}]`);
});
const filterComplex =
  filters.join(";") + ";" + mixLabels.join("") + `amix=inputs=${offsets.length}:normalize=0[aout]`;

const out = join(here, "..", "..", "media", "kembali-demo.mp4");
const args = [
  ...inputs,
  "-filter_complex", filterComplex,
  "-map", "0:v", "-map", "[aout]",
  "-c:v", "libx264", "-preset", "medium", "-crf", "23", "-pix_fmt", "yuv420p",
  "-c:a", "aac", "-b:a", "160k",
  "-movflags", "+faststart",
  out,
];
console.log(`muxing ${offsets.length} VO clips onto ${webm.split(/[\\/]/).slice(-2).join("/")} …`);
execFileSync("ffmpeg", args, { stdio: ["ignore", "ignore", "inherit"] });
console.log("→ media/kembali-demo.mp4");

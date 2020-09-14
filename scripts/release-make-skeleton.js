const { execSync } = require("child_process");
const Fs = require("fs");
const Path = require("path");
const esyJson = require("./../esy.json");

const filesToCopy = ["README.md"];

function exec(cmd) {
  console.log(`exec: ${cmd}`);
  return execSync(cmd).toString();
}

function mkdirpSync(p) {
  if (Fs.existsSync(p)) {
    return;
  }
  mkdirpSync(Path.dirname(p));
  Fs.mkdirSync(p);
}

function removeSync(p) {
  exec(`rm -rf "${p}"`);
}

const src = Path.resolve(Path.join(__dirname, ".."));
const dst = Path.resolve(Path.join(__dirname, "..", "_release"));

removeSync(dst);
mkdirpSync(dst);

for (const file of filesToCopy) {
  const p = Path.join(dst, file);
  mkdirpSync(Path.dirname(p));
  Fs.copyFileSync(Path.join(src, file), p);
}

Fs.copyFileSync(
  Path.join(src, "scripts", "release-postinstall.js"),
  Path.join(dst, "postinstall.js")
);

const filesToTouch = ["query-json"];

for (const file of filesToTouch) {
  const p = Path.join(dst, file);
  mkdirpSync(Path.dirname(p));
  Fs.writeFileSync(p, "");
}

const pkgJson = {
  ...esyJson,
  scripts: {
    postinstall: "node postinstall.js",
  },
  bin: "query-json",
  files: [
    "platform-windows-x64/",
    "platform-linux-x64/",
    "platform-darwin-x64/",
    "postinstall.js",
    "query-json",
  ],
};

Fs.writeFileSync(
  Path.join(dst, "package.json"),
  JSON.stringify(pkgJson, null, 2)
);

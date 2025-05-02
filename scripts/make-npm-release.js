const { execSync } = require('child_process');
const Fs = require('fs');
const Path = require('path');

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

const rootFolder = Path.join(__dirname, '..');
const releaseFolder = Path.resolve(rootFolder, '_release');

for (const fileName of ['README.md', 'LICENSE']) {
  const file = Path.join(rootFolder, fileName);
  const destination = Path.join(releaseFolder, fileName);
  Fs.copyFileSync(file, destination);
}

Fs.copyFileSync(
  Path.join(rootFolder, 'scripts', 'release-postinstall.js'),
  Path.join(releaseFolder, 'postinstall.js')
);

const filesToTouch = ['query-json'];

/* Generate an empty binary */
for (const file of filesToTouch) {
  const p = Path.join(releaseFolder, file);
  mkdirpSync(Path.dirname(p));
  Fs.writeFileSync(p, '');
}

const version = process.argv[2];
console.log(`Version: ${version}`);

const pkgJson = {
  "name": "@davesnx/query-json",
  "version": version,
  "scripts": {
    "postinstall": "node postinstall.js"
  },
  "main": "query-json-js/Js.bc.js",
  "bin": {
    "query-json": "query-json"
  },
  "files": [
    "platform-windows-x64/",
    "platform-linux-x64/",
    "platform-darwin-x64/",
    "postinstall.js",
    "query-json-js",
    "README.md"
  ],
  "dependencies": {},
  "devDependencies": {}
};

Fs.writeFileSync(
  Path.join(releaseFolder, 'package.json'),
  JSON.stringify(pkgJson, null, 2)
);

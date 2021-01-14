const { execSync } = require('child_process');
const Fs = require('fs');
const Path = require('path');
const esyJson = require('../esy.json');

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

removeSync(releaseFolder);
mkdirpSync(releaseFolder);

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

const pkgJson = {
  ...esyJson,
  scripts: {
    postinstall: 'node postinstall.js',
  },
  main: 'bundled/Js.bc.js',
  bin: 'query-json',
  files: [
    'platform-windows-x64/',
    'platform-linux-x64/',
    'platform-darwin-x64/',
    'postinstall.js',
    'bundled',
    'query-json',
    'README.md',
  ],
  dependencies: {},
  devDependencies: {},
};

Fs.writeFileSync(
  Path.join(releaseFolder, 'package.json'),
  JSON.stringify(pkgJson, null, 2)
);

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

const root = Path.resolve(Path.join(__dirname, '..'));
const releaseFolder = Path.resolve(root, '_release');

removeSync(releaseFolder);
mkdirpSync(releaseFolder);

for (const file of ['README.md', 'LICENSE']) {
  const p = Path.join(releaseFolder, file);
  mkdirpSync(Path.dirname(p));
  Fs.copyFileSync(Path.join(root, file), p);
}

Fs.copyFileSync(
  Path.join(root, 'scripts', 'release-postinstall.js'),
  Path.join(releaseFolder, 'postinstall.js')
);

const filesToTouch = ['query-json'];

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
  main: 'index.js',
  bin: 'query-json',
  files: [
    'platform-windows-x64/',
    'platform-linux-x64/',
    'platform-darwin-x64/',
    'postinstall.js',
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

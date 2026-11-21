#!/usr/bin/env node

const Path = require('path');
const Child_process = require('child_process');
const Fs = require('fs');

const platform = process.platform;

const binariesToCopy = ['query-json'];

function find_arch() {
  if (process.arch === 'x64') {
    return 'x64';
  }

  if (process.arch === 'arm64') {
    return 'arm64';
  }

  if (process.platform === 'darwin') {
    return 'x64';
  }

  if (process.platform === 'win32') {
    var useEnv = false;
    try {
      useEnv = !!(
        process.env.SYSTEMROOT && Fs.statSync(process.env.SYSTEMROOT)
      );
    } catch (err) { }

    const sysRoot = useEnv ? process.env.SYSTEMROOT : 'C:\\Windows';

    const isWOW64 = false;
    try {
      isWOW64 = !!Fs.statSync(Path.join(sysRoot, 'sysnative'));
    } catch (err) { }

    return isWOW64 ? 'x64' : 'x86';
  }

  if (process.platform === 'linux') {
    const output = Child_process.execSync('getconf LONG_BIT', { encoding: 'utf8' });
    return output === '64\n' ? 'x64' : 'x86';
  }

  return 'x86';
}

function copyFileSync(sourcePath, destPath) {
  const data = Fs.readFileSync(sourcePath);
  const stat = Fs.statSync(sourcePath);
  Fs.writeFileSync(destPath, data);
  Fs.chmodSync(destPath, stat.mode);
}

const copyPlatformBinaries = (platformPath) => {
  const platformBuildPath = Path.join(__dirname, platformPath);

  binariesToCopy.forEach((binaryPath) => {
    const sourcePath = Path.join(platformBuildPath, binaryPath);
    const destPath = Path.join(__dirname, binaryPath);
    if (Fs.existsSync(destPath)) {
      Fs.unlinkSync(destPath);
    }
    copyFileSync(sourcePath, destPath);
    Fs.chmodSync(destPath, 0o755);
  });
};

const arch = find_arch();

const platformPath = 'platform-' + platform + '-' + arch;
const supported = Fs.existsSync(platformPath);

if (!supported) {
  console.error('query-json does not support this platform yet.');
  console.error('');
  console.error(
    'If you want query-json to work fine on this platform natively,'
  );
  console.error('please open an issue at our repository, linked above.');
  console.error('Specify that you are on the ' + platform + ' platform,');
  console.error('and on the ' + arch + ' architecture.');
  process.exit(1);
}

copyPlatformBinaries(platformPath);

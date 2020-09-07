const cp = require("child_process");
const fs = require("fs");
const Path = require("path");

const getNameAndVersion = (package) => {
  const packageJson = fs.readFileSync(`${package}.json`, { encoding: "utf8" });
  const packageData = JSON.parse(packageJson);
  const version = fs
    .readFileSync(Path.resolve("VERSION"), { encoding: "utf8" })
    .toString()
    .trim();

  return { package, name: packageData.name, version };
};

const preparePackage = (packageData) => {
  const package = packageData.package;
  console.log(`Preparing package`);

  const packageJson = fs.readFileSync(`${package}.json`, { encoding: "utf8" });
  const updatedPackageJson = JSON.parse(packageJson);
  updatedPackageJson.version = packageData.version;

  fs.writeFileSync(
    Path.resolve("package.json"),
    JSON.stringify(updatedPackageJson, null, 2)
  );

  return package;
};

const deleteFolderRecursive = (path) => {
  if (fs.existsSync(path)) {
    fs.readdirSync(path).forEach((file, index) => {
      const curPath = Path.join(path, file);
      if (fs.lstatSync(curPath).isDirectory()) {
        // recurse
        deleteFolderRecursive(curPath);
      } else {
        // delete file
        fs.unlinkSync(curPath);
      }
    });
    fs.rmdirSync(path);
  }
};

const buildAndPublishPackage = (package) => {
  console.log(`Building package`);
  const cwd = Path.resolve(".");
  try {
    cp.execSync("esy install", { cwd, encoding: "utf8" });
    cp.execSync("esy build", { cwd, encoding: "utf8" });
  } catch (e) {
    console.warn(e);
    return;
  }
  console.log(`Publishing package`);
  cp.execSync("npm publish --access public", {
    cwd,
    encoding: "utf8",
  });
};

const filterPackage = (packageInfo) => {
  try {
    const remoteVersion = cp
      .execSync(`npm view ${packageInfo.name} version`, { encoding: "utf8" })
      .toString()
      .trim();

    console.log({ ...packageInfo, remoteVersion });

    return remoteVersion !== packageInfo.version;
  } catch (e) {
    return true;
  }
};

["package"]
  .map(getNameAndVersion)
  .filter(filterPackage)
  .map((packageData) => {
    preparePackage(packageData);
    return packageData;
  })
  .map((packageData) => {
    buildAndPublishPackage(packageData.package);
    return packageData;
  })
  .forEach((packageData) =>
    console.log(
      `Successfully published ${packageData.name}@${packageData.version}`
    )
  );

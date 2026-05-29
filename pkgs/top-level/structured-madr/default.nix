{ lib
, buildNpmPackage
, fetchzip
, importNpmLock
, makeWrapper
, nodejs_22
, nodejs ? nodejs_22
}:

buildNpmPackage rec {
  pname = "structured-madr";
  version = "1.2.0";

  src = fetchzip {
    url = "https://github.com/zircote/structured-madr/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-mxQhqpgvf7bUYPxfjKz8y/TCYDu3yBHjAtf79226L+g=";
    stripRoot = true;
  };

  inherit nodejs;

  npmDeps = importNpmLock {
    npmRoot = src;
  };

  npmConfigHook = importNpmLock.npmConfigHook;

  dontNpmBuild = true;

  npmInstallFlags = [
    "--omit=dev"
  ];

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    packageRoot="$out/lib/node_modules/structured-madr"

    mkdir -p \
      "$out/bin" \
      "$packageRoot/src" \
      "$packageRoot/schemas" \
      "$out/share/structured-madr/schemas"

    cp package.json "$packageRoot/package.json"
    cp src/validate.js "$packageRoot/src/validate.js"
    cp schemas/structured-madr.schema.json "$packageRoot/schemas/structured-madr.schema.json"

    cp -R node_modules "$packageRoot/node_modules"

    ln -s "$packageRoot/schemas/structured-madr.schema.json" \
      "$out/share/structured-madr/schemas/structured-madr.schema.json"

    makeWrapper ${lib.getExe nodejs} "$out/bin/structured-madr-validate" \
      --add-flags "$packageRoot/src/validate.js" \
      --set ACTION_PATH "$packageRoot"

    runHook postInstall
  '';

  passthru = {
    schema = "${placeholder "out"}/share/structured-madr/schemas/structured-madr.schema.json";
  };

  meta = {
    description = "Structured MADR validator for machine-readable Architecture Decision Records";
    homepage = "https://github.com/zircote/structured-madr";
    changelog = "https://github.com/zircote/structured-madr/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "structured-madr-validate";
    platforms = lib.platforms.all;
  };
}

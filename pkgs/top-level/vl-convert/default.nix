{ lib
, stdenvNoCC
, fetchurl
, unzip
}:

let
  pname = "vl-convert";
  version = "1.9.0";

  asset =
    if stdenvNoCC.hostPlatform.system == "x86_64-linux" then "linux-64"
    else throw "Unsupported platform: ${stdenvNoCC.hostPlatform.system}";

  hashes = {
    linux-64 = "sha256-9VdjehWcdRChSG4eQahsORmr1xwYq8CCa0mcdscSqlM=";
  };

  src = fetchurl {
    url = "https://github.com/vega/vl-convert/releases/download/v${version}/vl-convert_${asset}.zip";
    hash = hashes.${asset} or (throw "Missing hash for asset=${asset}");
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    binary="$(find . -type f -name vl-convert -print -quit)"
    install -Dm755 "$binary" "$out/bin/vl-convert"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Command line utility for converting Vega-Lite and Vega visualizations";
    homepage = "https://github.com/vega/vl-convert";
    license = licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "vl-convert";
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}

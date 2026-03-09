{ lib
, buildPythonApplication
, fetchPypi
, pythonOlder
, jsonpyth
, pygal
}:

buildPythonApplication rec {
  pname = "procpath";
  version = "1.14.0";
  format = "wheel";

  disabled = pythonOlder "3.9";

  src = fetchPypi {
    pname = "Procpath";
    inherit version format;
    dist = "py3";
    python = "py3";
    abi = "none";
    platform = "any";
    hash = "sha256-8/k+zqQyO2vkFSl/Bc7z60AFbcxI0o2KrgaHcGFZefs=";
  };

  propagatedBuildInputs = [
    jsonpyth
    pygal
  ];

  pythonImportsCheck = [
    "procpath"
  ];

  meta = with lib; {
    description = "Process tree analysis workbench";
    homepage = "https://saajns.heptapod.io/procpath/";
    license = licenses.lgpl3Only;
    platforms = platforms.linux;
    mainProgram = "procpath";
  };
}

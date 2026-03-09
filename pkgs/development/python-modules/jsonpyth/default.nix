{ lib
, buildPythonPackage
, fetchPypi
, pyparsing
, pythonOlder
}:

buildPythonPackage rec {
  pname = "jsonpyth";
  version = "0.1.3";
  pyproject = false;

  disabled = pythonOlder "3.5";

  src = fetchPypi {
    pname = "JSONPyth";
    inherit version;
    hash = "sha256-q52OnnJVjn4eWdWYtAjWA3Lg2V9W1MQWffKUa5uZ2mg=";
  };

  propagatedBuildInputs = [
    pyparsing
  ];

  pythonImportsCheck = [
    "jsonpyth"
  ];

  meta = with lib; {
    description = "JSONPath implementation for Python";
    homepage = "https://github.com/Frimkron/JSONPyth";
    license = licenses.mit;
    platforms = platforms.all;
  };
}

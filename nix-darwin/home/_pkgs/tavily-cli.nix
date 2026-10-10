{
  lib,
  python3Packages,
  fetchPypi,
}:

let
  # nixpkgs doesn't package the SDK the CLI is built on.
  tavily-python = python3Packages.buildPythonPackage rec {
    pname = "tavily_python";
    version = "0.8.5";
    format = "wheel";

    src = fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      hash = "sha256-+NKID1qmfPPuLrH3yTNupQ3DMeseQGaIORutsBQFmac=";
    };

    dependencies = with python3Packages; [
      requests
      tiktoken
      httpx
    ];

    pythonImportsCheck = [ "tavily" ];
  };
in
python3Packages.buildPythonApplication rec {
  pname = "tavily_cli";
  version = "0.1.8";
  format = "wheel";

  src = fetchPypi {
    inherit pname version format;
    dist = "py3";
    python = "py3";
    hash = "sha256-ddMHh5qc83z2k3hWYuyEIGPYwKwyhxJcFC4xiIr9RdU=";
  };

  dependencies = with python3Packages; [
    certifi
    click
    httpx
    packaging
    psutil
    requests
    rich
    tavily-python
    urllib3
  ];

  meta = {
    description = "Web search, extract, map, crawl and research from the terminal";
    homepage = "https://github.com/tavily-ai/tavily-cli";
    license = lib.licenses.mit;
    mainProgram = "tvly";
  };
}

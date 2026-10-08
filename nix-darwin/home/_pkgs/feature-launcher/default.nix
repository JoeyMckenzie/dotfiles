{
  writeShellApplication,
  jq,
  direnv,
}:

writeShellApplication {
  name = "feature";
  runtimeInputs = [
    jq
    direnv
  ];
  text = builtins.readFile ./feature.sh;
}

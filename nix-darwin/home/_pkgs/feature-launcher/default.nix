{
  writeShellApplication,
  jq,
}:

writeShellApplication {
  name = "feature";
  runtimeInputs = [ jq ];
  text = builtins.readFile ./feature.sh;
}

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nodejs
    go

    # Rust w/ full stable toolchain (cargo, rustc, rustfmt, clippy) via rust-overlay
    (rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" ];
    })

    php84
    php84Packages.composer
    ruby
    (python313.withPackages (ps: with ps; [ pip ]))
    uv
  ];
}

{ pkgs }:
let
  pname = "rakazo";
  version = "0.13.0";

  src = pkgs.fetchurl {                      # Option A
    url = "https://github.com/elie222/rakazo/releases/download/v${version}/Rakazo-${version}.AppImage";
    hash = "sha256-d3nccNudLBs72e00UBn8WA5KVa2k50BOX8ch8Uc4LbE=";
  };
  # Option B: use this instead of fetchurl. It needs `--impure`, so A is simpler.
  # src = /home/lazy/appimages/Rakazo-0.13.0.AppImage;

  extracted = pkgs.appimageTools.extract { inherit pname version src; };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  # Adds the app-menu entry and icon
  extraInstallCommands = ''
    install -Dm444 ${extracted}/*.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/*.desktop \
      --replace-quiet 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${extracted}/usr/share/icons $out/share/ 2>/dev/null || true
  '';
}

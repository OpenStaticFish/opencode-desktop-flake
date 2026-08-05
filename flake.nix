{
  description = "OpenCode Desktop - AI-powered coding agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      
      version = "1.18.13";
      
    in {
      packages = forEachSystem (pkgs: 
        let
          inherit (pkgs) stdenv lib fetchurl dpkg;
          inherit (pkgs.buildPackages) buildFHSEnv;
          
          platformInfo = {
            x86_64-linux = {
              asset = "opencode-desktop-linux-amd64.deb";
              hash = "sha256-EltiWIaoQfnI/Z5AL48b+LFKbghEbTE7wKDfxpMzVpc=";
            };
            aarch64-linux = {
              asset = "opencode-desktop-linux-arm64.deb";
              hash = "sha256-MnFF/CxTI890IDm5qYGUAXTXKTN4WU81d4bQ0wNBY+k=";
            };
            aarch64-darwin = {
              asset = "opencode-desktop-mac-arm64.app.tar.gz";
              hash = "sha256-4MzXdVz+Egt/3RDrszts0VAyVK254Y9REKKhPVOzofs=";
            };
            x86_64-darwin = {
              asset = "opencode-desktop-mac-x64.app.tar.gz";
              hash = "sha256-rpOzKNqZUHxzBEO6rO3NXZakyZr2Km8q+Y8OyWg0lwo=";
            };
          };
          
          info = platformInfo.${pkgs.stdenv.hostPlatform.system} or (throw "Unsupported system: ${pkgs.stdenv.hostPlatform.system}");
          
          # Unwrapped binary package
          opencode-desktop-unwrapped = stdenv.mkDerivation {
            pname = "opencode-desktop-unwrapped";
            inherit version;
            
            src = fetchurl {
              url = "https://github.com/anomalyco/opencode/releases/download/v${version}/${info.asset}";
              hash = info.hash;
            };
            
            nativeBuildInputs = [ dpkg ];
            
            dontBuild = true;
            dontFixup = true;
            
            unpackPhase = lib.optionalString stdenv.isLinux ''
              dpkg-deb -x $src .
            '';
            
            installPhase = lib.optionalString stdenv.isLinux ''
              mkdir -p $out
              cp -r opt $out/
              cp -r usr/* $out/
              mkdir -p $out/bin
              ln -s $out/opt/OpenCode/ai.opencode.desktop $out/bin/opencode-desktop-unwrapped
            '';
          };
          
          # FHS environment for running the binary
          opencode-desktop-fhs = buildFHSEnv {
            name = "opencode-desktop";
            targetPkgs = pkgs: with pkgs; [
              # Core libraries
              glib
              gtk3
              gtk4
              webkitgtk_4_1
              glib-networking
              gsettings-desktop-schemas
              
              # Graphics
              cairo
              pango
              gdk-pixbuf
              librsvg
              
              # X11/XWayland
              xorg.libX11
              xorg.libXcomposite
              xorg.libXdamage
              xorg.libXext
              xorg.libXfixes
              xorg.libXrandr
              xorg.libxcb
              libxkbcommon
              libdrm
              libgbm
              libglvnd
              mesa
              
              # Networking/Security
              openssl
              libsoup_3
              dbus
              libappindicator
              
              # GStreamer
              gst_all_1.gstreamer
              gst_all_1.gst-plugins-base
              gst_all_1.gst-plugins-good
              gst_all_1.gst-plugins-bad
              
              # Accessibility
              at-spi2-atk
              at-spi2-core
              
              # Misc
              alsa-lib
              nss
              nspr
              expat
              libuuid
              udev
              cups
              
              # Fontconfig
              fontconfig
              freetype
            ];
            
            extraInstallCommands = ''
              mkdir -p $out/share/applications
              mkdir -p $out/share/icons/hicolor

              # Copy desktop entry
              cp ${opencode-desktop-unwrapped}/share/applications/ai.opencode.desktop.desktop $out/share/applications/opencode-desktop.desktop
              sed -i 's|Exec=/opt/OpenCode/ai.opencode.desktop %U|Exec=opencode-desktop %U|' $out/share/applications/opencode-desktop.desktop
              sed -i 's|Icon=ai.opencode.desktop|Icon=opencode-desktop|' $out/share/applications/opencode-desktop.desktop

              # Copy all shipped icon sizes; upstream does not consistently include 32x32.
              for icon in ${opencode-desktop-unwrapped}/share/icons/hicolor/*/apps/ai.opencode.desktop.png; do
                size=$(basename "$(dirname "$(dirname "$icon")")")
                mkdir -p "$out/share/icons/hicolor/$size/apps"
                cp "$icon" "$out/share/icons/hicolor/$size/apps/opencode-desktop.png"
              done

              # Copy metainfo
              if [ -d ${opencode-desktop-unwrapped}/share/metainfo ]; then
                mkdir -p $out/share/metainfo
                cp ${opencode-desktop-unwrapped}/share/metainfo/* $out/share/metainfo/
              fi
            '';
            
            runScript = "${opencode-desktop-unwrapped}/bin/opencode-desktop-unwrapped";
          };
          
        in {
          default = opencode-desktop-fhs;
          unwrapped = opencode-desktop-unwrapped;
        }
      );
    };
}

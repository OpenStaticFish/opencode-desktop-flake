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
      
      version = "1.2.1";
      
    in {
      packages = forEachSystem (pkgs: 
        let
          inherit (pkgs) stdenv lib fetchurl dpkg;
          inherit (pkgs.buildPackages) buildFHSEnv;
          
          platformInfo = {
            x86_64-linux = {
              asset = "opencode-desktop-linux-amd64.deb";
              hash = "sha256-MFX7m8CXh6xXyJ5w+AisNI/gkPG7sLDB8EpqF5ylflE=";
            };
            aarch64-linux = {
              asset = "opencode-desktop-linux-arm64.deb";
              hash = "sha256-aX7fvMSXJQfCm8AzY3EmEAHZs1HiuCgO7hhUngCzk5w=";
            };
            aarch64-darwin = {
              asset = "opencode-desktop-darwin-aarch64.app.tar.gz";
              hash = "sha256-9LR2DjHKr11BHQQZBCRM0BzBsOLoZtyLmZTmEVrardE=";
            };
            x86_64-darwin = {
              asset = "opencode-desktop-darwin-x64.app.tar.gz";
              hash = "sha256-G5Z+ziOM/u2jaYOBP2Ss4hEH+7/vs88G2rfeTTz2GBQ=";
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
              cp -r usr/* $out/
              mv $out/bin/OpenCode $out/bin/opencode-desktop-unwrapped
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
              libX11
              libXcomposite
              libXdamage
              libXext
              libXfixes
              libXrandr
              libxcb
              libxkbcommon
              libdrm
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
              cups
              
              # Fontconfig
              fontconfig
              freetype
            ];
            
            extraInstallCommands = ''
              mkdir -p $out/share/applications
              mkdir -p $out/share/icons/hicolor/128x128/apps
              mkdir -p $out/share/icons/hicolor/256x256@2/apps
              mkdir -p $out/share/icons/hicolor/32x32/apps
              
              # Copy desktop entry
              cp ${opencode-desktop-unwrapped}/share/applications/OpenCode.desktop $out/share/applications/opencode-desktop.desktop
              sed -i 's|Exec=OpenCode|Exec=opencode-desktop|' $out/share/applications/opencode-desktop.desktop
              sed -i 's|Icon=OpenCode|Icon=opencode-desktop|' $out/share/applications/opencode-desktop.desktop
              
              # Copy icons
              cp ${opencode-desktop-unwrapped}/share/icons/hicolor/128x128/apps/OpenCode.png $out/share/icons/hicolor/128x128/apps/opencode-desktop.png
              cp ${opencode-desktop-unwrapped}/share/icons/hicolor/256x256@2/apps/OpenCode.png $out/share/icons/hicolor/256x256@2/apps/opencode-desktop.png
              cp ${opencode-desktop-unwrapped}/share/icons/hicolor/32x32/apps/OpenCode.png $out/share/icons/hicolor/32x32/apps/opencode-desktop.png
              
              # Copy metainfo
              mkdir -p $out/share/metainfo
              cp ${opencode-desktop-unwrapped}/share/metainfo/ai.opencode.opencode.metainfo.xml $out/share/metainfo/
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

{
  description = "OpenCode Desktop - AI-powered coding agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Unstable no longer supports Intel macOS; 26.05 is its last supported release.
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
  };

  outputs = { self, nixpkgs, nixpkgs-darwin, ... }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system:
        f (if system == "x86_64-darwin" then nixpkgs-darwin.legacyPackages.${system} else nixpkgs.legacyPackages.${system})
      );
      
      version = "2.2.6";
      
    in {
      packages = forEachSystem (pkgs: 
        let
          inherit (pkgs) stdenv lib fetchurl dpkg;
          inherit (pkgs.buildPackages) buildFHSEnv;
          
          platformInfo = {
            x86_64-linux = {
              asset = "opencode-desktop-linux-amd64.deb";
              hash = "sha256-h/ZlVfOj/sOQHvfhrIb14t61W5AATPQjludUfGsZVFk=";
            };
            aarch64-linux = {
              asset = "opencode-desktop-linux-arm64.deb";
              hash = "sha256-9/YSlP8xHp8O4KKDqwBl80AI+1ciMASANFzaNHZadXE=";
            };
            aarch64-darwin = {
              asset = "opencode-desktop-mac-arm64.app.tar.gz";
              hash = "sha256-jpfhMYFKht8yTlzfARMPnuvNqPp+8Sf0AOAFtqJLXyY=";
            };
            x86_64-darwin = {
              asset = "opencode-desktop-mac-x64.app.tar.gz";
              hash = "sha256-mZK5tfFUFkk1C+ErFdhp/m+fnEPYEPABeuy99JQ4vlk=";
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
            
            nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ dpkg ];

            dontBuild = true;
            dontConfigure = true;
            dontFixup = true;

            unpackPhase = if stdenv.hostPlatform.isLinux then ''
              runHook preUnpack
              dpkg-deb -x "$src" .
              runHook postUnpack
            '' else ''
              runHook preUnpack
              tar -xzf "$src"
              runHook postUnpack
            '';

            installPhase = if stdenv.hostPlatform.isLinux then ''
              runHook preInstall
              mkdir -p "$out/bin"
              cp -r opt "$out/"
              cp -r usr/* "$out/"
              ln -s "$out/opt/OpenCode/ai.opencode" "$out/bin/opencode-desktop-unwrapped"
              runHook postInstall
            '' else ''
              runHook preInstall
              mkdir -p "$out/Applications" "$out/bin"
              cp -R OpenCode.app "$out/Applications/"
              cat > "$out/bin/opencode-desktop" <<EOF
              #!${stdenv.shell}
              exec "$out/Applications/OpenCode.app/Contents/MacOS/OpenCode" "\$@"
              EOF
              chmod +x "$out/bin/opencode-desktop"
              ln -s opencode-desktop "$out/bin/opencode-desktop-unwrapped"
              runHook postInstall
            '';

            meta.mainProgram = if stdenv.hostPlatform.isLinux then "opencode-desktop-unwrapped" else "opencode-desktop";
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
              libx11
              libxcomposite
              libxdamage
              libxext
              libxfixes
              libxrandr
              libxcb
              libxrender
              libxscrnsaver
              libxtst
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
              libnotify
              libsecret
              
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

              # Keep the desktop ID and icon name consistent with upstream metainfo.
              cp ${opencode-desktop-unwrapped}/share/applications/ai.opencode.desktop.desktop "$out/share/applications/"
              sed -i "s|^Exec=.*|Exec=$out/bin/opencode-desktop %U|" "$out/share/applications/ai.opencode.desktop.desktop"
              cp -r ${opencode-desktop-unwrapped}/share/icons/hicolor/. "$out/share/icons/hicolor/"

              # Copy metainfo
              if [ -d ${opencode-desktop-unwrapped}/share/metainfo ]; then
                mkdir -p $out/share/metainfo
                cp ${opencode-desktop-unwrapped}/share/metainfo/* $out/share/metainfo/
              fi
            '';
            
            runScript = "${opencode-desktop-unwrapped}/bin/opencode-desktop-unwrapped";
          };
          
        in {
          default = if stdenv.hostPlatform.isLinux then opencode-desktop-fhs else opencode-desktop-unwrapped;
          unwrapped = opencode-desktop-unwrapped;
        }
      );
    };
}

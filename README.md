# opencode-desktop-flake

Nix flake for installing [OpenCode Desktop](https://opencode.ai) - the AI-powered coding agent.

## Features

- Installs OpenCode Desktop from official GitHub releases
- FHS environment for proper library resolution
- Desktop integration with icons and .desktop entry
- Supports Linux (x86_64, aarch64) and macOS (x86_64, aarch64)

## Usage

### Running directly

```bash
nix run github:anomalyco/opencode-desktop-flake
```

### Installing to your profile

```bash
nix profile install github:anomalyco/opencode-desktop-flake
```

### Using in Home Manager

Add to your `home.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    opencode-desktop.url = "github:anomalyco/opencode-desktop-flake";
  };

  outputs = { self, nixpkgs, home-manager, opencode-desktop, ... }: {
    homeConfigurations.username = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        {
          home.packages = [
            opencode-desktop.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### Using as a flake input

```nix
{
  inputs.opencode-desktop.url = "github:anomalyco/opencode-desktop-flake";

  outputs = { self, nixpkgs, opencode-desktop }: {
    # Use opencode-desktop.packages.${system}.default
  };
}
```

## Building locally

```bash
git clone https://github.com/anomalyco/opencode-desktop-flake.git
cd opencode-desktop-flake
nix build
```

## Available outputs

- `packages.<system>.default` - The main OpenCode Desktop package with FHS environment
- `packages.<system>.unwrapped` - The unwrapped binary (internal use)

## Supported platforms

- `x86_64-linux`
- `aarch64-linux`  
- `x86_64-darwin`
- `aarch64-darwin`

## Notes

- The desktop app requires a running Wayland/X11 session
- On Wayland, the app runs via XWayland by default (set `OC_ALLOW_WAYLAND=1` for native Wayland)
- First launch may take a moment as the FHS environment is set up

## Automated Updates

This repository uses GitHub Actions workflows to automatically handle updates:

### OpenCode Desktop Version Updates

- **Schedule** - Runs daily at 6:00 AM UTC to check for new OpenCode Desktop releases
- **Manual trigger** - Can be triggered manually from the Actions tab
- **Auto-update** - Automatically updates version and calculates new hashes for all platforms
- **Pull requests** - Creates PRs for you to review before merging

### Nixpkgs Updates (flake.lock)

- **Schedule** - Runs every Monday at 4:00 AM UTC
- **Manual trigger** - Can be triggered manually from the Actions tab
- **Pull requests** - Creates PRs for you to review before merging

The workflow uses [update-flake-lock](https://github.com/DeterminateSystems/update-flake-lock) to check for updates to `nixpkgs-unstable` and other flake inputs.

## License

MIT License - see [LICENSE](LICENSE) file

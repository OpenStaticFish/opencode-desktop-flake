# opencode-desktop-flake

Nix flake for installing [OpenCode Desktop v2](https://opencode.ai) - the AI-powered coding agent.

## Features

- Installs the stable OpenCode Desktop v2 release from GitHub
- FHS environment for Linux library resolution
- Linux desktop integration with icons and a .desktop entry
- Native macOS application bundle
- Supports Linux (x86_64, aarch64) and macOS (x86_64, aarch64)

## Usage

### Running directly

```bash
nix run github:OpenStaticFish/opencode-desktop-flake
```

### Installing to your profile

```bash
nix profile install github:OpenStaticFish/opencode-desktop-flake
```

### Using in Home Manager

Add the flake input and package to your Home Manager configuration, for example in `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    opencode-desktop.url = "github:OpenStaticFish/opencode-desktop-flake";
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
  inputs.opencode-desktop.url = "github:OpenStaticFish/opencode-desktop-flake";

  outputs = { self, nixpkgs, opencode-desktop }: {
    # Use opencode-desktop.packages.${system}.default
  };
}
```

## Building locally

```bash
git clone https://github.com/OpenStaticFish/opencode-desktop-flake.git
cd opencode-desktop-flake
nix build
```

## Available outputs

- `packages.<system>.default` - The OpenCode Desktop package (with an FHS environment on Linux)
- `packages.<system>.unwrapped` - The unwrapped binary (internal use)

## Supported platforms

- `x86_64-linux`
- `aarch64-linux`  
- `x86_64-darwin`
- `aarch64-darwin`

Intel macOS uses the `nixpkgs-26.05-darwin` input because newer nixpkgs releases
have dropped `x86_64-darwin` support. Nixpkgs 26.05 is the last release that
supports this platform.

## Notes

- The Linux desktop app requires a running Wayland/X11 session.
- On macOS, the package includes `Applications/OpenCode.app` and an `opencode-desktop` executable.
- OpenCode v2 changes the plugin and server APIs. See the [v1-to-v2 migration guide](https://opencode.ai/docs/migrate-v1) before relying on existing integrations.

## Automated Updates

This repository uses GitHub Actions workflows to automatically handle updates:

### OpenCode Desktop Version Updates

- **Schedule** - Runs daily at 6:00 AM UTC to check for stable OpenCode Desktop v2 releases
- **Manual trigger** - Can be triggered manually from the Actions tab
- **Validation** - Tests the updater, evaluates all platforms, and builds the updated x86_64 Linux package outputs
- **Pull requests** - Creates or updates a PR only after validation passes, and attempts to merge it automatically

The updater ignores v1, prereleases, and unrelated release tags. Before updating,
it verifies that all four desktop assets have SHA-256 digests and refuses downgrades.
Run its tests locally with `python3 -m unittest discover -s tests -v`.

Pushes and pull requests also run native package builds and layout checks for
all four supported platforms.

### Nixpkgs Updates (flake.lock)

- **Schedule** - Runs every Monday at 4:00 AM UTC
- **Manual trigger** - Can be triggered manually from the Actions tab
- **Pull requests** - Creates PRs for you to review before merging

The workflow uses [update-flake-lock](https://github.com/DeterminateSystems/update-flake-lock) to check for updates to the nixpkgs flake inputs.

## License

MIT License - see [LICENSE](LICENSE) file

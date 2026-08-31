# Ghostship on macOS

<p align="center">
  <img src="icons/preview/liquid-glass-macos26.png" width="168" alt="Liquid Glass app icon rendered on macOS 26">
  &nbsp;&nbsp;&nbsp;
  <img src="icons/preview/liquid-glass-macos27.png" width="168" alt="Liquid Glass app icon rendered on macOS 27">
  <br>
  <sub>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>macOS 26 Tahoe</b>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>macOS 27 Golden Gate</b></sub>
</p>

This fork carries fixes on top of upstream [HarbourMasters/Ghostship](https://github.com/HarbourMasters/Ghostship) develop. What each build adds is listed in its [release notes](https://github.com/quarrel07/Ghostship-macOS/releases).

**[Download the latest release](https://github.com/quarrel07/Ghostship-macOS/releases/latest)** (arm64 dmg).

## Branches

- `develop` mirrors upstream.
- `macos-rebase` is upstream develop plus the fork's changes, and is what releases are built from. Some changes live in the [libultraship fork](https://github.com/quarrel07/libultraship) the submodule points at.

## Building

```
git clone --recursive -b macos-rebase https://github.com/quarrel07/Ghostship-macOS.git
cd Ghostship-macOS
cmake -S . -B build -GNinja -DCMAKE_BUILD_TYPE=Release -DSDL2_DIR="$(brew --prefix sdl2-compat)/lib/cmake/SDL2" -DCMAKE_FIND_FRAMEWORK=LAST
cmake --build build --parallel
```

Homebrew dependencies: sdl2-compat, sdl3, glew, libzip, nlohmann-json, tinyxml2, mbedtls@3, ninja. Built and tested on macOS 26 (arm64) with current Xcode; other setups may need adjustments.

Packaging into the dmg is upstream's own CPack flow: `cd build && cpack`.

## Credits

All credit for Ghostship to [Lywx](https://github.com/kiritodv) and the [HarbourMasters](https://github.com/HarbourMasters) team and the [libultraship](https://github.com/Kenix3/libultraship) project. Everything here builds on their work.

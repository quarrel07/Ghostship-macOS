<p align="center">
  <img src="icons/preview/liquid-glass-macos26.png" width="160" alt="Liquid Glass app icon on macOS 26 Tahoe">
  &nbsp;&nbsp;&nbsp;
  <img src="icons/preview/liquid-glass-macos27.png" width="160" alt="Liquid Glass app icon on macOS 27 Golden Gate">
  <br>
  <sub><b>Liquid Glass app icon</b> &nbsp;—&nbsp; macOS 26 Tahoe (left) &nbsp;·&nbsp; macOS 27 Golden Gate (right)</sub>
</p>

# Ghostship — macOS

A macOS-optimized fork of [HarbourMasters/Ghostship](https://github.com/HarbourMasters/Ghostship)
(a *Super Mario 64* port with Satella online play, built on
[libultraship](https://github.com/Kenix3/libultraship) and [Torch](https://github.com/HarbourMasters/Torch)).

The goal of this fork is simple: **a plain build produces a self-contained, codesigned `Ghostship.app`**
that launches on any modern Apple-Silicon Mac with no extra setup — plus crisp Retina text, a native
Liquid Glass icon, an input fix, and the fixes needed to build cleanly on a current Apple-clang / CMake
toolchain. Gameplay, assets, and the rest of the project are unchanged from upstream — you still provide
your own *Super Mario 64* ROM.

> **Why it's pinned to a specific commit.** This fork tracks upstream **playtest commit `86364855`**
> (libultraship `7c6950e7`), not the very latest `develop`. A newer upstream libultraship commit
> (`11ad2a55`, pulled in by the "custom uniforms" change) **regressed the Metal renderer** — it crashes
> in the 3D draw path on Apple Silicon / macOS 26. `86364855` is the last commit whose Metal backend
> works (it's the same commit as the upstream prebuilt playtest build). Once upstream fixes Metal, this
> fork can move forward.

---

## Download & run

1. Grab `Ghostship-v2.1.0-macOS-arm64.zip` from
   [Releases](https://github.com/quarrel07/Ghostship-macOS/releases) and unzip it.
2. The app is **ad-hoc codesigned**, so on first launch right-click `Ghostship.app` → **Open**
   (or run `xattr -dr com.apple.quarantine Ghostship.app`) to get past Gatekeeper.
3. On first run the game asks for a supported **Super Mario 64 (US) ROM** (`.z64`). It extracts
   `sm64.o2r` into `~/Library/Application Support/com.ghostship/` — this can take a minute — then boots
   the game.

No copyrighted assets are bundled. You must supply your own legally-dumped ROM.

## What this fork changes

| # | Area | Fix |
|---|------|-----|
| 1 | **libultraship** `cmake/dependencies/mac.cmake` | A stale `/Library/Frameworks/SDL2.framework` can win `find_package(SDL2)` over Homebrew's and break configure. Search frameworks last and add the Homebrew prefix to `CMAKE_PREFIX_PATH`. |
| 2 | **Torch** `CMakeLists.txt` | The pinned spdlog bundles an `fmt` whose compile-time format-string check is gated on `consteval`, which Apple clang 21+ rejects. Neutralize it with a directory-level `-DFMT_CONSTEVAL=`. |
| 3 | **MbedTLS** `CMakeLists.txt` | Ghostship's net code (`PlayerIdentity.cpp`) and ixwebsocket both use MbedTLS. mbedtls **4.x dropped** the legacy `ctr_drbg`/`entropy` API they need, so the build requires **`mbedtls@3`** (keg-only); its prefix is added to `CMAKE_PREFIX_PATH` and it's explicitly linked into the app. |
| 4 | **Crisp Retina menu text** (`libultraship`, `Engine.cpp`) | The ImGui overlay was rasterized at logical point size and stretched to the Retina framebuffer → fuzzy menus. Detect the backing scale (`Gui::GetDpiScale`) and rasterize every font (`RasterizerDensity`) at `backingScale × maxUiScale`, so text stays sharp at every **ImGui scale** option. |
| 5 | **Press-and-hold accent popup** `src/port/Game.cpp` | Holding a movement key (WASD) popped up the macOS accent/diacritic picker (SDL keeps a Cocoa text-input context active). Disable the per-app `ApplePressAndHoldEnabled` default at startup — key repeat still works. |
| 6 | **Packaging** `cmake/macos/apple_bundle.cmake` | Build a self-contained `.app`: compile the Liquid Glass icon, bundle `ghostship.o2r` + the extractor `assets/` + the TCC scripting runtime (`.tcc`, **relocated from `Contents/MacOS/` to `Contents/Resources/`** so codesign accepts the bundle and the runtime finds it), relink Homebrew dylibs (incl. SDL3 + mbedtls) into `Contents/Frameworks`, copy `Info.plist`, ad-hoc codesign. Replaces the old `sips`/`iconutil` icon flow. |
| 7 | **Clean quit** `src/port/Engine.cpp` | Declining the first-run extractor prompt bailed via `exit()`, which ran a static `Context`/`spdlog` destructor and segfaulted. The pre-init bail-outs now use `_Exit()`. |
| 8 | **Metadata** `Info.plist`, **`SHIP_HOME` fallback** | `CFBundleIconName = GhostshipIcon`, HiDPI keys, version `2.1.0`; data folder at `~/Library/Application Support/com.ghostship` via `SHIP_HOME` (`LSEnvironment` + a `setenv` fallback in `main()` for the raw binary). |

## File layout at runtime

* **`Ghostship.app/Contents/Resources`** (read-only) — `ghostship.o2r` (port assets), `config.yml`,
  `assets/` (extractor definitions), `.tcc/` (TCC scripting runtime), `gamecontrollerdb.txt`, the
  compiled icon (`Assets.car`, `GhostshipIcon.icns`).
* **`~/Library/Application Support/com.ghostship/`** (writable) — `sm64.o2r` extracted from your ROM on
  first run, plus config, save data, logs, and the `mods/` folder.

## Building it yourself

```bash
brew install cmake ninja sdl2 sdl3 glew libpng libzip nlohmann-json tinyxml2 spdlog mbedtls@3
git clone --recurse-submodules https://github.com/quarrel07/Ghostship-macOS.git
cd Ghostship-macOS
cmake --no-warn-unused-cli -H. -Bbuild-cmake -GNinja -DCMAKE_BUILD_TYPE=Release
cmake --build build-cmake          # produces build-cmake/Ghostship.app
```

A fresh recursive clone builds turnkey — the submodule fixes live on forks that `.gitmodules` already
points at, so no manual patching is needed. **`mbedtls@3` is required** (the current `mbedtls` 4.x
formula dropped the API Ghostship's net code uses). `sdl3` is required because the bundled sdl2-compat
shim loads it. The Liquid Glass icon step needs **full Xcode 26+** installed (for `actool`). Pass
`-DGHOSTSHIP_BUNDLE_DEPS=OFF` to skip the dylib bundling for a local-only build.

## Submodule forks used

| Submodule | Fork / branch | Change |
|-----------|---------------|--------|
| `libultraship` | [`quarrel07/libultraship@ghostship-macos`](https://github.com/quarrel07/libultraship/tree/ghostship-macos) | SDL2 framework build fix (#1) + HiDPI font density (#4) |
| `Torch` | [`quarrel07/Torch@ghostship-macos`](https://github.com/quarrel07/Torch/tree/ghostship-macos) | fmt `consteval` fix (#2) |

Both forks branch from the exact commits this fork pins (libultraship `7c6950e7`, Torch `4e021e10`), so
it tracks upstream playtest `86364855` with only the macOS-specific deltas above.

## Credits

All credit for Ghostship goes to **[Lywx](https://github.com/kiritodv)** and the
**[HarbourMasters](https://github.com/HarbourMasters)** team, and to **[Kenix3](https://github.com/Kenix3)** /
the libultraship project. This fork only adds macOS build, packaging, and quality-of-life fixes.

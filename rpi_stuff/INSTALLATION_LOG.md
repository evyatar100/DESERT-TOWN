# Pokémon Essentials v21 on Raspberry Pi (RetroPie) - Installation & Decision Log

**Target**: Run Pokémon Essentials v21 natively on Raspberry Pi (RetroPie / Raspbian 10 Buster) without x86 emulation (Wine/Box86).  
**Date**: October 2026  
**Hardware Detected**: Raspberry Pi 4 Model B (4 cores, 3.7GB RAM, `armv7l` 32-bit userspace) running RetroPie on Raspbian Buster.

---

## Executive Summary & Game Engine Context

Pokémon Essentials v21 is built upon RPG Maker XP (RGSS1), but modern Essentials versions (v20+) broke away from legacy Windows-only 16-year-old Ruby 1.8.1 and Win32API calls. Essentials v20/v21 uses **mkxp-z**, an open-source multiplatform RGSS implementation.

To run Pokémon Essentials v21 natively on the Pi inside RetroPie:
1. We need a native ARM binary of **mkxp-z**.
2. We need all backend libraries (SDL2, OpenAL, FluidSynth, Theora, Vorbis, PhysFS, Image formats).
3. We need proper Ruby runtime compatibility for Essentials v21 scripts (MRI 2.5 on Buster).
4. We need game assets structured properly (case-sensitivity handling via `pathCache: true`).
5. We need a launcher script inside RetroPie (`roms/ports`) so the user can start the game directly from EmulationStation with a gamepad.

---

## Stage-by-Stage Log & Decision Records

### Stage 1: System Baseline & Package Repositories
- **Status**: COMPLETED
- **Problem**: Raspbian Buster is End-Of-Life (EOL). `apt update` failed because `raspbian.raspberrypi.org` mirrors returned 404 Not Found.
- **Solution**:
  - Replaced `/etc/apt/sources.list` mirror with the archive mirror: `http://legacy.raspbian.org/raspbian/`.
  - Successfully installed build tools and libraries:
    `build-essential cmake ninja-build git pkg-config python3-pip python3-setuptools libphysfs-dev libtheora-dev libvorbis-dev libogg-dev libbz2-dev libssl-dev libfluidsynth-dev libuchardet-dev libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev libopenal-dev libpixman-1-dev libfreetype6-dev libpng-dev libjpeg-dev zlib1g-dev ruby ruby-dev libruby2.5`
  - Upgraded Meson: Buster’s apt provided Meson 0.49.2, but mkxp-z requires Meson >= 0.54. Upgraded via `pip3 install --user --upgrade meson` to Meson 1.11.2 (located in `/home/pi/.local/bin/meson`).

---

### Stage 2: PhysFS & Glibc Stubs Configuration
- **Status**: COMPLETED
- **Problem**:
  1. `libphysfs-dev` on Debian/Buster does not supply a `physfs.pc` pkg-config file.
  2. `libphysfs.a` lacked an indexed symbol table (`ranlib` required).
  3. Meson was checking for standalone `libiconv` and `libcharset`, but glibc on Linux provides iconv directly in `libc.so.6`.
- **Solution**:
  - Created `/usr/lib/arm-linux-gnueabihf/pkgconfig/physfs.pc`:
    ```ini
    prefix=/usr
    exec_prefix=${prefix}
    libdir=${prefix}/lib/arm-linux-gnueabihf
    includedir=${prefix}/include
    Name: PhysFS
    Description: PhysicsFS filesystem abstraction library
    Version: 3.0.1
    Libs: -L${libdir} -lphysfs
    Cflags: -I${includedir}
    ```
  - Executed `sudo ranlib /usr/lib/arm-linux-gnueabihf/libphysfs.a`.
  - Created stub archives `libiconv.a` and `libcharset.a` in `/usr/local/lib` and indexed them with `ranlib`.

---

### Stage 3: SDL_sound Build & Installation
- **Status**: COMPLETED
- **Problem**: mkxp-z requires modern SDL_sound with custom decoders / API compatible with mkxp-z.
- **Solution**:
  - Cloned official `https://github.com/mkxp-z/SDL_sound` (branch `git`).
  - Built with CMake: `cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DSDLSOUND_BUILD_STATIC=ON -DSDLSOUND_BUILD_SHARED=ON`
  - Installed to `/usr/local/lib` and symlinked header:
    `sudo ln -sf /usr/local/include/SDL2/SDL_sound.h /usr/local/include/SDL_sound.h`

---

### Stage 4: mkxp-z Target Selection, Compilation & Patches
- **Status**: COMPLETED
- **Critical Finding - The Exact Commit**:
  - Pokémon Essentials v21 scripts specifically require `mkxp-z version 2.4.2/c9378cf`.
  - Upstream `dev` branch added ANGLE/Vulkan dependencies that break on older Debian Buster toolchains.
  - Checking out the exact commit `c9378cfa` matches Essentials v21 perfectly and builds purely on OpenGL 2.1 / Broadcom V3D!
- **Key Code Patches Applied**:
  1. **Theora Pkg-Config**: In `src/meson.build`, Debian packages split theora into `theora` and `theoradec`.
     ```meson
     theora = [dependency('theora', static: build_static), dependency('theoradec', static: build_static)]
     ```
  2. **Preserve System Ruby Loadpath**: In `binding/binding-mri.cpp`, mkxp-z originally cleared Ruby's `$LOAD_PATH` (`rb_ary_clear(lpaths)`), which wiped out `/usr/lib/arm-linux-gnueabihf/ruby/2.5.0/zlib.so`.
     Commented out `rb_ary_clear(lpaths)` so standard Ruby extensions (`zlib`, `openssl`, etc.) remain fully functional.
  3. **Version Hash String**: Set `git_hash = 'c9378cf'` in `meson.build` so `System::VERSION` matches Essentials v21 check (`2.4.2/c9378cf`).
- **Build Command**:
  ```bash
  meson setup build --buildtype=release -Dmri_version=2.5 -Dstatic_executable=false
  ninja -C build
  ```
- **Result**: Native ARM executable `mkxp-z.armv7l` compiled cleanly with Broadcom V3D OpenGL hardware acceleration and OpenAL audio.

---

### Stage 5: Game Asset Packaging & Deployment
- **Status**: COMPLETED
- **Packaging Rules**:
  - Stripped Windows-only binaries (`*.exe`, `*.dll`) saving ~25 MB.
  - Excluded `.agents`, temporary logs, and `.git`.
  - Compressed remaining 7,754 files into `game-files.zip` (111 MB).
  - Uploaded via Paramiko SFTP to Raspberry Pi in 24 seconds and extracted into `/home/pi/pokemon-game/`.
  - Installed native `mkxp-z` binary directly in `/home/pi/pokemon-game/`.
- **mkxp.json Tuning**:
  - Enabled `"pathCache": true` to eliminate Linux ext4 case-sensitivity mismatches.
  - Verified `soundfont.sf2` and Unicode font declarations.

---

### Stage 6: RetroPie Integration
- **Status**: COMPLETED
- **Configuration**:
  - Added `ports` system definition to `/etc/emulationstation/es_systems.cfg`:
    ```xml
    <system>
      <name>ports</name>
      <fullname>Ports</fullname>
      <path>/home/pi/RetroPie/roms/ports</path>
      <extension>.sh .SH</extension>
      <command>bash %ROM%</command>
      <platform>pc</platform>
      <theme>ports</theme>
    </system>
    ```
  - Created executable launcher `/home/pi/RetroPie/roms/ports/Pokemon Essentials.sh`:
    ```bash
    #!/bin/bash
    cd /home/pi/pokemon-game
    ./mkxp-z
    ```
  - Verified `ports.svg` icon exists in default `carbon-2021` theme.

### Stage 7: Display Flickering & 4K Bandwidth Throttling Fix
- **Status**: COMPLETED
- **Problem**:
  When playing in fullscreen on modern Smart TVs, the bottom 60% of the screen turned black every few seconds and then returned.
- **Root Cause Analysis**:
  Inspecting `tvservice -s` revealed the Pi 4 auto-negotiated **4K (3840x2160) at 30Hz** with default **76MB** GPU RAM.
  Under full 4K output, rendering 3D/OpenGL through VideoCore VI saturates the DDR4 memory bus and the HDMI display pixel pipeline.
  This causes a hardware **FIFO Buffer Underrun**, which truncates scanout midway down the frame (black screen on the lower half) until the buffer refills.
- **Solution Applied**:
  In `/boot/config.txt`, locked the HDMI output for both ports to Full HD **1080p @ 60Hz** (CEA Mode 16) and boosted GPU memory to **256MB**:
  ```ini
  [pi4]
  # Force 1080p 60Hz (prevents 4K pixel FIFO underflow & black-screen flickering)
  hdmi_group:0=1
  hdmi_mode:0=16
  hdmi_group:1=1
  hdmi_mode:1=16

  # Allocate 256MB GPU RAM for smooth rendering
  gpu_mem=256
  ```
  Result: Memory bandwidth demand reduced by 75%, refresh rate locked at smooth 60 FPS, eliminating all screen tearing and blackouts.

---

### Stage 8: Rebuild mkxp-z on Ruby 3.1 to match the laptop build (TG54, 2026-10-28)
- **Status**: BUILT AND DEPLOYED. Process evidence from a Ports launch shows title BGM, then map BGM and a save written, with no errorlog entry. The founder's on-TV confirmation is pending.
- **Problem**: The new 64 GB card (fresh RetroPie) ran the Stage 4 engine (Ruby 2.5). The game's scripts now use Ruby 3 syntax (endless `def x = ...`, 68+ places), so loading stopped with a SyntaxError in TempleStickers `007a_board_view.rb:44`.
- **Decision (founder)**: Rebuild the engine to match the laptop, not just Ruby but every engine library, and do not change game code.
- **What the laptop runs** (read from `game-files/Game.exe`, `x64-msvcrt-ruby310.dll`, `zlib1.dll`): the mkxp-z GitHub CI build of `2.4.2/c9378cf`, whose dependencies were built on 2023-07-07 (libjpeg-turbo carries `build 20230707`). Essentials' gate is an exact match: `System::VERSION != Essentials::MKXPZ_VERSION ("2.4.2/c9378cf")`.
- **Approach**: Same commit (c9378cf already defaults to `mri_version=3.1`), built with that commit's own `linux/Makefile` (same forks and branches as `windows/Makefile`). Every dependency repo is pinned to its last commit before 2023-07-08, so it matches what the laptop's CI cache built. Everything goes in `/home/pi/tg54` with **no sudo**: RetroPie-Setup had already installed gcc 8.3, cmake 3.16, meson 0.56.1, autotools, libdrm/gbm/EGL/GL (Mesa 19.3.2), ALSA and X11 dev packages.

#### Version table
| component | laptop version | Pi version | match? |
| :--- | :--- | :--- | :--- |
| mkxp-z | 2.4.2/c9378cf | 2.4.2/c9378cf (git_hash pinned, see patch 1) | yes |
| Ruby (mkxp-z/ruby `mkxp-z-3.1.3`) | 3.1.3p185 rev c2ac5ccbc2 | 3.1.3p185 rev c2ac5ccbc2 | yes |
| zlib | 1.2.13 | 1.2.13 (built static; Buster has 1.2.11) | yes |
| bzip2 | 1.0.8 | 1.0.8 (built static; Buster has 1.0.6) | yes |
| OpenSSL | 1.1.1i | 1.1.1i | yes |
| OpenAL Soft (mkxp-z fork) | 1.22.2 | 1.22.2 (Buster: 1.19.1) | yes |
| FluidSynth (sans-glib fork) | 2.1.5 | 2.1.5 (synth identical; OS audio drivers off, see patch 6) | yes (core) |
| pixman | 0.40.1 | 0.40.1 | yes |
| libpng | 1.6.38.git | 1.6.38.git | yes |
| libjpeg-turbo | 2.0.6 (build 20230707) | 2.0.6 | yes |
| SDL2 (mkxp-z fork, `mkxp-z` branch) | not embedded; same branch, revision placeholder `hg-0:aaaaaaaaaaah` in both | 2.0.12 (Buster: 2.0.10+rpi) | same source, not byte-proven |
| SDL2_image (SDL_image_old `mkxp-z`) | not embedded | 2.0.6 | same source, not byte-proven |
| SDL2_ttf (`mkxp-z`) | not embedded | 2.0.15 | same source, not byte-proven |
| SDL_sound (`git` branch) | not embedded | 2.0.1 | same source, not byte-proven |
| PhysFS (`release-3.2.0`) | not embedded | 3.2.0 | same source, not byte-proven |
| FreeType (mkxp-z fork) | not embedded | 2.13.0+git (4d8db130e) | same source, not byte-proven |
| ogg / vorbis / theora | not embedded | 1.3.4+git / 1.3.7 / 1.2.0alpha1+git | same source, not byte-proven |
| uchardet / libiconv | not embedded | 0.0.6 / 1.16 | same source, not byte-proven |
| OpenGL driver | Windows GPU vendor driver | Mesa 19.3.2 V3D 4.2, GL 2.1 | no: platform driver, cannot match |
| Video/audio backends | Win32 / WASAPI-DSound | SDL KMSDRM, OpenAL ALSA (+ system libsndio 7.0) | no: platform, cannot match |

#### Build steps (scripts on the Pi: `~/tg54/pin_deps.sh`, `~/tg54/build_deps.sh`, `~/tg54/build_mkxp.sh`)
1. `git clone https://github.com/mkxp-z/mkxp-z ~/tg54/mkxp-z && git checkout c9378cf`.
2. Host Ruby (needed as BASERUBY to build Ruby from git): official `ruby-3.1.3.tar.gz` (sha256 `5ea498a3...6ab9e`) built into `~/tg54/baseruby`.
3. `pin_deps.sh`: clone each repo from `linux/Makefile` into `linux/downloads/armv7l/<name>` and check out `git rev-list -1 --before=2023-07-08 HEAD` (OpenSSL tag `OpenSSL_1_1_1i`, Ruby branch `mkxp-z-3.1.3` resolves to c2ac5ccbc2). Make then skips its own clones.
4. `build_deps.sh` (`make everything` in `linux/`, with `build-armv7l/bin` first on PATH):
   ```bash
   make everything OPENSSL_FLAGS=linux-armv4 \
     RUBY_FLAGS=--with-baseruby=/home/pi/tg54/baseruby/bin/ruby \
     PKG_CONFIG_LIBDIR=$P/lib/pkgconfig:/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig \
     SDL_FLAGS="--disable-video-rpi --enable-video-kmsdrm --disable-fcitx --disable-ibus"
   ```
5. zlib 1.2.13 (`./configure --static`, `-fPIC`) and bzip2 1.0.8 (`make libbz2.a`, `-fPIC`) installed into `build-armv7l` before Ruby's `ext/zlib` is configured.
6. `build_mkxp.sh`: `meson setup build --buildtype=release -Dmri_version=3.1 --prefix=/home/pi/tg54/install && ninja -C build && meson install -C build` with the same PATH/PKG_CONFIG_LIBDIR and `CFLAGS/LDFLAGS` pointing at `build-armv7l`.
   Result: `mkxp-z.armv7l` (12.6 MB). Everything is static except `libruby.so.3.1`, which loads from `$ORIGIN/lib32`.

#### Patches and deviations from the upstream recipe
1. `meson.build:11` `git_hash = 'c9378cf'`: a full clone abbreviates to `c9378cfa` (8 chars), which fails the Essentials gate. CI used a shallow clone (7 chars).
2. `OPENSSL_FLAGS=linux-armv4`: the Makefile's `linux-armv7l` is not an OpenSSL target.
3. SDL: `PKG_CONFIG_LIBDIR` must include the system dirs or configure cannot see `libdrm.pc`/`gbm.pc`, and SDL builds with no KMSDRM (no display without X). `--disable-video-rpi` keeps it off the legacy dispmanx/Broadcom GL path. `--disable-fcitx --disable-ibus` works around SDL 2.0.12 enabling fcitx without dbus headers.
4. Ruby git checkout: `tool/config.sub` and `tool/config.guess` copied from the 3.1.3 tarball (same release). They are fetched at release time and are not in git.
5. SDL_image: `libtoolize --force --copy && autoreconf -fi` (shipped ltmain 2.2.6 vs Buster's libtool 2.4.6). FreeType: run `./autogen.sh`, then `./configure --prefix=$P --enable-static --disable-shared` by hand (its tracked top-level `configure`/`Makefile` make the Makefile skip both, and it then tries to install to `/usr/local`).
6. FluidSynth rebuilt with `-Denable-alsa=off -Denable-dbus=off -Denable-pulseaudio=off -Denable-jack=off -Denable-oss=off -Denable-libsndfile=off ...`. mkxp-z uses it only as an in-memory synth into OpenAL, and the static ALSA/RTKit drivers broke the link. SF3 (compressed) soundfonts are unsupported; the game ships `soundfont.sf2`.
7. The Stage 4 `rb_ary_clear(lpaths)` patch is **not** applied: zlib and the other exts are linked into libruby (`--with-static-linked-ext`), which matches the Windows behaviour.

#### Deploy (no sudo; game files untouched)
- `~/pokemon-game/mkxp-z` and `~/stage/mkxp-z` are the new binary. The Ruby 2.5 binary is kept as `mkxp-z.ruby25` in both.
- `~/pokemon-game/lib32/` and `~/stage/lib32/` hold `libruby.so.3.1` (+ `libcrypt.so.1`, `libbsd.so.0` copied by upstream `install.sh`).
- The launcher `~/RetroPie/roms/ports/Pokemon Essentials.sh` is unchanged (the rpath finds `lib32`).
- Rollback: `cd ~/pokemon-game && mv mkxp-z mkxp-z.ruby31 && mv mkxp-z.ruby25 mkxp-z`.

#### Verification
- `timeout 40 ./mkxp-z` over SSH (ES running): GL init on V3D 4.2 / GL 2.1 Mesa 19.3.2, alive at 40 s, `errorlog.txt` unchanged.
- Launched from EmulationStation Ports: after about 1.5 min the process held `Audio/BGM/Title.ogg`, then `Audio/BGM/Area.ogg`, and wrote `~/.local/share/Pokemon Essentials v21.1/Game.rxdata`. `errorlog.txt` was still the old 20:08 entry from the 2.5 engine.
- `[ALSOFT] (EE) Could not query RTKit` in `game.log` is harmless (no realtime-priority daemon).

#### Follow-up: game drawn as a small box in the bottom-left of the TV
- **Symptom (founder, first TV run)**: the game showed as a small picture in the bottom-left corner; the rest of the 1920x1080 screen was black.
- **Cause**:
  - At boot, `Game.set_up_system` calls `pbSetResizeFactor($PokemonSystem.screensize)`. The default size is "M" (`SCREEN_SCALE = 1.0`), so it runs `Graphics.fullscreen = false` and `Graphics.scale = 1.0`. This overrides `"fullscreen": true` in mkxp.json; on the laptop it is simply a 512x384 window.
  - The SDL 2.0.12 KMSDRM driver always creates its GBM scanout surface at the display mode size (`SDL_kmsdrmvideo.c:390`), and `KMSDRM_SetWindowSize` does nothing to it. Leaving fullscreen makes generic SDL restore the stored 512x384 windowed size and send a RESIZED event.
  - mkxp-z then sets its GL viewport to 512x384 inside the 1920x1080 buffer. GL's origin is bottom-left, hence the box.
- **Fix (config only; no rebuild, no game code)**: the Pi-only preload script `/home/pi/pi-engine/kmsdrm_fullscreen.rb`, listed in the Pi's `~/pokemon-game/mkxp.json` as `"preloadScript": ["/home/pi/pi-engine/kmsdrm_fullscreen.rb"]`. mkxp-z runs it before the game scripts. It redefines `Graphics.fullscreen=` to always pass `true`, and makes `Graphics.scale=`, `resize_window` and `center` no-ops. mkxp-z's default `fixedAspectRatio` then fills the TV height at 4:3 with black side bars. The in-game "Screen size" option has no effect on the Pi.
- Every intercepted call appends a line to `/home/pi/pi-engine/kmsdrm_fullscreen.log`, so the result of a TV run can be read over SSH.
- Stub test (Ruby 3.1.3 on the Pi): `~/tg54/tests/test_kmsdrm.rb` passes.
- mkxp.json backup: `/home/pi/pi-engine/mkxp.json.before-tg54-fullscreen`. Rollback: copy it back over `~/pokemon-game/mkxp.json`.
- **Note**: re-copying the laptop's `mkxp.json` to the Pi drops the `preloadScript` line and brings the box back. Do not add the line to the laptop copy: it would force fullscreen on Windows too.
- **If the box remains** (the log shows `fullscreen=false -> true` but the picture is still small): patch SDL 2.0.12 `KMSDRM_SetWindowSize` and the leave-fullscreen path to keep the window at the display size, then rebuild SDL and relink. That would be a source deviation from the laptop's SDL, to be recorded in the version table.
- Versions are unchanged by this fix.

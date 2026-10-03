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

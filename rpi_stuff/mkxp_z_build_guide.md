# Native mkxp-z (Pokémon Essentials v21) on Raspberry Pi

This document details the complete process, blockers encountered, and resolutions applied to successfully build and run **mkxp-z** natively on a Raspberry Pi running RetroPie (Raspbian GNU/Linux 10 Buster, `armv7l`).

---

## 1. Environment & Target Hardware

- **Hardware**: Raspberry Pi (ARMv8 64-bit SoC running 32-bit `armv7l` userspace).
- **Operating System**: RetroPie on Raspbian GNU/Linux 10 (Buster).
- **Kernel**: `Linux town 5.10.103-v7l+ #1529 SMP armv7l`.
- **Target Engine**: mkxp-z `v2.4.2` (Open-source RGSS implementation compatible with Pokémon Essentials).

---

## 2. Root Cause Analysis of Previous Blockers

| Blocker / Error | Root Cause | Resolution |
| :--- | :--- | :--- |
| `404 Not Found` during `apt update` | Raspbian Buster reached End-of-Life (EOL); official repos moved to archive mirrors. | Switched `/etc/apt/sources.list` to `http://legacy.raspbian.org/raspbian/`. |
| `Meson version is 0.56.1 but project requires >=1.4.0` | Buster's repo packages an outdated Meson version. | Installed modern Meson via `pip3 install --user --upgrade meson` into `~/.local/bin`. |
| `spirv-tools` CMake subproject compilation failed | Upstream `dev`/`master` branch introduced modern Vulkan/SPIR-V shader compilation toolchains incompatible with Buster's toolchain. | Switched to stable release tag `v2.4.2`. |
| `Dependency "physfs" not found` | Debian's `libphysfs-dev` does not ship `physfs.pc` for `pkg-config`. | Created `/usr/lib/arm-linux-gnueabihf/pkgconfig/physfs.pc`. |
| `C++ shared or static library 'SDL2_sound' not found` | `SDL2_sound` is not packaged in Buster's apt repos. | Cloned `https://github.com/mkxp-z/SDL_sound` (`git` branch), built with CMake, and installed to `/usr/local`. |
| `C++ shared or static library 'iconv' / 'charset' not found` | On glibc Linux, `iconv` is built directly into `libc.so.6`. Standalone `libiconv` is not provided. | Created empty stub archives `libiconv.a` and `libcharset.a` in `/usr/local/lib` so linker checks succeed while `libc` provides the functions. |
| `archive has no index; run ranlib to add one` on `libphysfs.a` | Missing symbol table index in static archive. | Executed `sudo ranlib /usr/lib/arm-linux-gnueabihf/libphysfs.a`. |
| Undefined references to `cairo_*`, `TIFF*`, `WebP*` | Meson defaulted `static_executable` to `true`, forcing static linking against system archives without all transitive dependencies. | Configured Meson with `-Dstatic_executable=false` to dynamically link shared libraries (`.so`). |
| Undefined references to `th_decode_*`, `th_info_*` | Debian packages the Theora decoder in a separate library (`libtheoradec.so`). | Added `theoradec` dependency alongside `theora` in `src/meson.build`. |

---

## 3. Step-by-Step Build Reproduction Guide

### Step 1: System Package Manager & Base Tools
Ensure `/etc/apt/sources.list` points to the legacy Buster archive:
```bash
deb http://legacy.raspbian.org/raspbian buster main contrib non-free rpi
```
Update apt and install essential build tools and libraries:
```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential cmake ninja-build git pkg-config \
  libphysfs-dev libtheora-dev libvorbis-dev libogg-dev \
  libbz2-dev libssl-dev libfluidsynth-dev libuchardet-dev \
  libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev \
  libopenal-dev libpixman-1-dev libfreetype6-dev \
  libpng-dev libjpeg-dev zlib1g-dev \
  ruby ruby-dev libruby2.5
```

### Step 2: Install Modern Meson
```bash
pip3 install --user --upgrade meson
export PATH="$HOME/.local/bin:$PATH"
```

### Step 3: Build & Install `SDL2_sound`
```bash
cd /tmp
rm -rf SDL_sound
git clone --depth 1 https://github.com/mkxp-z/SDL_sound -b git
cd SDL_sound
mkdir cmakebuild && cd cmakebuild
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DSDLSOUND_BUILD_SHARED=true \
  -DSDLSOUND_BUILD_STATIC=true \
  -DSDLSOUND_BUILD_TEST=false
make -j$(nproc)
sudo make install
sudo ldconfig
sudo ln -sf /usr/local/include/SDL2/SDL_sound.h /usr/local/include/SDL_sound.h
```

### Step 4: Configure `physfs.pc` & Libc Stubs
Create the missing pkg-config file for PhysFS:
```bash
sudo tee /usr/lib/arm-linux-gnueabihf/pkgconfig/physfs.pc > /dev/null << 'EOF'
prefix=/usr
exec_prefix=${prefix}
libdir=${prefix}/lib/arm-linux-gnueabihf
includedir=${prefix}/include

Name: PhysFS
Description: PhysicsFS is a library to provide abstract access to various archives.
Version: 3.0.1
Libs: -L${libdir} -lphysfs
Cflags: -I${includedir}
EOF

sudo ranlib /usr/lib/arm-linux-gnueabihf/libphysfs.a
```

Create iconv / charset linker stubs:
```bash
sudo ar cr /usr/local/lib/libiconv.a
sudo ar cr /usr/local/lib/libcharset.a
sudo ranlib /usr/local/lib/libiconv.a
sudo ranlib /usr/local/lib/libcharset.a
sudo ldconfig
```

### Step 5: Checkout mkxp-z `v2.4.2` & Patch `src/meson.build`
```bash
cd ~/mkxp-z
git checkout v2.4.2
git submodule update --init --recursive
```

In `src/meson.build`, ensure `theora` links both `theora` and `theoradec`:
```python
theora = [dependency('theora', static: build_static), dependency('theoradec', static: build_static)]
```

### Step 6: Configure & Compile
```bash
cd ~/mkxp-z
rm -rf build
meson setup build \
  --buildtype=release \
  -Dmri_version=2.5 \
  -Dstatic_executable=false
ninja -C build
```

Create standard executable alias:
```bash
ln -sf mkxp-z.armv7l build/mkxp-z
```

---

## 4. Verification

The compiled binary is located at:
- `/home/desert/mkxp-z/build/mkxp-z.armv7l` (symlinked as `/home/desert/mkxp-z/build/mkxp-z`)
- Format: ELF 32-bit LSB executable, ARM, EABI5 version 1 (GNU/Linux), dynamically linked.
- Size: ~2.5 MB.

### Testing Execution:
```bash
~/mkxp-z/build/mkxp-z -v
```
Expected output confirms engine initialization:
```text
RGSS version 1 (RPG Maker XP) 
ALC_SOFT_pause_device present 
Backend      : OpenGL 
GL Vendor    : VMware, Inc. 
GL Renderer  : llvmpipe (LLVM 9.0.1, 128 bits) 
GL Version   : 3.1 Mesa 19.3.2 
GLSL Version : 1.40 
...
Shutting down.
```

---

## 5. Running Pokémon Essentials Games

To run a Pokémon Essentials game using the compiled binary:

1. Copy the game files (containing `Data/`, `Audio/`, `Graphics/`, `Game.ini`) into a game directory on the Pi.
2. Copy `mkxp.json` into the game directory:
   ```bash
   cp ~/mkxp-z/mkxp.json /path/to/game/
   ```
3. Set your soundfont path in `mkxp.json`:
   ```json
   "soundFont": "/path/to/soundfont.sf2"
   ```
4. Launch the game:
   ```bash
   cd /path/to/game
   ~/mkxp-z/build/mkxp-z
   ```

# Local Lynx

This directory contains the Lynx 2.9.3 source archive and its extracted source
tree. The source is vendored so setup does not need to download Lynx again.

## Portable Windows binary

The `native` directory contains the extracted Win32 `lynx.exe`, PDCurses
runtime, OpenSSL 4 DLLs, and the Visual C++ runtime DLL it needs. Neovim uses
this copy automatically. It requires no installer, administrator rights,
registry changes, or system-wide `PATH` entry.

The included `lynx-newssl-setup.exe` is the upstream HTTPS-capable installer
artifact; it is not needed to run the portable copy.

## macOS and Linux

On macOS and Linux, Neovim checks candidate paths in the following order:
1. `Downloads/Lynx/native/lynx`
2. `Downloads/Lynx/lynx2.9.3/lynx`
3. `lynx` on system `PATH`

### Building with OpenSSL / SSL Support

Build into the local directory when a C compiler, ncurses, and OpenSSL are available:

```sh
cd Downloads/Lynx/lynx2.9.3
./configure --with-screen=ncurses --enable-gopher --enable-nested-tables --enable-default-colors --without-color-style --with-ssl
make
mkdir -p ../native
cp lynx ../native/lynx
```

### Building without OpenSSL / SSL Support

If OpenSSL development libraries are unavailable, Lynx can be built without SSL:

```sh
cd Downloads/Lynx/lynx2.9.3
./configure --with-screen=ncurses --enable-gopher --enable-nested-tables --enable-default-colors --without-color-style --without-ssl
make
mkdir -p ../native
cp lynx ../native/lynx
```

When Lynx is built without SSL support, the Neovim integration automatically detects this via `lynx -version` and transparently converts `https://` URLs to `http://` so browsing continues uninterrupted.

## Text-Only Browser and Supported Protocols

Lynx is configured as a clean, text-only browser. CSS styling has been removed to keep browsing simple and focused:
- **HTTP and HTTPS:** Native Lynx browsing, with HTTPS using the bundled SSL-capable build when available.
- **FTP:** Native Lynx FTP browsing.
- **Gopher Protocol (`gopher://`):** Native Gopher browsing support via `:LynxGopher`.
- **Text-Only Experience:** No CSS clutter, focusing on simple text navigation across supported protocols.

## Minimal UI & Shortcuts

The browser is configured for a minimal, keyboard-driven experience:
- `j` / `k` / `h` / `l` or arrow keys for navigation and following links
- `g` to open URL input prompt
- `1` - `9` + `Enter` to select numbered links directly
- `q` to close the browser window and return to Neovim

## Build Windows from source

The upstream source includes `makefile.msc`, `make-msc.bat`, and Visual Studio
project files under `BUILD`. Open a Visual Studio developer command prompt,
change to `Downloads\Lynx\lynx2.9.3`, and run:

```bat
call make-msc.bat
nmake -f makefile.msc
```

Copy the resulting `lynx.exe` to `Downloads\Lynx\native\lynx.exe`.
The build requires a curses-compatible library and OpenSSL development files;
the upstream `INSTALLATION` file documents the available configurations.

Lynx's source includes handlers for HTTP, HTTPS, FTP, Gopher, WAIS, and NNTP.

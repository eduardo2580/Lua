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
./configure --with-screen=ncurses --enable-gopher --enable-nested-tables --enable-default-colors --enable-color-style --with-ssl
make
mkdir -p ../native
cp lynx ../native/lynx
```

### Building without OpenSSL / SSL Support

If OpenSSL development libraries are unavailable, Lynx can be built without SSL:

```sh
cd Downloads/Lynx/lynx2.9.3
./configure --with-screen=ncurses --enable-gopher --enable-nested-tables --enable-default-colors --enable-color-style --without-ssl
make
mkdir -p ../native
cp lynx ../native/lynx
```

When Lynx is built without SSL support, the Neovim integration automatically detects this via `lynx -version` and transparently converts `https://` URLs to `http://` so browsing continues uninterrupted.

## Style Sheet & CSS Compatibility

Lynx uses style sheets (`.lss` files) for CSS element styling and color mapping. The Neovim integration passes `lynx.cfg` and `lynx-nvim.lss` (`-lss=...`) automatically, configuring formatting and colors for headings (h1-h6), links, tables, code blocks, form elements, status indicators, and source code syntax highlighting (`PRETTYSRC`).

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

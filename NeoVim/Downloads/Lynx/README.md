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

On macOS and Linux, Neovim first checks `Downloads/Lynx/native/lynx` and then
`lynx` on `PATH`. Build into the local directory without root access when a C
compiler, ncurses, and OpenSSL are already available:

```sh
cd Downloads/Lynx/lynx2.9.3
./configure --with-screen=ncurses --enable-gopher
make
cp lynx ../native/lynx
```

Alternatively, install the `lynx` package using the operating system's normal
package manager. The executable must have HTTP, HTTPS, FTP, Gopher, WAIS, and
NNTP support enabled by its build.

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
# Neovim Python and Java Setup

This configuration includes the Python workflow from the `python` branch of
the [Neovim Starter Kit](https://github.com/bcampolo/nvim-starter-kit): Pyright,
Treesitter, formatting, linting, debugging, and test integration.
It also includes Mason-managed `jdtls`, project-aware workspaces, Java
refactoring, compilation, and test commands.

## Prerequisites

- Neovim 0.9.1 or newer
- A true-color terminal and a Nerd Font
- Git and [ripgrep](https://github.com/BurntSushi/ripgrep)
- Node.js and npm
- Python 3.8 or newer
- Python provider: `python3 -m pip install pynvim` (use `python` on Windows)
- Tree-sitter CLI and a C compiler (`clang`, `gcc`, or MSVC)
- JDK 21 or newer for `eclipse.jdt.ls`

For Java, set `JAVA_HOME` to the JDK 21+ installation and ensure `java` is on
`PATH`. Open a Maven or Gradle project with `pom.xml`, `mvnw`, `build.gradle`,
or `gradlew` for full JDTLS support. Mason installs `jdtls` on first startup;
it can also be installed manually with `:Mason`.

On Linux, install `xclip`, `xsel`, or `wl-clipboard` for system clipboard
support. Windows and macOS use their native clipboard integrations.

Install w3m on your platform and put it on `PATH`. On Windows, the fallback
location is `C:\w3m.exe`. Use `:W3mGopher [host/path]` to open a Gopher
resource; running it without an argument opens
`gopher://gopher.floodgap.com:70/1`. Set `$BROWSER` to choose the command used
by `:W3mShowExtenalBrowser`; `open`, `xdg-open`, or the Windows URL handler is
selected automatically otherwise.

The first startup uses Mason to install the Python tools used by this config:
`black`, `debugpy`, `flake8`, `isort`, `mypy`, and `pylint`.

Run `:CheckPrerequisites` inside Neovim to check the external requirements.

## Java Keymaps

- `<leader>jo`: organize imports
- `<leader>jc`: compile incrementally
- `<leader>ju`: update Maven or Gradle project configuration
- `<leader>jv`: choose a configured Java runtime
- `<leader>jr`: extract variable
- `<leader>jm`: extract method
- `<leader>jt`: run the nearest Java test method
- `<leader>jf`: run the Java test class

The JDTLS commands `:JdtCompile`, `:JdtUpdateConfig`, `:JdtRestart`, and
`:JdtShowLogs` are available after a Java buffer attaches successfully.
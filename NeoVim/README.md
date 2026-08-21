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
- Python provider: `python -m pip install pynvim`
- JDK 21 or newer for `eclipse.jdt.ls`

For Java, set `JAVA_HOME` to the JDK 21+ installation and ensure `java` is on
`PATH`. Open a Maven or Gradle project with `pom.xml`, `mvnw`, `build.gradle`,
or `gradlew` for full JDTLS support. Mason installs `jdtls` on first startup;
it can also be installed manually with `:Mason`.

On Linux, install `xclip` or `xsel` for system clipboard support. Windows and
macOS use their native clipboard integrations.

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
# Cheer

[![CI](https://github.com/joshrotenberg/cheer/actions/workflows/ci.yml/badge.svg)](https://github.com/joshrotenberg/cheer/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/cheer.svg)](https://hex.pm/packages/cheer)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/cheer)
[![License](https://img.shields.io/hexpm/l/cheer.svg)](LICENSE)

A clap-inspired CLI framework for Elixir. Define your command tree once and
get parsing, validation, help, shell completion, a REPL, and in-process
testing for free.

## 30-second taste

```elixir
defmodule MyApp.CLI.Greet do
  use Cheer.Command

  command "greet" do
    about "Greet someone"

    argument :name, type: :string, required: true, help: "Who to greet"
    option :loud, type: :boolean, short: :l, help: "SHOUT"
  end

  @impl Cheer.Command
  def run(%{name: name} = args, _raw) do
    greeting = "Hello, #{name}!"
    if args[:loud], do: String.upcase(greeting), else: greeting
  end
end

Cheer.run(MyApp.CLI.Greet, ["world", "--loud"], prog: "greet")
# "HELLO, WORLD!"
```

## Features

- Declarative macro DSL for commands, options, arguments, and subcommands
- Typed options and arguments with automatic coercion
- Repeated (`:multi`), multi-value (`:num_args`), delimited (`:value_delimiter`),
  and hyphen-leading (`:allow_hyphen_values`) option values
- Custom value parsers (`:parse`) that transform input into domain types
- Per-param and cross-param validation, choices, conditional-required
- Per-option relations (`:conflicts_with`, `:requires`) and param groups
- Env var fallback, defaults (including `:default_missing_value`), boolean
  negation (`--no-*`)
- Deprecation markers (`deprecated`) for options, arguments, and subcommands
- Auto-generated help with headings, display order, before/after text, hidden
  items (`hide`), terminal-width wrapping, and color (respecting `NO_COLOR`)
- Prefix inference and `"Did you mean?"` suggestions for mistyped commands and
  flags
- Optional subcommands (`:args_conflicts_with_subcommands`) and external
  subcommands for git-style plugin dispatchers
- Escript and Mix task entry points (`Cheer.MixTask`)
- Shell completion for bash, zsh, fish, and PowerShell
- REPL mode driven by the same command tree
- In-process test runner with output capture
- Command tree introspection (`Cheer.tree/1`) and markdown reference generation
  (`Cheer.Reference`)
- Zero runtime dependencies

## Install

```elixir
def deps do
  [{:cheer, "~> 0.1"}]
end
```

## Documentation

Full docs on [hexdocs.pm/cheer](https://hexdocs.pm/cheer):

- **[Getting started](https://hexdocs.pm/cheer/getting_started.html)** -- install and a five-minute tour.
- **[Concepts](https://hexdocs.pm/cheer/concepts.html)** -- vocabulary and mental model.
- **Guides:**
  [Options](https://hexdocs.pm/cheer/options.html),
  [Arguments](https://hexdocs.pm/cheer/arguments.html),
  [Subcommands](https://hexdocs.pm/cheer/subcommands.html),
  [Validation](https://hexdocs.pm/cheer/validation.html),
  [Constraints](https://hexdocs.pm/cheer/constraints.html),
  [Help and output](https://hexdocs.pm/cheer/help_and_output.html),
  [Lifecycle hooks](https://hexdocs.pm/cheer/lifecycle_hooks.html),
  [Shell completion](https://hexdocs.pm/cheer/shell_completion.html),
  [REPL](https://hexdocs.pm/cheer/repl.html),
  [Testing](https://hexdocs.pm/cheer/testing.html).
- **Cookbook:**
  [Greeter](https://hexdocs.pm/cheer/greeter.html) (single command),
  [Devtool](https://hexdocs.pm/cheer/devtool.html) (nested subcommands with hooks and groups),
  [Mix task](https://hexdocs.pm/cheer/mix_task.html) (drive a `mix` task with a command).

## Runnable examples

Standalone Mix projects that match the cookbook entries live under
[`examples/`](examples/):

- [`examples/greeter/`](examples/greeter/) -- minimal single-command CLI.
- [`examples/devtool/`](examples/devtool/) -- nested multi-command CLI
  with lifecycle hooks and groups.
- [`examples/mix_task/`](examples/mix_task/) -- a Cheer command driving a
  `mix` task.

```sh
cd examples/greeter && mix deps.get
mix run -e 'Greeter.CLI.main(["world", "--loud", "--times", "3"])'
```

## License

MIT

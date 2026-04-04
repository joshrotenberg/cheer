# Cheer

[![CI](https://github.com/joshrotenberg/cheer/actions/workflows/ci.yml/badge.svg)](https://github.com/joshrotenberg/cheer/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/cheer.svg)](https://hex.pm/packages/cheer)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/cheer)
[![License](https://img.shields.io/hexpm/l/cheer.svg)](LICENSE)

A clap-inspired CLI framework for Elixir. Define your command tree once and get parsing, validation, help, shell completion, REPL mode, and testing for free.

## Features

- **Declarative DSL** -- define commands, options, arguments, and subcommands with macros
- **Arbitrary nesting** -- subcommand trees of any depth
- **Typed options and arguments** -- `:string`, `:integer`, `:float`, `:boolean` with automatic coercion
- **Validation** -- per-param (`:validate`, `:choices`), cross-param (`validate/1`), required fields
- **Environment variable fallback** -- `option :port, env: "MY_PORT"`
- **Param groups** -- mutually exclusive and co-occurring option groups
- **Lifecycle hooks** -- `before_run`, `after_run`, `persistent_before_run` (inherited by children)
- **Auto-generated help** -- includes defaults, env vars, choices, groups
- **Shell completion** -- bash, zsh, and fish script generation
- **REPL mode** -- interactive command shell from the same command tree
- **In-process test runner** -- `Cheer.Test.run/3` captures output and return values
- **Command tree introspection** -- `Cheer.tree/1` returns the tree as data
- **"Did you mean?"** -- typo suggestions via Jaro distance

## Quick Start

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

# Run it
Cheer.run(MyApp.CLI.Greet, ["world", "--loud"], prog: "greet")
```

## Validation

```elixir
# Per-param: inline function
option :port, type: :integer,
  validate: fn p -> if p in 1024..65535, do: :ok, else: {:error, "invalid port"} end

# Per-param: choices
option :format, type: :string, choices: ["json", "csv", "table"]

# Cross-param: runs after all params are parsed
validate fn args ->
  if args[:tls] && !args[:cert], do: {:error, "--tls requires --cert"}, else: :ok
end
```

## Environment Variable Fallback

```elixir
option :port, type: :integer, default: 4000, env: "PORT"
# Priority: CLI flag > env var > default
```

## Param Groups

```elixir
group :format, mutually_exclusive: true do
  option :json, type: :boolean
  option :csv, type: :boolean
end

group :auth, co_occurring: true do
  option :username, type: :string
  option :password, type: :string
end
```

## Lifecycle Hooks

```elixir
before_run fn args -> Map.put(args, :debug, true) end
after_run fn result -> log(result); result end

# Inherited by ALL child subcommands
persistent_before_run fn args -> Map.put(args, :logger, init_logger()) end
```

## Shell Completion

```elixir
Cheer.Completion.generate(MyApp.CLI.Root, :bash, prog: "my-app")
# Also :zsh and :fish
```

## REPL Mode

```elixir
Cheer.Repl.start(MyApp.CLI.Root, prog: "my-app")
# my-app> greet world
# my-app> exit
```

## Testing

```elixir
result = Cheer.Test.run(MyApp.CLI.Greet, ["world"])
assert result.return == "Hello, world!"
assert result.output == ""
```

## Introspection

```elixir
Cheer.tree(MyApp.CLI.Root)
# %{name: "my-app", subcommands: [%{name: "greet", ...}, ...]}
```

## Installation

```elixir
def deps do
  [{:cheer, "~> 0.1.0"}]
end
```

## License

MIT

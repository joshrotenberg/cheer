# Concepts

A short vocabulary tour. Read once, then skim the guides.

## Command

A module that `use Cheer.Command` and declares a `command "<name>" do ... end`
block. Commands compose into trees of arbitrary depth.

```elixir
defmodule MyApp.CLI.Deploy do
  use Cheer.Command

  command "deploy" do
    about "Deploy to an environment"
    # ... options, arguments, subcommands ...
  end

  @impl Cheer.Command
  def run(args, _raw), do: ...
end
```

Leaf commands (no subcommands) must implement `run/2`. Branch commands route
argv to their children automatically.

## Argument

A positional input. Matched by position, typed, optionally required.

```elixir
argument :name, type: :string, required: true, help: "Who to greet"
```

## Option

A flag. Long form (`--port`), optional short alias (`-p`), optional value,
optional type. Boolean options automatically support `--no-<name>` negation.

```elixir
option :port, type: :integer, short: :p, default: 4000, env: "PORT"
option :verbose, type: :boolean, short: :v
```

Cheer normalizes atom names to kebab-case in both the parser and help output,
so `:base_port` becomes `--base-port`.

## Subcommand

A nested command module registered under its parent:

```elixir
command "devtool" do
  subcommand Devtool.Server   # devtool server ...
  subcommand Devtool.Db       # devtool db ...
end
```

Subcommand trees can nest arbitrarily deep.

## Run

A leaf command's handler. Receives a parsed `args` map and the raw `argv`:

```elixir
@impl Cheer.Command
def run(args, _raw_argv) do
  # args is already parsed, typed, validated
end
```

The `args` map contains parsed arguments and options by their declared name,
plus any defaults and environment-variable fallbacks that applied. Unknown
trailing tokens (after `--`) land in `args[:rest]` unless the command
declares a named `trailing_var_arg`.

## Help, usage, version

Every command gets `-h` / `--help` automatically. Commands that call
`version("1.0.0")` also get `-V` / `--version`. Help output is derived from
the metadata you declared, not from a parallel format file.

## Metadata

Every command has a compile-time `__cheer_meta__/0` function that returns the
full declaration as a data structure. `Cheer.tree/1` walks the tree and
returns a nested map, useful for documentation, completion scripts, and
testing.

## Test runner

`Cheer.Test.run/3` invokes a command in-process, captures stdout, and returns
both the output and the handler's return value. No subprocess, no argv
escaping. See [Testing](guides/testing.md).

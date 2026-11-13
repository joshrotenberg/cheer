# Greeter: a single-command CLI

A minimal complete example. One command, one required argument, three options
(including a typed one with a validator and an env var fallback).

Full runnable project: [`examples/greeter/`](https://github.com/joshrotenberg/cheer/tree/main/examples/greeter).
The same command is also there as a single-file script,
[`greeter.exs`](https://github.com/joshrotenberg/cheer/blob/main/examples/greeter/greeter.exs);
see [Run it as a script](#run-it-as-a-script).

## The command

```elixir
defmodule Greeter.CLI do
  use Cheer.Command

  command "greeter" do
    about "Greet someone with style"
    version "1.0.0"

    argument :name, type: :string, required: true, help: "Who to greet"

    option :greeting, type: :string, default: "Hello", env: "GREETER_GREETING",
      help: "Greeting word"

    option :loud, type: :boolean, short: :l, help: "SHOUT the greeting"

    option :times, type: :integer, short: :n, default: 1,
      validate: fn n -> if n in 1..10, do: :ok, else: {:error, "times must be 1-10"} end,
      help: "Repeat the greeting"
  end

  @impl Cheer.Command
  def run(%{name: name} = args, _raw) do
    greeting = "#{args[:greeting]}, #{name}!"
    greeting = if args[:loud], do: String.upcase(greeting), else: greeting

    for _ <- 1..args[:times] do
      IO.puts(greeting)
    end

    :ok
  end

  def main(argv) do
    Cheer.run(__MODULE__, argv, prog: "greeter")
  end
end
```

## Run it

```sh
cd examples/greeter
mix deps.get

mix run -e 'Greeter.CLI.main(["world"])'
# Hello, world!

mix run -e 'Greeter.CLI.main(["world", "--loud", "--times", "3"])'
# HELLO, WORLD!
# HELLO, WORLD!
# HELLO, WORLD!

GREETER_GREETING=Hey mix run -e 'Greeter.CLI.main(["Ada"])'
# Hey, Ada!

mix run -e 'Greeter.CLI.main(["world", "--times", "42"])'
# error: times must be 1-10 (validator failure)

mix run -e 'Greeter.CLI.main(["--help"])'
# Usage: greeter <name> [OPTIONS]
# ...
```

Or build as a proper escript:

```sh
mix escript.build
./greeter world --loud --times 3
```

Option defaults are evaluated at compile time, so a default computed from the
build machine (a home directory, the current date) is fixed in the escript.
See [Defaults and env var fallback](../guides/options.md#defaults-and-env-var-fallback).

## Run it as a script

The command needs no Mix project. Put the module in one `.exs` file, declare
cheer with `Mix.install/2` above it, and call `Cheer.main/3` on the last line:

```elixir
#!/usr/bin/env elixir
Mix.install([
  {:cheer, "~> 0.3"}
])

defmodule Greeter.CLI do
  use Cheer.Command

  # The command block and run/2 from above, unchanged. main/1 is not needed.
end

Cheer.main(Greeter.CLI, System.argv(), prog: "greeter")
```

```sh
chmod +x greeter.exs

./greeter.exs world --loud --times 3
# HELLO, WORLD!
# HELLO, WORLD!
# HELLO, WORLD!

./greeter.exs --help
# Usage: greeter <name> [OPTIONS]
# ...
```

The first run fetches and compiles cheer; later runs reuse the `Mix.install`
cache. `Cheer.main/3` halts the VM with exit code 0, or 2 on a usage error.
[Script](script.md) covers the cache, formatting a lone script, and when a
script fits better than an escript.

## What it shows

- **Required positional** -- `argument :name, required: true` with the
  missing-arg error path.
- **Typed option with validator** -- `:times` is coerced to integer and
  range-checked.
- **Env var fallback** -- `GREETER_GREETING` is consulted when `--greeting`
  is not passed.
- **Short alias** -- `-l` for `--loud`, `-n` for `--times`.
- **Version flag** -- `version "1.0.0"` wires up `-V` / `--version`.
- **Auto help** -- `-h` / `--help` generated from the declaration.

## See also

- Guides: [Options](../guides/options.md), [Arguments](../guides/arguments.md),
  [Validation](../guides/validation.md).
- Next cookbook: [Devtool](devtool.md) -- multi-command nesting with
  lifecycle hooks and groups.
- Cookbook: [Script](script.md) -- a multi-command CLI with a second
  dependency, as a `Mix.install` script.

# Getting Started

Cheer is a clap-inspired CLI framework for Elixir. Define your command tree
once, get parsing, validation, help, shell completion, a REPL, and in-process
testing for free.

## Install

```elixir
def deps do
  [{:cheer, "~> 0.1"}]
end
```

No runtime dependencies.

## Five-minute tour

A single-command CLI with an argument, a typed option, and a validator:

```elixir
defmodule MyApp.CLI.Greet do
  use Cheer.Command

  command "greet" do
    about "Greet someone"

    argument :name, type: :string, required: true, help: "Who to greet"
    option :times, type: :integer, short: :n, default: 1,
      validate: fn n -> if n in 1..10, do: :ok, else: {:error, "must be 1-10"} end,
      help: "Repeat the greeting"
  end

  @impl Cheer.Command
  def run(%{name: name, times: times}, _raw) do
    for _ <- 1..times, do: IO.puts("Hello, #{name}!")
  end
end

Cheer.run(MyApp.CLI.Greet, ["world", "--times", "3"], prog: "greet")
# Hello, world!
# Hello, world!
# Hello, world!
```

`Cheer.run/3` takes your root command module, argv, and an optional `prog`
name used in usage lines. A missing required argument, a bad integer, or
`--times 42` would each produce a clear error and exit without running the
handler.

## Going further

The guides are organized by feature; read them in any order.

- [Concepts](concepts.md) -- vocabulary and mental model.
- **Building blocks:**
  [Options](guides/options.md),
  [Arguments](guides/arguments.md),
  [Subcommands](guides/subcommands.md).
- **Validation and relationships:**
  [Validation](guides/validation.md),
  [Constraints](guides/constraints.md).
- **Polish:**
  [Help and output](guides/help_and_output.md),
  [Lifecycle hooks](guides/lifecycle_hooks.md).
- **Ecosystem:**
  [Shell completion](guides/shell_completion.md),
  [REPL mode](guides/repl.md),
  [Testing](guides/testing.md).

For full worked examples you can run locally, see the
[cookbook](cookbook/greeter.md) and the matching projects under `examples/`.

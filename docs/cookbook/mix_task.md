# Mix task: drive `mix` commands with Cheer

Cheer is not only for escripts. The same command definition can power a Mix
task, so `mix greet world --loud` parses, validates, and renders help exactly
like a standalone CLI. No framework changes are needed.

Full runnable project: [`examples/mix_task/`](https://github.com/joshrotenberg/cheer/tree/main/examples/mix_task).

## The key idea

A Mix task is a module named `Mix.Tasks.<Name>` that does `use Mix.Task` and
implements `run/1`, receiving the raw argv list. A Cheer command does
`use Cheer.Command` and implements `run/2`, receiving parsed args. These do not
collide: `run/1` and `run/2` have different arities, so one module can be both.

The Mix entry point (`run/1`) delegates to `Cheer.run/3`, which does the
parsing, validation, and help rendering and then calls your `run/2`.

## The task

```elixir
defmodule Mix.Tasks.Greet do
  @shortdoc "Greet someone with style"

  @moduledoc """
  #{@shortdoc}

  ## Examples

      mix greet world
      mix greet world --loud --times 3
      GREET_GREETING=Hey mix greet Ada
      mix greet --help
  """

  use Mix.Task
  use Cheer.Command

  command "greet" do
    about "Greet someone with style"

    argument :name, type: :string, required: true, help: "Who to greet"

    option :greeting, type: :string, default: "Hello", env: "GREET_GREETING",
      help: "Greeting word"

    option :loud, type: :boolean, short: :l, help: "SHOUT the greeting"

    option :times, type: :integer, short: :n, default: 1,
      validate: fn n -> if n in 1..10, do: :ok, else: {:error, "times must be 1-10"} end,
      help: "Repeat the greeting"
  end

  # Mix entry point. Delegate to Cheer, then translate a usage failure into the
  # Mix exit idiom.
  @impl Mix.Task
  def run(argv) do
    case Cheer.run(__MODULE__, argv, prog: "mix greet") do
      {:error, :usage} -> exit({:shutdown, 2})
      other -> other
    end
  end

  # Cheer leaf handler. Runs once argv has parsed and validated cleanly.
  @impl Cheer.Command
  def run(%{name: name} = args, _raw) do
    greeting = "#{args[:greeting]}, #{name}!"
    greeting = if args[:loud], do: String.upcase(greeting), else: greeting

    for _ <- 1..args[:times] do
      IO.puts(greeting)
    end

    :ok
  end
end
```

## Run it

```sh
cd examples/mix_task
mix deps.get

mix greet world
# Hello, world!

mix greet world --loud --times 3
# HELLO, WORLD!
# HELLO, WORLD!
# HELLO, WORLD!

GREET_GREETING=Hey mix greet Ada
# Hey, Ada!

mix greet --help
# Usage: mix greet <name> [OPTIONS]
# ...

mix greet
# error: missing required argument(s): <name>
# ... (exits 2)
```

`mix help` and `mix help greet` render from `@shortdoc` and `@moduledoc`, the
standard Mix mechanism, so the task lists and documents itself like any other.

## Signaling failure

Return `{:error, :usage}` from a usage failure into a nonzero exit code with
`exit({:shutdown, 2})`. That is the Mix idiom: Mix catches this exit and halts
with the given code without a crash report.

Do **not** use `Cheer.main/3` inside a Mix task. `main/3` calls `System.halt`,
which hard-kills the VM immediately: it skips Mix's own cleanup and is wrong
inside `mix`, CI, and umbrella projects. `Cheer.run/3` exists as the separate
primitive precisely so callers can decide how to exit. `main/3` is for escript
entry points, where halting the VM is the whole point.

## Starting the application

Mix does not start your application before running a task. If the task needs the
app running (a repo, a supervision tree, config), start it inside `run/2`:

```elixir
@impl Cheer.Command
def run(args, _raw) do
  Mix.Task.run("app.start")
  # ... now the app is running
end
```

`Application.ensure_all_started/1` works too when you only need a specific
application.

## What it shows

- **One module, two behaviours** -- `use Mix.Task` and `use Cheer.Command`
  coexist because `run/1` and `run/2` do not collide.
- **`prog: "mix greet"`** -- so the usage line reads as the Mix invocation, not
  a bare command name.
- **Exit codes** -- `exit({:shutdown, 2})` translates a Cheer usage failure into
  a conventional nonzero exit.
- **Mix help integration** -- `@shortdoc` / `@moduledoc` drive `mix help`.
- **The `main/3` caveat** -- never `System.halt` from inside a Mix task.

## See also

- Cookbook: [Greeter](greeter.md) -- the same command as a standalone escript.
- Guides: [Options](../guides/options.md), [Arguments](../guides/arguments.md),
  [Validation](../guides/validation.md).

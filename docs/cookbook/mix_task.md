# Mix task: drive `mix` commands with Cheer

Cheer is not only for escripts. The same command definition can power a Mix
task, so `mix greet world --loud` parses, validates, and renders help exactly
like a standalone CLI. No framework changes are needed.

Full runnable project: [`examples/mix_task/`](https://github.com/joshrotenberg/cheer/tree/main/examples/mix_task).

## The task

`use Cheer.MixTask` combines `use Mix.Task` and `use Cheer.Command` and generates
the Mix `run/1` entry point. Declare the command and implement the leaf `run/2`:

```elixir
defmodule Mix.Tasks.Greet do
  use Cheer.MixTask

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

  @impl Cheer.Command
  def run(%{name: name} = args, _raw) do
    greeting = "#{args[:greeting]}, #{name}!"
    greeting = if args[:loud], do: String.upcase(greeting), else: greeting

    for _ <- 1..args[:times] do
      Mix.shell().info(greeting)
    end

    :ok
  end
end
```

Then `mix greet world --loud` parses, validates, and renders help exactly like a
standalone CLI.

## What the helper generates

`use Cheer.MixTask` gives you:

- a `run/1` Mix entry point that dispatches argv through the command with
  `Cheer.run/3`, using `mix greet` as the program name in help and usage output;
- a `{:error, :usage}` to `exit({:shutdown, 2})` translation, the Mix idiom for a
  nonzero exit;
- `@shortdoc` defaulted to the command's `about` text, so `mix help` lists the task.

If you prefer to wire it by hand (or need to override `run/1` for setup), the
manual equivalent is a plain module that does `use Mix.Task` and `use Cheer.Command`
(they coexist because `run/1` and `run/2` have different arities) with a `run/1`
that delegates:

```elixir
@impl Mix.Task
def run(argv) do
  case Cheer.run(__MODULE__, argv, prog: "mix greet") do
    {:error, :usage} -> exit({:shutdown, 2})
    other -> other
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

The helper translates a `{:error, :usage}` result into `exit({:shutdown, 2})`,
the Mix idiom: Mix catches this exit and halts with the given code without a
crash report.

Do **not** use `Cheer.main/3` inside a Mix task. `main/3` calls `System.halt`,
which hard-kills the VM immediately: it skips Mix's own cleanup and is wrong
inside `mix`, CI, and umbrella projects. The helper uses `Cheer.run/3` for
exactly this reason. `main/3` is for escript entry points, where halting the VM
is the whole point.

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
application. If you would rather start the app before argv is even parsed,
override the generated `run/1` and call `Cheer.run/3` yourself.

## What it shows

- **`use Cheer.MixTask`** -- one line that makes a Cheer command a Mix task,
  generating the `run/1` entry point.
- **`mix greet` program name** -- the usage line reads as the Mix invocation, not
  a bare command name.
- **Exit codes** -- a usage failure becomes `exit({:shutdown, 2})`, a conventional
  nonzero exit.
- **Mix help integration** -- `@shortdoc` defaults to the command's `about`.
- **The `main/3` caveat** -- never `System.halt` from inside a Mix task.

## See also

- Cookbook: [Greeter](greeter.md) -- the same command as a standalone escript.
- Guides: [Options](../guides/options.md), [Arguments](../guides/arguments.md),
  [Validation](../guides/validation.md).

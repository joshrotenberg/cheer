defmodule Cheer do
  @moduledoc """
  A [clap](https://crates.io/crates/clap)-inspired CLI argument parsing framework for Elixir.

  Provides declarative command definitions with arbitrarily nested subcommands,
  typed options, automatic help generation, and shell completion.

  ## Usage

      defmodule MyApp.CLI.Greet do
        use Cheer.Command

        command "greet" do
          about "Greet someone"

          argument :name, type: :string, required: true, help: "Name to greet"
          option :loud, type: :boolean, short: :l, help: "Shout the greeting"
        end

        @impl Cheer.Command
        def run(%{name: name} = args, _opts) do
          greeting = "Hello, \#{name}!"
          if args[:loud], do: String.upcase(greeting), else: greeting
        end
      end

  ## Architecture

  Commands are modules that `use Cheer.Command`. Each command declares its name,
  about text, arguments, options, and subcommands via macros. At compile time,
  Cheer builds a command tree that handles:

  - Argv routing through nested subcommands
  - Option parsing via OptionParser
  - Type validation and coercion
  - Help text generation
  - Shell completion script generation (bash, zsh, fish)
  """

  @doc """
  Parse argv and dispatch to the appropriate command handler.

  Options:
    * `:prog` - program name for usage lines (default: derived from root command name)

  ## Return value

    * On success, returns whatever the matched command's `run/2` returns.
    * On a usage failure (unknown option, missing required argument, bad choice,
      unknown or ambiguous subcommand, missing required subcommand), prints the
      error and returns `{:error, :usage}`.
    * For `--help` / `--version` (and a bare command that just prints help),
      returns `:ok`.

  Use the `{:error, :usage}` result to set a nonzero exit code, or call
  `main/3` to have Cheer halt with a conventional code for you.

  Pass `Cheer.argv/0` rather than `System.argv/0` if the app also ships as a
  Burrito binary. Use `parse/3` instead if argv configures a process that keeps
  running rather than driving a unit of work.
  """
  @spec run(module(), [String.t()], keyword()) :: term() | {:error, :usage}
  def run(root_command, argv, opts \\ []) do
    prog = Keyword.get(opts, :prog)
    Cheer.Router.dispatch(root_command, argv, prog: prog)
  end

  @doc """
  Parse argv and return the matched command without invoking its handler.

  Everything `run/3` does up to the point of dispatch: subcommand resolution,
  option parsing, defaults, env fallback, validation, and help output. The
  matched command's `run/2` is not called.

  Options:
    * `:prog` - program name for usage lines (default: derived from root command name)

  ## Return value

    * `{:ok, command_module, args}` on a successful parse. `args` is the map
      `run/2` would have received.
    * `:handled` when Cheer printed help or a version and there is nothing left
      to run.
    * `{:error, :usage}` on a parse failure, error already printed.

  `:handled` is distinct from `:ok` on purpose: a caller can tell "Cheer printed
  help" from a handler that legitimately returned `:ok`.

  Use this where argv configures something rather than driving a unit of work,
  such as an `Application.start/2` that turns options into a supervision tree:

      def start(_type, _args) do
        case Cheer.parse(MyApp.CLI.Root, Cheer.argv(), prog: "myapp") do
          {:ok, MyApp.CLI.Serve, args} ->
            Supervisor.start_link(children(args), strategy: :one_for_one, name: MyApp.Supervisor)

          :handled ->
            System.halt(0)

          {:error, :usage} ->
            System.halt(2)
        end
      end

  `before_run` and `persistent_before_run` hooks still run, since they shape the
  args. `after_run` hooks do not: nothing ran, so there is no result to pass
  them.
  """
  @spec parse(module(), [String.t()], keyword()) ::
          {:ok, module(), map()} | :handled | {:error, :usage}
  def parse(root_command, argv, opts \\ []) do
    prog = Keyword.get(opts, :prog)
    Cheer.Router.dispatch(root_command, argv, prog: prog, mode: :parse)
  end

  @doc """
  Run as an entry point with argv from `argv/0`, halting the VM.

  Equivalent to `main(root_command, Cheer.argv(), [])`. Use this where the
  runtime hands you no argv of its own, such as an `Application.start/2` in a
  Burrito binary that exits when the command returns.
  """
  @dialyzer {:nowarn_function, [main: 1]}
  @spec main(module()) :: no_return()
  def main(root_command), do: main(root_command, argv(), [])

  @doc """
  Run as an escript entry point, halting the VM with a conventional exit code.

  Dispatches `argv` like `run/3`, then halts the VM: `0` on success (including
  `--help` and `--version`) and `2` on a usage failure. The command's own
  `run/2` return value does not affect the exit code; a command that wants
  custom codes should call `run/3` and halt itself, mapping the results it does
  not special-case with `exit_code/1`.

      def main(argv), do: Cheer.main(MyApp.CLI, argv, prog: "myapp")

  An escript is handed its argv, so pass it straight through. A Burrito binary
  is not: use `main/1`, or pass `argv/0` explicitly to set `:prog`.

      Cheer.main(MyApp.CLI, Cheer.argv(), prog: "myapp")
  """
  # main/2 and main/3 always System.halt, so they never return locally. That is
  # the intended behaviour for an escript entry point, not a defect.
  @dialyzer {:nowarn_function, [main: 2, main: 3]}
  @spec main(module(), [String.t()], keyword()) :: no_return()
  def main(root_command, argv, opts \\ []) do
    root_command
    |> run(argv, opts)
    |> exit_code()
    |> System.halt()
  end

  @doc """
  Map a `run/3` or `parse/3` result to a conventional process exit code.

  Returns `2` for `{:error, :usage}` and `0` for anything else, which is the
  mapping `main/3` applies. Call it directly when a command wants exit codes of
  its own and so has to halt itself, rather than restating the convention:

      case Cheer.run(MyApp.CLI, argv, prog: "myapp") do
        {:error, :not_found} -> System.halt(4)
        other -> System.halt(exit_code(other))
      end

  Pure, unlike `main/3`, which halts.
  """
  @spec exit_code(term()) :: 0 | 2
  def exit_code({:error, :usage}), do: 2
  def exit_code(_), do: 0

  @doc """
  Returns the command-line arguments, accounting for Burrito binaries.

  A [Burrito](https://github.com/burrito-elixir/burrito)-wrapped binary does not
  populate `System.argv/0`; its arguments arrive through
  `Burrito.Util.Args.argv/0`. This returns whichever one is correct for the
  current runtime, so a single entry point works under `mix run`, an escript,
  and a Burrito binary.

      Cheer.main(MyApp.CLI, Cheer.argv(), prog: "myapp")

  The check is `Burrito.Util.running_standalone?/0`, not merely whether Burrito
  is loaded, so `mix test` and `iex -S mix` in a project that ships via Burrito
  still see their own argv.

  Burrito is resolved at runtime rather than referenced at compile time, so
  Cheer takes no dependency on it and this compiles clean in projects that do
  not use it.
  """
  @spec argv() :: [String.t()]
  def argv do
    util = Module.concat(["Burrito", "Util"])

    if Code.ensure_loaded?(util) and function_exported?(util, :running_standalone?, 0) and
         util.running_standalone?() do
      Module.concat(["Burrito", "Util", "Args"]).argv()
    else
      System.argv()
    end
  end

  @doc """
  Returns the command tree as a nested data structure.

  Useful for documentation generation, introspection, and testing.
  """
  @spec tree(module()) :: map()
  def tree(command) do
    meta = command.__cheer_meta__()

    %{
      name: meta.name,
      about: meta.about,
      arguments: Enum.reject(meta.arguments, &hidden?/1),
      options: Enum.reject(meta.options, &hidden?/1),
      trailing_var_arg: Map.get(meta, :trailing_var_arg),
      groups: Map.get(meta, :groups, %{}),
      subcommands:
        meta.subcommands
        |> Enum.reject(fn sub -> Map.get(sub.__cheer_meta__(), :hide, false) end)
        |> Enum.map(&tree/1)
    }
  end

  defp hidden?({_name, opts}), do: Keyword.get(opts, :hide, false)
end

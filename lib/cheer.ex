defmodule Cheer do
  @moduledoc """
  A clap-inspired CLI argument parsing framework for Elixir.

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
  """
  @spec run(module(), [String.t()], keyword()) :: term() | {:error, :usage}
  def run(root_command, argv, opts \\ []) do
    prog = Keyword.get(opts, :prog)
    Cheer.Router.dispatch(root_command, argv, prog: prog)
  end

  @doc """
  Run as an escript entry point, halting the VM with a conventional exit code.

  Dispatches `argv` like `run/3`, then halts the VM: `0` on success (including
  `--help` and `--version`) and `2` on a usage failure. The command's own
  `run/2` return value does not affect the exit code; a command that wants
  custom codes should call `run/3` and halt itself.

      def main(argv), do: Cheer.main(MyApp.CLI, argv, prog: "myapp")
  """
  # main/2 and main/3 always System.halt, so they never return locally. That is
  # the intended behaviour for an escript entry point, not a defect.
  @dialyzer {:nowarn_function, [main: 2, main: 3]}
  @spec main(module(), [String.t()], keyword()) :: no_return()
  def main(root_command, argv, opts \\ []) do
    case run(root_command, argv, opts) do
      {:error, :usage} -> System.halt(2)
      _ -> System.halt(0)
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
      arguments:
        meta.arguments
        |> Enum.reject(fn {_name, opts} -> Keyword.get(opts, :hide, false) end)
        |> Enum.map(fn {name, opts} -> {name, opts} end),
      options:
        meta.options
        |> Enum.reject(fn {_name, opts} -> Keyword.get(opts, :hide, false) end)
        |> Enum.map(fn {name, opts} -> {name, opts} end),
      groups: Map.get(meta, :groups, %{}),
      trailing_var_arg: Map.get(meta, :trailing_var_arg),
      subcommands:
        meta.subcommands
        |> Enum.reject(fn sub -> Map.get(sub.__cheer_meta__(), :hide, false) end)
        |> Enum.map(&tree/1)
    }
  end
end

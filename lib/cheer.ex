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
  """
  @spec run(module(), [String.t()], keyword()) :: term()
  def run(root_command, argv, opts \\ []) do
    prog = Keyword.get(opts, :prog)
    Cheer.Router.dispatch(root_command, argv, prog: prog)
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
      arguments: Enum.map(meta.arguments, fn {name, opts} -> {name, opts} end),
      options: Enum.map(meta.options, fn {name, opts} -> {name, opts} end),
      groups: Map.get(meta, :groups, %{}),
      subcommands: Enum.map(meta.subcommands, &tree/1)
    }
  end
end

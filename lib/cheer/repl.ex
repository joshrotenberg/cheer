defmodule Cheer.Repl do
  @moduledoc """
  Interactive REPL mode for a command tree.

  Presents a prompt and dispatches typed commands through the command tree.
  Supports command history, help, and tab-like introspection.

  ## Usage

      Cheer.Repl.start(MyApp.CLI.Root, prog: "my-app")
  """

  @doc """
  Start an interactive REPL for the command tree.

  Options:
    * `:prog` - program name for the prompt (default: root command name)
    * `:banner` - banner text to print on start (default: auto-generated)
  """
  @spec start(module(), keyword()) :: :ok
  def start(root, opts \\ []) do
    meta = root.__cheer_meta__()
    prog = Keyword.get(opts, :prog, meta.name)
    banner = Keyword.get(opts, :banner, default_banner(meta, prog))

    IO.puts(banner)
    loop(root, prog, opts)
  end

  defp loop(root, prog, opts) do
    prompt = "#{prog}> "

    case IO.gets(prompt) do
      :eof ->
        IO.puts("Bye!")
        :ok

      {:error, _} ->
        IO.puts("Bye!")
        :ok

      input ->
        input = String.trim(input)

        cond do
          input == "" ->
            loop(root, prog, opts)

          input in ["exit", "quit"] ->
            IO.puts("Bye!")
            :ok

          input == "help" or input == "?" ->
            Cheer.Help.print(root, prog: prog)
            loop(root, prog, opts)

          input == "commands" ->
            print_commands(root)
            loop(root, prog, opts)

          true ->
            argv = tokenize(input)
            Cheer.run(root, argv, prog: prog)
            loop(root, prog, opts)
        end
    end
  end

  defp print_commands(root) do
    tree = Cheer.tree(root)
    do_print_commands(tree, 0)
  end

  defp do_print_commands(tree, indent) do
    prefix = String.duplicate("  ", indent)

    if indent > 0 do
      IO.puts("#{prefix}#{tree.name}")
    end

    for sub <- tree.subcommands do
      do_print_commands(sub, indent + 1)
    end
  end

  defp default_banner(_meta, prog) do
    """

    #{prog} interactive shell
    Type 'help' for available commands, 'exit' to quit.
    """
  end

  defp tokenize(input) do
    ~r/"([^"]*)"|\S+/
    |> Regex.scan(input)
    |> Enum.map(fn
      [_, quoted] -> quoted
      [word] -> word
    end)
  end
end

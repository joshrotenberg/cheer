defmodule Cheer.Help do
  @moduledoc """
  Auto-generates help text from command metadata.
  """

  @doc """
  Print formatted help for a command to stdout.

  Options:
    * `:prog` - program name for usage line (default: command name)
  """
  @spec print(module(), keyword()) :: :ok
  def print(command, opts \\ []) do
    meta = command.__cheer_meta__()
    prog = Keyword.get(opts, :prog) || meta.name

    IO.puts("")
    IO.puts(format_usage(meta, prog))
    IO.puts("")

    if meta.about != "" do
      IO.puts(meta.about)
      IO.puts("")
    end

    if meta.subcommands != [] do
      IO.puts("COMMANDS:")

      for sub <- meta.subcommands do
        sub_meta = sub.__cheer_meta__()
        IO.puts("  #{String.pad_trailing(sub_meta.name, 20)} #{sub_meta.about}")
      end

      IO.puts("")
    end

    if meta.arguments != [] do
      IO.puts("ARGUMENTS:")

      for {name, arg_opts} <- meta.arguments do
        help = Keyword.get(arg_opts, :help, "")
        required = if Keyword.get(arg_opts, :required, false), do: " (required)", else: ""
        IO.puts("  #{String.pad_trailing("<#{name}>", 20)} #{help}#{required}")
      end

      IO.puts("")
    end

    if meta.options != [] do
      IO.puts("OPTIONS:")

      for {name, opt_opts} <- meta.options do
        short =
          if Keyword.has_key?(opt_opts, :short),
            do: "-#{Keyword.get(opt_opts, :short)}, ",
            else: "    "

        help = Keyword.get(opt_opts, :help, "")

        suffixes =
          []
          |> maybe_append(Keyword.get(opt_opts, :choices), fn choices ->
            "[choices: #{Enum.join(choices, ", ")}]"
          end)
          |> maybe_append(Keyword.get(opt_opts, :default), fn default ->
            "[default: #{default}]"
          end)
          |> maybe_append(Keyword.get(opt_opts, :env), fn env ->
            "[env: #{env}]"
          end)

        suffix = if suffixes != [], do: " " <> Enum.join(suffixes, " "), else: ""

        IO.puts("  #{short}--#{String.pad_trailing(to_string(name), 16)} #{help}#{suffix}")
      end

      IO.puts("")
    end

    groups = Map.get(meta, :groups, %{})

    if map_size(groups) > 0 do
      for {group_name, %{opts: group_opts, members: members}} <- groups do
        constraint =
          cond do
            Keyword.get(group_opts, :mutually_exclusive, false) -> "mutually exclusive"
            Keyword.get(group_opts, :co_occurring, false) -> "must be used together"
            true -> ""
          end

        IO.puts("  [#{group_name}] (#{constraint}): #{Enum.map_join(members, ", ", &"--#{&1}")}")
      end

      IO.puts("")
    end

    IO.puts("  -h, --help              Print help")

    if meta[:version] do
      IO.puts("  -V, --version           Print version")
    end

    :ok
  end

  defp maybe_append(list, nil, _fun), do: list
  defp maybe_append(list, value, fun), do: list ++ [fun.(value)]

  defp format_usage(meta, prog) do
    parts = ["Usage: #{prog}"]

    parts =
      if meta.subcommands != [] do
        parts ++ ["<COMMAND>"]
      else
        parts
      end

    parts =
      parts ++
        Enum.map(meta.arguments, fn {name, arg_opts} ->
          if Keyword.get(arg_opts, :required, false), do: "<#{name}>", else: "[#{name}]"
        end)

    parts = if meta.options != [], do: parts ++ ["[OPTIONS]"], else: parts

    Enum.join(parts, " ")
  end
end

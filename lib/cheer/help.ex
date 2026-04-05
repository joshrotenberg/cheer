defmodule Cheer.Help do
  @moduledoc """
  Auto-generates help text from command metadata.

  Renders a formatted help page to stdout including usage line, description,
  subcommands, arguments, options (with defaults, env vars, choices), param
  groups, and built-in flags (`--help`, `--version`).

  Supports short help (`-h`) and long help (`--help`) modes. When long help
  is available (via `long_about` or `long_help`), `--help` displays the
  extended version while `-h` displays the short version.
  """

  @doc """
  Print formatted help for a command to stdout.

  Options:
    * `:prog` - program name for usage line (default: command name)
    * `:long` - `true` to print long help (default: `false`)
  """
  @spec print(module(), keyword()) :: :ok
  def print(command, opts \\ []) do
    meta = command.__cheer_meta__()
    prog = Keyword.get(opts, :prog) || meta.name
    long = Keyword.get(opts, :long, false)

    if meta[:before_help] do
      IO.puts(meta.before_help)
      IO.puts("")
    end

    IO.puts("")
    IO.puts(format_usage(meta, prog))
    IO.puts("")

    about_text = if long, do: meta[:long_about] || meta.about, else: meta.about

    if about_text && about_text != "" do
      IO.puts(about_text)
      IO.puts("")
    end

    visible_subcommands =
      Enum.reject(meta.subcommands, fn sub ->
        sub_meta = sub.__cheer_meta__()
        Map.get(sub_meta, :hide, false)
      end)

    if visible_subcommands != [] do
      IO.puts("COMMANDS:")

      for sub <- visible_subcommands do
        sub_meta = sub.__cheer_meta__()
        cmd_aliases = Map.get(sub_meta, :aliases, [])
        alias_str = if cmd_aliases != [], do: " (#{Enum.join(cmd_aliases, ", ")})", else: ""
        IO.puts("  #{String.pad_trailing(sub_meta.name <> alias_str, 20)} #{sub_meta.about}")
      end

      IO.puts("")
    end

    visible_arguments =
      Enum.reject(meta.arguments, fn {_name, arg_opts} ->
        Keyword.get(arg_opts, :hide, false)
      end)

    if visible_arguments != [] do
      IO.puts("ARGUMENTS:")

      for {name, arg_opts} <- visible_arguments do
        display_name = Keyword.get(arg_opts, :value_name, Atom.to_string(name))
        help = pick_help(arg_opts, long)
        required = if Keyword.get(arg_opts, :required, false), do: " (required)", else: ""
        IO.puts("  #{String.pad_trailing("<#{display_name}>", 20)} #{help}#{required}")
      end

      IO.puts("")
    end

    # Merge inherited global options from parents
    parent_globals = Keyword.get(opts, :parent_globals, [])

    inherited_globals =
      Enum.reject(parent_globals, fn {name, _} ->
        Enum.any?(meta.options, fn {n, _} -> n == name end)
      end)

    all_options = meta.options ++ inherited_globals

    visible_options =
      Enum.reject(all_options, fn {_name, opt_opts} ->
        Keyword.get(opt_opts, :hide, false)
      end)

    if visible_options != [] do
      IO.puts("OPTIONS:")

      for {name, opt_opts} <- visible_options do
        short =
          if Keyword.has_key?(opt_opts, :short),
            do: "-#{Keyword.get(opt_opts, :short)}, ",
            else: "    "

        help = pick_help(opt_opts, long)

        type = Keyword.get(opt_opts, :type, :string)

        flag_name =
          if type == :boolean, do: "[no-]#{name}", else: to_string(name)

        value_suffix =
          case Keyword.get(opt_opts, :value_name) do
            nil -> ""
            vn -> " <#{vn}>"
          end

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

        suffixes =
          if type == :count, do: suffixes ++ ["(repeatable)"], else: suffixes

        suffixes =
          if Keyword.get(opt_opts, :multi, false),
            do: suffixes ++ ["(multiple)"],
            else: suffixes

        suffixes =
          if Keyword.get(opt_opts, :global, false),
            do: suffixes ++ ["(global)"],
            else: suffixes

        suffix = if suffixes != [], do: " " <> Enum.join(suffixes, " "), else: ""

        IO.puts(
          "  #{short}--#{String.pad_trailing(flag_name <> value_suffix, 16)} #{help}#{suffix}"
        )
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

    if meta[:after_help] do
      IO.puts("")
      IO.puts(meta.after_help)
    end

    :ok
  end

  defp pick_help(opts, true),
    do: Keyword.get(opts, :long_help) || Keyword.get(opts, :help, "")

  defp pick_help(opts, false),
    do: Keyword.get(opts, :help, "")

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

    visible_arguments =
      Enum.reject(meta.arguments, fn {_name, arg_opts} ->
        Keyword.get(arg_opts, :hide, false)
      end)

    parts =
      parts ++
        Enum.map(visible_arguments, fn {name, arg_opts} ->
          display_name = Keyword.get(arg_opts, :value_name, Atom.to_string(name))

          if Keyword.get(arg_opts, :required, false),
            do: "<#{display_name}>",
            else: "[#{display_name}]"
        end)

    parts = if meta.options != [], do: parts ++ ["[OPTIONS]"], else: parts
    parts = if meta.subcommands == [], do: parts ++ ["[-- <args>...]"], else: parts

    Enum.join(parts, " ")
  end
end

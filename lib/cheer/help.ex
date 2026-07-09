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

    if meta[:usage] do
      IO.puts("Usage: #{meta.usage}")
    else
      IO.puts(format_usage(meta, prog))
    end

    IO.puts("")

    about_text = if long, do: meta[:long_about] || meta.about, else: meta.about

    if about_text && about_text != "" do
      IO.puts(about_text)
      IO.puts("")
    end

    visible_subcommands =
      meta.subcommands
      |> Enum.reject(fn sub ->
        sub_meta = sub.__cheer_meta__()
        Map.get(sub_meta, :hide, false)
      end)
      |> sort_subcommands()

    if visible_subcommands != [] do
      IO.puts("COMMANDS:")

      for sub <- visible_subcommands do
        sub_meta = sub.__cheer_meta__()
        cmd_aliases = Map.get(sub_meta, :aliases, [])
        alias_str = if cmd_aliases != [], do: " (#{Enum.join(cmd_aliases, ", ")})", else: ""
        dep = Enum.join(deprecated_label(Map.get(sub_meta, :deprecated)), "")
        dep = if dep != "", do: " " <> dep, else: ""

        IO.puts(
          "  #{String.pad_trailing(sub_meta.name <> alias_str, 20)} #{sub_meta.about}#{dep}"
        )
      end

      IO.puts("")
    end

    visible_arguments =
      meta.arguments
      |> Enum.reject(fn {_name, arg_opts} ->
        Keyword.get(arg_opts, :hide, false)
      end)
      |> sort_by_display_order()

    has_trailing = meta[:trailing_var_arg] != nil

    if visible_arguments != [] or has_trailing do
      IO.puts("ARGUMENTS:")

      for {name, arg_opts} <- visible_arguments do
        display_name = Keyword.get(arg_opts, :value_name, Atom.to_string(name))
        help = pick_help(arg_opts, long)
        required = if Keyword.get(arg_opts, :required, false), do: " (required)", else: ""
        deprecated = Enum.join(deprecated_label(Keyword.get(arg_opts, :deprecated)), "")
        deprecated = if deprecated != "", do: " " <> deprecated, else: ""

        IO.puts(
          wrap_line(
            "  #{String.pad_trailing("<#{display_name}>", 20)} ",
            "#{help}#{required}#{deprecated}"
          )
        )
      end

      if has_trailing do
        {tva_name, tva_opts} = meta.trailing_var_arg
        tva_help = Keyword.get(tva_opts, :help, "")

        tva_required =
          if Keyword.get(tva_opts, :required, false), do: " (required)", else: ""

        IO.puts("  #{String.pad_trailing("<#{tva_name}>...", 20)} #{tva_help}#{tva_required}")
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
      {default_section, headed_sections} = group_options_by_heading(visible_options)

      if default_section != [] do
        IO.puts("OPTIONS:")
        for opt <- default_section, do: IO.puts(format_option(opt, long))
        IO.puts("")
      end

      for {heading, opts_in_heading} <- headed_sections do
        IO.puts("#{String.upcase(heading)}:")
        for opt <- opts_in_heading, do: IO.puts(format_option(opt, long))
        IO.puts("")
      end
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

        IO.puts(
          "  [#{group_name}] (#{constraint}): " <>
            Enum.map_join(members, ", ", &"--#{flag_from(&1)}")
        )
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

  # Terminal width for wrapping, or `:no_wrap` when output is not a tty (piped,
  # captured in tests, CI). When not a tty, help renders on single lines exactly
  # as before, so wrapping never changes non-interactive output.
  defp terminal_width do
    case :io.columns() do
      {:ok, cols} when cols > 0 -> cols
      _ -> :no_wrap
    end
  end

  # Place `desc` after `prefix`, wrapping to the terminal width with continuation
  # lines hanging-indented under the description column.
  defp wrap_line(prefix, desc) do
    width = terminal_width()
    indent = String.length(prefix)
    avail = if width == :no_wrap, do: 0, else: width - indent

    if width == :no_wrap or avail < 12 or String.length(prefix) + String.length(desc) <= width do
      prefix <> desc
    else
      prefix <> wrap_text(desc, avail, indent)
    end
  end

  @doc false
  # Wrap `text` to `width` columns, joining lines with a newline + `indent`
  # spaces. The first line carries no leading indent (it follows a prefix).
  def wrap_text(text, width, indent) do
    {lines, current} =
      text
      |> String.split(" ", trim: true)
      |> Enum.reduce({[], ""}, fn word, {lines, current} ->
        candidate = if current == "", do: word, else: current <> " " <> word

        if String.length(candidate) > width and current != "" do
          {[current | lines], word}
        else
          {lines, candidate}
        end
      end)

    [current | lines]
    |> Enum.reverse()
    |> Enum.join("\n" <> String.duplicate(" ", indent))
  end

  # `:deprecated` is `true` for a bare marker or a string for a reason.
  defp deprecated_label(nil), do: []
  defp deprecated_label(false), do: []
  defp deprecated_label(true), do: ["(deprecated)"]
  defp deprecated_label(msg) when is_binary(msg), do: ["(deprecated: #{msg})"]

  # Render a default for the "[default: ...]" suffix. Most defaults are strings
  # or numbers; a value with no String.Chars implementation (a map) or a
  # non-charlist list would otherwise raise while printing help, so fall back to
  # inspect/1.
  defp default_to_string(default) do
    to_string(default)
  rescue
    _ -> inspect(default)
  end

  defp sort_by_display_order(items) do
    items
    |> Enum.with_index()
    |> Enum.sort_by(fn {{_name, opts}, idx} ->
      {Keyword.get(opts, :display_order) || 1_000_000, idx}
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp sort_subcommands(subs) do
    subs
    |> Enum.with_index()
    |> Enum.sort_by(fn {sub, idx} ->
      order = Map.get(sub.__cheer_meta__(), :display_order) || 1_000_000
      {order, idx}
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp group_options_by_heading(options) do
    {defaults, headed} =
      Enum.split_with(options, fn {_, opts} -> is_nil(Keyword.get(opts, :help_heading)) end)

    sorted_defaults = sort_by_display_order(defaults)

    # Preserve first-appearance order of headings, then sort within each.
    {heading_order, grouped} =
      Enum.reduce(headed, {[], %{}}, fn {_, opts} = item, {order, acc} ->
        heading = Keyword.get(opts, :help_heading)
        new_order = if heading in order, do: order, else: order ++ [heading]
        new_acc = Map.update(acc, heading, [item], fn existing -> existing ++ [item] end)
        {new_order, new_acc}
      end)

    headed_sections =
      Enum.map(heading_order, fn heading ->
        {heading, sort_by_display_order(grouped[heading])}
      end)

    {sorted_defaults, headed_sections}
  end

  defp format_option({name, opt_opts}, long) do
    short =
      if Keyword.has_key?(opt_opts, :short),
        do: "-#{Keyword.get(opt_opts, :short)}, ",
        else: "    "

    help = pick_help(opt_opts, long)
    type = Keyword.get(opt_opts, :type, :string)

    base_flag =
      if type == :boolean,
        do: "[no-]#{flag_from(name)}",
        else: flag_from(name)

    opt_aliases = Keyword.get(opt_opts, :aliases, [])

    flag_name =
      if opt_aliases != [] do
        alias_str = Enum.map_join(opt_aliases, ", ", &"--#{flag_from(&1)}")
        "#{base_flag} (#{alias_str})"
      else
        base_flag
      end

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
        "[default: #{default_to_string(default)}]"
      end)
      |> maybe_append(Keyword.get(opt_opts, :env), fn env ->
        "[env: #{env}]"
      end)

    suffixes = if type == :count, do: suffixes ++ ["(repeatable)"], else: suffixes

    suffixes =
      if Keyword.get(opt_opts, :multi, false),
        do: suffixes ++ ["(multiple)"],
        else: suffixes

    suffixes =
      if Keyword.get(opt_opts, :global, false),
        do: suffixes ++ ["(global)"],
        else: suffixes

    suffixes =
      case Keyword.get(opt_opts, :num_args) do
        nil -> suffixes
        spec -> suffixes ++ [num_args_label(spec)]
      end

    suffixes = suffixes ++ deprecated_label(Keyword.get(opt_opts, :deprecated))

    suffix = if suffixes != [], do: " " <> Enum.join(suffixes, " "), else: ""

    wrap_line(
      "  #{short}--#{String.pad_trailing(flag_name <> value_suffix, 16)} ",
      "#{help}#{suffix}"
    )
  end

  # Render an option name as the long flag the parser accepts.
  # `OptionParser` converts atoms to kebab-case (`:base_port` -> `--base-port`);
  # help output has to match, otherwise users type what `--help` shows and
  # get "unknown option".
  defp flag_from(name) when is_atom(name), do: name |> Atom.to_string() |> flag_from()
  defp flag_from(name) when is_binary(name), do: String.replace(name, "_", "-")

  defp num_args_label(n) when is_integer(n), do: "(#{n} values)"
  defp num_args_label(%Range{first: first, last: last}), do: "(#{first}..#{last} values)"

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

    parts =
      case meta[:trailing_var_arg] do
        {tva_name, tva_opts} when meta.subcommands == [] ->
          label =
            if Keyword.get(tva_opts, :required, false),
              do: "<#{tva_name}>...",
              else: "[#{tva_name}]..."

          parts ++ [label]

        _ ->
          parts
      end

    Enum.join(parts, " ")
  end
end

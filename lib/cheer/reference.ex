defmodule Cheer.Reference do
  @moduledoc """
  Generate a reference document for a command tree, suitable for a docs site or a
  repository reference page. Derives everything from `Cheer.tree/1`, so hidden
  options, arguments, and subcommands are omitted.

  ## Usage

      iex> Cheer.Reference.generate(MyApp.CLI, :markdown, prog: "myapp")

  Currently supports the `:markdown` format.
  """

  @doc """
  Render a reference document for the command tree rooted at `root`.

  Options:
    * `:prog` - program name for the top-level heading (default: root command name)
  """
  @spec generate(module(), :markdown, keyword()) :: String.t()
  def generate(root, format \\ :markdown, opts \\ [])

  def generate(root, :markdown, opts) do
    tree = Cheer.tree(root)
    prog = Keyword.get(opts, :prog, tree.name)

    tree
    |> render_command(prog, 1)
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  # -- Command --

  defp render_command(tree, path, level) do
    [
      "#{String.duplicate("#", level)} #{path}",
      paragraph(tree.about),
      usage_section(tree, path),
      arguments_section(tree),
      options_section(tree),
      subcommands_section(tree, path, level)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp usage_section(tree, path) do
    opts = if tree.options == [], do: "", else: " [OPTIONS]"

    args =
      tree.arguments
      |> Enum.map(fn {name, o} ->
        label = "<#{value_name(name, o)}>"
        if Keyword.get(o, :required, false), do: " #{label}", else: " [#{label}]"
      end)
      |> Enum.join()

    trailing =
      case tree.trailing_var_arg do
        {name, _} -> " [<#{name}>...]"
        _ -> ""
      end

    "```\n#{path}#{opts}#{args}#{trailing}\n```"
  end

  defp arguments_section(%{arguments: [], trailing_var_arg: nil}), do: ""

  defp arguments_section(tree) do
    bullets =
      Enum.map(tree.arguments, fn {name, o} ->
        "- `<#{value_name(name, o)}>`" <> help_and_meta(o, argument_meta(o))
      end)

    trailing =
      case tree.trailing_var_arg do
        {name, o} -> ["- `<#{name}>...`" <> help_and_meta(o, [])]
        _ -> []
      end

    "**Arguments**\n\n" <> Enum.join(bullets ++ trailing, "\n")
  end

  defp options_section(%{options: []}), do: ""

  defp options_section(tree) do
    bullets = Enum.map(tree.options, fn opt -> "- " <> option_flags(opt) <> option_tail(opt) end)
    "**Options**\n\n" <> Enum.join(bullets, "\n")
  end

  defp subcommands_section(%{subcommands: []}, _path, _level), do: ""

  defp subcommands_section(tree, path, level) do
    tree.subcommands
    |> Enum.map(fn sub -> render_command(sub, "#{path} #{sub.name}", level + 1) end)
    |> Enum.join("\n\n")
  end

  # -- Options / arguments --

  defp option_flags({name, o}) do
    flags =
      ["`--#{kebab(name)}`"] ++
        short(o) ++
        Enum.map(Keyword.get(o, :aliases, []), &"`--#{kebab(&1)}`")

    value = if takes_value?(o), do: " `<#{value_name(name, o)}>`", else: ""
    Enum.join(flags, ", ") <> value
  end

  defp option_tail({_name, o}), do: help_and_meta(o, option_meta(o))

  defp short(o) do
    case Keyword.get(o, :short) do
      nil -> []
      s -> ["`-#{s}`"]
    end
  end

  defp takes_value?(o) do
    Keyword.get(o, :type, :string) not in [:boolean, :count]
  end

  defp option_meta(o) do
    []
    |> put(Keyword.get(o, :default), fn d -> "default: #{inspect_value(d)}" end)
    |> put(Keyword.get(o, :choices), fn c -> "choices: #{Enum.join(c, ", ")}" end)
    |> put(Keyword.get(o, :env), fn e -> "env: #{e}" end)
    |> flag(Keyword.get(o, :required, false), "required")
    |> flag(deprecated?(o), "deprecated")
  end

  defp argument_meta(o) do
    []
    |> flag(Keyword.get(o, :required, false), "required")
    |> flag(deprecated?(o), "deprecated")
  end

  defp help_and_meta(o, meta) do
    help = Keyword.get(o, :help, "")
    help_str = if help != "", do: " -- #{help}", else: ""
    meta_str = if meta == [], do: "", else: " (" <> Enum.join(meta, ", ") <> ")"
    help_str <> meta_str
  end

  defp paragraph(""), do: ""
  defp paragraph(nil), do: ""
  defp paragraph(text), do: text

  defp value_name(name, o), do: Keyword.get(o, :value_name, kebab(name))
  defp kebab(name), do: name |> Atom.to_string() |> String.replace("_", "-")
  defp deprecated?(o), do: Keyword.get(o, :deprecated, false) not in [nil, false]

  defp put(list, nil, _fun), do: list
  defp put(list, value, fun), do: list ++ [fun.(value)]
  defp flag(list, false, _label), do: list
  defp flag(list, nil, _label), do: list
  defp flag(list, _truthy, label), do: list ++ [label]

  defp inspect_value(v) when is_binary(v), do: v
  defp inspect_value(v), do: inspect(v)
end

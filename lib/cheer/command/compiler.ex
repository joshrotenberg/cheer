defmodule Cheer.Command.Compiler do
  @moduledoc """
  Compile-time hook that materializes command metadata from module attributes
  and validates command definitions.
  """

  defmacro __before_compile__(env) do
    name = Module.get_attribute(env.module, :cheer_command_name) || ""
    about = Module.get_attribute(env.module, :cheer_about) || ""
    long_about = Module.get_attribute(env.module, :cheer_long_about)
    version = Module.get_attribute(env.module, :cheer_version)
    before_help = Module.get_attribute(env.module, :cheer_before_help)
    after_help = Module.get_attribute(env.module, :cheer_after_help)
    aliases = Module.get_attribute(env.module, :cheer_aliases) || []
    usage = Module.get_attribute(env.module, :cheer_usage)
    hide = Module.get_attribute(env.module, :cheer_hide) || false
    deprecated = Module.get_attribute(env.module, :cheer_deprecated) || false
    subcommand_required = Module.get_attribute(env.module, :cheer_subcommand_required) || false
    propagate_version = Module.get_attribute(env.module, :cheer_propagate_version) || false
    infer_subcommands = Module.get_attribute(env.module, :cheer_infer_subcommands) || false

    external_subcommands =
      Module.get_attribute(env.module, :cheer_external_subcommands) || false

    args_conflicts_with_subcommands =
      Module.get_attribute(env.module, :cheer_args_conflicts_with_subcommands) || false

    display_order = Module.get_attribute(env.module, :cheer_display_order)
    trailing_var_arg = Module.get_attribute(env.module, :cheer_trailing_var_arg)
    arguments = Module.get_attribute(env.module, :cheer_arguments) |> Enum.reverse()
    options = Module.get_attribute(env.module, :cheer_options) |> Enum.reverse()
    subcommands = Module.get_attribute(env.module, :cheer_subcommands) |> Enum.reverse()
    has_validate = Module.get_attribute(env.module, :cheer_has_validate)
    has_parse = Module.get_attribute(env.module, :cheer_has_parse)
    # Hook counters are incremented at macro-expansion time (see
    # Cheer.Command.DSL.next_hook_index/2). A command that declares no hooks of a
    # kind never writes the attribute, so default nil to 0.
    validator_count = Module.get_attribute(env.module, :cheer_validator_count) || 0
    before_run_count = Module.get_attribute(env.module, :cheer_before_run_count) || 0
    after_run_count = Module.get_attribute(env.module, :cheer_after_run_count) || 0

    persistent_before_count =
      Module.get_attribute(env.module, :cheer_persistent_before_run_count) || 0

    raw_groups = Module.get_attribute(env.module, :cheer_groups) |> Enum.reverse()

    # Validate: leaf commands (no subcommands) must define run/2
    if subcommands == [] do
      unless Module.defines?(env.module, {:run, 2}) do
        IO.warn(
          "#{inspect(env.module)} is a leaf command (no subcommands) but does not implement run/2",
          Macro.Env.stacktrace(env)
        )
      end
    end

    # Validate: version/1 called with an empty string is almost always a
    # mistake -- a common footgun is `version(Application.spec(:my_app,
    # :vsn) |> to_string())`, which evaluates at compile time before the
    # .app file exists and collapses to `""`. Use `Mix.Project.config()
    # [:version]` instead, which is always available while compiling.
    if version == "" do
      IO.warn(
        "#{inspect(env.module)} called `version(\"\")`. Empty version string " <>
          "is almost always unintended. If you meant to read the version " <>
          "from mix.exs, try `Mix.Project.config()[:version]`.",
        Macro.Env.stacktrace(env)
      )
    end

    # Build groups map: %{group_name => %{opts: [...], members: [...]}}
    groups = build_groups(raw_groups)

    # Merge the generated :validate / :parse accessor fns back into the param opts.
    options_expr = merge_accessors(options, has_validate, has_parse)
    arguments_expr = merge_accessors(arguments, has_validate, has_parse)

    validators_expr = make_indexed_fns(:__cheer_cross_validate__, validator_count)
    before_run_expr = make_indexed_fns(:__cheer_before_run__, before_run_count)
    after_run_expr = make_indexed_fns(:__cheer_after_run__, after_run_count)

    persistent_before_expr =
      make_indexed_fns(:__cheer_persistent_before_run__, persistent_before_count)

    quote do
      def __cheer_meta__ do
        %{
          name: unquote(name),
          about: unquote(about),
          long_about: unquote(long_about),
          version: unquote(version),
          before_help: unquote(before_help),
          after_help: unquote(after_help),
          aliases: unquote(aliases),
          usage: unquote(usage),
          hide: unquote(hide),
          deprecated: unquote(deprecated),
          subcommand_required: unquote(subcommand_required),
          propagate_version: unquote(propagate_version),
          infer_subcommands: unquote(infer_subcommands),
          external_subcommands: unquote(external_subcommands),
          args_conflicts_with_subcommands: unquote(args_conflicts_with_subcommands),
          display_order: unquote(display_order),
          trailing_var_arg: unquote(Macro.escape(trailing_var_arg)),
          arguments: unquote(arguments_expr),
          options: unquote(options_expr),
          subcommands: unquote(subcommands),
          validators: unquote(validators_expr),
          before_run: unquote(before_run_expr),
          after_run: unquote(after_run_expr),
          persistent_before_run: unquote(persistent_before_expr),
          groups: unquote(Macro.escape(groups))
        }
      end
    end
  end

  # Reattach generated :validate / :parse accessor fns to the {name, opts} list.
  # Each reattach branch is only emitted when its list is non-empty; an empty
  # list would expand to `if n in []`, which the compiler flags as an always-false
  # conditional in the user's generated __cheer_meta__/0.
  defp merge_accessors(params, has_validate, has_parse) do
    if has_validate == [] and has_parse == [] do
      Macro.escape(params)
    else
      quote do
        Enum.map(unquote(Macro.escape(params)), fn {n, o} ->
          o = unquote(reattach_step(:validate, has_validate))
          o = unquote(reattach_step(:parse, has_parse))
          {n, o}
        end)
      end
    end
  end

  # An empty list means no such accessor: leave `o` untouched (no `if n in []`).
  defp reattach_step(_kind, []), do: quote(do: o)

  defp reattach_step(:validate, names) do
    quote do
      if n in unquote(names),
        do: Keyword.put(o, :validate, &apply(__MODULE__, :"__cheer_validate_#{n}__", [&1])),
        else: o
    end
  end

  defp reattach_step(:parse, names) do
    quote do
      if n in unquote(names),
        do: Keyword.put(o, :parse, &apply(__MODULE__, :"__cheer_parse_#{n}__", [&1])),
        else: o
    end
  end

  defp make_indexed_fns(_fname, 0), do: quote(do: [])

  defp make_indexed_fns(fname, count) do
    quote do
      Enum.map(0..(unquote(count) - 1), fn idx ->
        fn val -> apply(__MODULE__, unquote(fname), [idx, val]) end
      end)
    end
  end

  defp build_groups(raw_groups) do
    raw_groups
    |> Enum.group_by(fn {name, _opts, _member} -> name end)
    |> Map.new(fn {name, entries} ->
      [{_, opts, _} | _] = entries
      members = Enum.map(entries, fn {_, _, member} -> member end)
      {name, %{opts: opts, members: members}}
    end)
  end
end

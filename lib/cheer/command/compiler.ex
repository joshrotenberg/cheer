defmodule Cheer.Command.Compiler do
  @moduledoc """
  Compile-time hook that materializes command metadata from module attributes
  and validates command definitions.
  """

  defmacro __before_compile__(env) do
    name = Module.get_attribute(env.module, :cheer_command_name) || ""
    about = Module.get_attribute(env.module, :cheer_about) || ""
    version = Module.get_attribute(env.module, :cheer_version)
    arguments = Module.get_attribute(env.module, :cheer_arguments) |> Enum.reverse()
    options = Module.get_attribute(env.module, :cheer_options) |> Enum.reverse()
    subcommands = Module.get_attribute(env.module, :cheer_subcommands) |> Enum.reverse()
    has_validate = Module.get_attribute(env.module, :cheer_has_validate)
    validator_count = Module.get_attribute(env.module, :cheer_validator_count)
    before_run_count = Module.get_attribute(env.module, :cheer_before_run_count)
    after_run_count = Module.get_attribute(env.module, :cheer_after_run_count)
    persistent_before_count = Module.get_attribute(env.module, :cheer_persistent_before_run_count)
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

    # Build groups map: %{group_name => %{opts: [...], members: [...]}}
    groups = build_groups(raw_groups)

    # Options: merge validate fns from generated functions
    options_expr =
      if has_validate == [] do
        Macro.escape(options)
      else
        quote do
          Enum.map(unquote(Macro.escape(options)), fn {n, o} ->
            if n in unquote(has_validate) do
              fname = :"__cheer_validate_#{n}__"
              {n, Keyword.put(o, :validate, &apply(__MODULE__, fname, [&1]))}
            else
              {n, o}
            end
          end)
        end
      end

    arguments_expr =
      if has_validate == [] do
        Macro.escape(arguments)
      else
        quote do
          Enum.map(unquote(Macro.escape(arguments)), fn {n, o} ->
            if n in unquote(has_validate) do
              fname = :"__cheer_validate_#{n}__"
              {n, Keyword.put(o, :validate, &apply(__MODULE__, fname, [&1]))}
            else
              {n, o}
            end
          end)
        end
      end

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
          version: unquote(version),
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

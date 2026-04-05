defmodule Cheer.Router do
  @moduledoc """
  Routes argv through the command tree and dispatches to the matched command.

  Handles the full dispatch pipeline: subcommand matching, option parsing
  (via `OptionParser`), default/env-var application, validation (required
  fields, choices, custom validators, cross-param validators, groups), and
  lifecycle hook execution.

  This module is called internally by `Cheer.run/3` and is not typically
  invoked directly.
  """

  @doc """
  Dispatch `argv` through the command tree rooted at `command`.

  Options:

    * `:prog` - program name for help/usage output
    * `:parent_hooks` - (internal) accumulated persistent hooks from parent commands
  """
  @spec dispatch(module(), [String.t()], keyword()) :: term()
  def dispatch(command, argv, opts \\ []) do
    parent_hooks = Keyword.get(opts, :parent_hooks, [])
    dispatch_with_hooks(command, argv, opts, parent_hooks)
  end

  defp dispatch_with_hooks(command, argv, opts, parent_hooks) do
    meta = command.__cheer_meta__()

    # Accumulate global options from this command
    parent_globals = Keyword.get(opts, :parent_globals, [])

    global_opts =
      meta.options
      |> Enum.filter(fn {_name, o} -> Keyword.get(o, :global, false) end)

    accumulated_globals = parent_globals ++ global_opts
    opts = Keyword.put(opts, :parent_globals, accumulated_globals)

    # Accumulate persistent hooks from this command
    hooks = parent_hooks ++ Map.get(meta, :persistent_before_run, [])

    # If the first token matches a subcommand, dispatch to it before checking
    # flags. This ensures `tool sub --help` shows the subcommand's help.
    first_is_subcommand =
      case argv do
        [token | _] ->
          Enum.any?(meta.subcommands, fn sub ->
            sub_meta = sub.__cheer_meta__()
            sub_meta.name == token or token in Map.get(sub_meta, :aliases, [])
          end)

        _ ->
          false
      end

    cond do
      first_is_subcommand ->
        dispatch_command(command, meta, argv, Keyword.put(opts, :parent_hooks, hooks), hooks)

      "--help" in argv ->
        Cheer.Help.print(command, Keyword.put(opts, :long, true))

      "-h" in argv ->
        Cheer.Help.print(command, opts)

      "--version" in argv or "-V" in argv ->
        print_version(meta)

      match?(["help" | _], argv) ->
        resolve_help(command, tl(argv), opts)

      true ->
        dispatch_command(command, meta, argv, Keyword.put(opts, :parent_hooks, hooks), hooks)
    end
  end

  defp resolve_help(command, [], opts),
    do: Cheer.Help.print(command, Keyword.put(opts, :long, true))

  defp resolve_help(command, [token | rest], opts) do
    meta = command.__cheer_meta__()

    case match_subcommand(meta.subcommands, [token]) do
      {:ok, sub_module, _} ->
        resolve_help(sub_module, rest, opts)

      _ ->
        IO.puts("error: unknown command '#{token}'")
        :ok
    end
  end

  defp dispatch_command(command, meta, argv, opts, hooks) do
    case match_subcommand(meta.subcommands, argv) do
      {:ok, sub_module, rest} ->
        dispatch_with_hooks(sub_module, rest, opts, hooks)

      {:error, unknown_token} ->
        print_unknown_command(meta, unknown_token)

      :none when meta.subcommands != [] ->
        Cheer.Help.print(command, opts)

      :none ->
        case parse_and_validate(command, meta, argv, opts) do
          {:ok, args} ->
            # Apply persistent hooks from parents, then local before_run
            args = apply_hooks(args, hooks)
            args = apply_hooks(args, Map.get(meta, :before_run, []))

            result = command.run(args, argv)

            # Apply after_run hooks
            apply_after_hooks(result, Map.get(meta, :after_run, []))

          :handled ->
            :ok
        end
    end
  end

  defp apply_hooks(args, []), do: args

  defp apply_hooks(args, [hook | rest]) do
    args = hook.(args)
    apply_hooks(args, rest)
  end

  defp apply_after_hooks(result, []), do: result

  defp apply_after_hooks(result, [hook | rest]) do
    result = hook.(result)
    apply_after_hooks(result, rest)
  end

  # -- Parsing pipeline --

  defp parse_and_validate(command, meta, argv, opts) do
    # Merge parent global options with this command's options
    parent_globals = Keyword.get(opts, :parent_globals, [])

    inherited_globals =
      parent_globals
      |> Enum.reject(fn {name, _} ->
        Enum.any?(meta.options, fn {n, _} -> n == name end)
      end)

    all_options = meta.options ++ inherited_globals

    {option_parser_opts, option_aliases} = build_option_parser_spec(all_options)

    {parsed, positional, invalid} =
      OptionParser.parse(argv, strict: option_parser_opts, aliases: option_aliases)

    if invalid != [] do
      print_invalid_options_error(command, invalid, opts)
      :handled
    else
      args = apply_defaults(all_options)
      args = apply_env_vars(args, all_options)
      args = Map.merge(args, Map.new(parsed))

      args =
        meta.arguments
        |> Enum.zip(positional)
        |> Enum.reduce(args, fn {{name, arg_opts}, value}, acc ->
          Map.put(acc, name, coerce_arg(value, arg_opts))
        end)

      missing =
        missing_required(meta.arguments, args) ++ missing_required(all_options, args)

      cond do
        missing != [] ->
          print_missing_args_error(command, missing, opts)
          :handled

        true ->
          with :ok <- validate_groups(args, Map.get(meta, :groups, %{})),
               :ok <- validate_params(args, all_options),
               :ok <- run_validators(args, Map.get(meta, :validators, [])) do
            {:ok, args}
          else
            {:error, msg} ->
              IO.puts("error: #{msg}")
              :handled
          end
      end
    end
  end

  defp missing_required(params, args) do
    params
    |> Enum.filter(fn {_name, o} -> Keyword.get(o, :required, false) end)
    |> Enum.reject(fn {name, _o} -> Map.has_key?(args, name) end)
    |> Enum.map(fn {name, _o} -> name end)
  end

  # -- Groups validation --

  defp validate_groups(_args, groups) when map_size(groups) == 0, do: :ok

  defp validate_groups(args, groups) do
    Enum.reduce_while(groups, :ok, fn {name, %{opts: opts, members: members}}, _acc ->
      set_members = Enum.filter(members, &Map.has_key?(args, &1))

      cond do
        Keyword.get(opts, :mutually_exclusive, false) and length(set_members) > 1 ->
          flags = Enum.map_join(set_members, ", ", &"--#{&1}")
          {:halt, {:error, "options #{flags} are mutually exclusive (group: #{name})"}}

        Keyword.get(opts, :co_occurring, false) and set_members != [] and
            length(set_members) != length(members) ->
          flags = Enum.map_join(members, ", ", &"--#{&1}")
          {:halt, {:error, "options #{flags} must be used together (group: #{name})"}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  # -- Defaults --

  defp apply_defaults(options) do
    options
    |> Enum.filter(fn {_name, opts} -> Keyword.has_key?(opts, :default) end)
    |> Enum.reduce(%{}, fn {name, opts}, acc ->
      Map.put(acc, name, Keyword.fetch!(opts, :default))
    end)
  end

  # -- Env vars --

  defp apply_env_vars(args, options) do
    options
    |> Enum.filter(fn {_name, opts} -> Keyword.has_key?(opts, :env) end)
    |> Enum.reduce(args, fn {name, opts}, acc ->
      env_name = Keyword.fetch!(opts, :env)

      case System.get_env(env_name) do
        nil -> acc
        value -> Map.put(acc, name, coerce_env(value, Keyword.get(opts, :type, :string)))
      end
    end)
  end

  defp coerce_env(value, :integer) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> value
    end
  end

  defp coerce_env(value, :float) do
    case Float.parse(value) do
      {n, ""} -> n
      _ -> value
    end
  end

  defp coerce_env(value, :boolean), do: value in ["true", "1", "yes"]
  defp coerce_env(value, _), do: value

  # -- Per-param validation --

  defp validate_params(args, options) do
    Enum.reduce_while(options, :ok, fn {name, opts}, _acc ->
      case Map.fetch(args, name) do
        {:ok, value} ->
          with :ok <- validate_choices(name, value, opts),
               :ok <- validate_custom(name, value, opts) do
            {:cont, :ok}
          else
            {:error, msg} -> {:halt, {:error, msg}}
          end

        :error ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_choices(name, value, opts) do
    case Keyword.get(opts, :choices) do
      nil ->
        :ok

      choices ->
        if to_string(value) in Enum.map(choices, &to_string/1) do
          :ok
        else
          {:error, "--#{name} must be one of: #{Enum.join(choices, ", ")}"}
        end
    end
  end

  defp validate_custom(_name, value, opts) do
    case Keyword.get(opts, :validate) do
      nil -> :ok
      fun when is_function(fun, 1) -> fun.(value)
    end
  end

  # -- Cross-param validators --

  defp run_validators(_args, []), do: :ok

  defp run_validators(args, [validator | rest]) do
    case validator.(args) do
      :ok -> run_validators(args, rest)
      {:error, _msg} = err -> err
    end
  end

  # -- Arg coercion --

  defp coerce_arg(value, opts) do
    case Keyword.get(opts, :type, :string) do
      :integer ->
        case Integer.parse(value) do
          {n, ""} -> n
          _ -> value
        end

      :float ->
        case Float.parse(value) do
          {n, ""} -> n
          _ -> value
        end

      :boolean ->
        value in ["true", "1", "yes"]

      _ ->
        value
    end
  end

  # -- Subcommand matching --

  defp match_subcommand([], _argv), do: :none

  defp match_subcommand(subcommands, [token | rest]) do
    found =
      Enum.find_value(subcommands, nil, fn sub_module ->
        sub_meta = sub_module.__cheer_meta__()
        aliases = Map.get(sub_meta, :aliases, [])

        if sub_meta.name == token or token in aliases do
          {:ok, sub_module, rest}
        end
      end)

    case found do
      {:ok, _, _} = match ->
        match

      nil ->
        if String.starts_with?(token, "-") do
          :none
        else
          {:error, token}
        end
    end
  end

  defp match_subcommand(_subcommands, []), do: :none

  # -- OptionParser spec --

  defp build_option_parser_spec(options) do
    spec =
      Enum.map(options, fn {name, opts} ->
        {name, Keyword.get(opts, :type, :string)}
      end)

    aliases =
      options
      |> Enum.filter(fn {_name, opts} -> Keyword.has_key?(opts, :short) end)
      |> Enum.map(fn {name, opts} -> {Keyword.fetch!(opts, :short), name} end)

    {spec, aliases}
  end

  # -- Output helpers --

  defp print_version(meta) do
    case meta[:version] do
      nil -> IO.puts("#{meta.name} (version not set)")
      version -> IO.puts("#{meta.name} #{version}")
    end

    :ok
  end

  defp print_unknown_command(meta, token) do
    IO.puts("error: unknown command '#{token}'")

    # "Did you mean?" suggestion
    if meta.subcommands != [] do
      names =
        Enum.flat_map(meta.subcommands, fn sub ->
          sub_meta = sub.__cheer_meta__()
          [sub_meta.name | Map.get(sub_meta, :aliases, [])]
        end)

      case suggest(token, names) do
        nil -> :ok
        suggestion -> IO.puts("\n  Did you mean '#{suggestion}'?")
      end

      IO.puts("\nAvailable commands:")

      for sub <- meta.subcommands do
        sub_meta = sub.__cheer_meta__()
        IO.puts("  #{sub_meta.name}")
      end

      IO.puts("")
    end

    :ok
  end

  defp suggest(input, candidates) do
    candidates
    |> Enum.map(fn c -> {c, String.jaro_distance(input, c)} end)
    |> Enum.filter(fn {_c, d} -> d > 0.7 end)
    |> Enum.sort_by(fn {_c, d} -> d end, :desc)
    |> case do
      [{best, _} | _] -> best
      [] -> nil
    end
  end

  defp print_missing_args_error(command, missing_names, opts) do
    labels = Enum.map_join(missing_names, ", ", &"<#{&1}>")
    IO.puts("error: missing required argument(s): #{labels}")
    IO.puts("")
    Cheer.Help.print(command, opts)
  end

  defp print_invalid_options_error(command, invalid, opts) do
    flags = Enum.map_join(invalid, ", ", fn {flag, _} -> flag end)
    IO.puts("error: unknown option(s): #{flags}")
    IO.puts("")
    Cheer.Help.print(command, opts)
  end
end

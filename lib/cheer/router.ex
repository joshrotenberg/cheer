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

    # Resolve prog so help/usage output reflects the full subcommand path.
    # First entry: default to the root command's name if caller didn't set one.
    opts =
      case Keyword.get(opts, :prog) do
        nil -> Keyword.put(opts, :prog, meta.name)
        _ -> opts
      end

    # Propagate version from parent if enabled
    meta =
      if meta.version == nil and Keyword.has_key?(opts, :propagated_version) do
        Map.put(meta, :version, Keyword.get(opts, :propagated_version))
      else
        meta
      end

    opts =
      if meta.propagate_version and meta.version do
        Keyword.put(opts, :propagated_version, meta.version)
      else
        opts
      end

    # Accumulate global options from this command
    parent_globals = Keyword.get(opts, :parent_globals, [])

    global_opts =
      Enum.filter(meta.options, fn {_name, o} -> Keyword.get(o, :global, false) end)

    accumulated_globals = parent_globals ++ global_opts
    opts = Keyword.put(opts, :parent_globals, accumulated_globals)

    # Accumulate persistent hooks from this command
    hooks = parent_hooks ++ Map.get(meta, :persistent_before_run, [])

    # If the first token matches a subcommand, dispatch to it before checking
    # flags. This ensures `tool sub --help` shows the subcommand's help.
    infer? = Map.get(meta, :infer_subcommands, false)

    first_is_subcommand =
      case argv do
        [token | _] ->
          case match_subcommand(meta.subcommands, [token], infer?) do
            {:ok, _, _} -> true
            {:ambiguous, _, _} -> true
            _ -> false
          end

        _ ->
          false
      end

    cond do
      first_is_subcommand ->
        dispatch_command(command, meta, argv, Keyword.put(opts, :parent_hooks, hooks), hooks)

      flag_requested?(argv, ["--help"]) ->
        Cheer.Help.print(command, Keyword.put(opts, :long, true))

      flag_requested?(argv, ["-h"]) ->
        Cheer.Help.print(command, opts)

      flag_requested?(argv, ["--version", "-V"]) ->
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
    infer? = Map.get(meta, :infer_subcommands, false)

    case match_subcommand(meta.subcommands, [token], infer?) do
      {:ok, sub_module, _} ->
        sub_name = sub_module.__cheer_meta__().name
        child_opts = Keyword.update(opts, :prog, sub_name, &"#{&1} #{sub_name}")
        resolve_help(sub_module, rest, child_opts)

      {:ambiguous, t, candidates} ->
        print_ambiguous_subcommand(t, candidates)
        {:error, :usage}

      _ ->
        IO.puts("error: unknown command '#{token}'")
        {:error, :usage}
    end
  end

  defp dispatch_command(command, meta, argv, opts, hooks) do
    infer? = Map.get(meta, :infer_subcommands, false)
    external? = Map.get(meta, :external_subcommands, false)
    args_conflict? = Map.get(meta, :args_conflicts_with_subcommands, false)

    case match_subcommand(meta.subcommands, argv, infer?) do
      {:ok, sub_module, rest} ->
        sub_name = sub_module.__cheer_meta__().name
        child_opts = Keyword.update!(opts, :prog, &"#{&1} #{sub_name}")
        dispatch_with_hooks(sub_module, rest, child_opts, hooks)

      {:ambiguous, token, candidates} ->
        print_ambiguous_subcommand(token, candidates)
        {:error, :usage}

      {:error, _unknown_token} when external? ->
        run_leaf(command, meta, argv, opts, hooks)

      # With args_conflicts_with_subcommands, an unknown first token is not an
      # error: parse it (and the rest of argv) as this command's own arguments
      # and options, so the parent command runs.
      {:error, _unknown_token} when args_conflict? ->
        run_leaf(command, meta, argv, opts, hooks)

      {:error, unknown_token} ->
        print_unknown_command(meta, unknown_token)
        {:error, :usage}

      :none when meta.subcommands != [] and meta.subcommand_required ->
        IO.puts("error: a subcommand is required")
        IO.puts("")
        Cheer.Help.print(command, opts)
        {:error, :usage}

      # No subcommand matched (argv is empty or starts with an option). When the
      # parent is runnable, dispatch to it rather than printing help.
      :none when meta.subcommands != [] and args_conflict? ->
        run_leaf(command, meta, argv, opts, hooks)

      :none when meta.subcommands != [] and not external? ->
        Cheer.Help.print(command, opts)

      :none when meta.subcommands != [] and argv == [] ->
        Cheer.Help.print(command, opts)

      :none ->
        run_leaf(command, meta, argv, opts, hooks)
    end
  end

  defp run_leaf(command, meta, argv, opts, hooks) do
    case parse_and_validate(command, meta, argv, opts) do
      {:ok, args} ->
        # Apply persistent hooks from parents, then local before_run
        args = apply_hooks(args, hooks)
        args = apply_hooks(args, Map.get(meta, :before_run, []))

        result = command.run(args, argv)

        # Apply after_run hooks
        apply_after_hooks(result, Map.get(meta, :after_run, []))

      :handled ->
        {:error, :usage}
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
    if Map.get(meta, :external_subcommands, false) do
      parse_with_external_subcommand(command, meta, argv, opts)
    else
      parse_standard(command, meta, argv, opts)
    end
  end

  defp parse_standard(command, meta, argv, opts) do
    # Merge parent global options with this command's options
    parent_globals = Keyword.get(opts, :parent_globals, [])

    inherited_globals =
      Enum.reject(parent_globals, fn {name, _} ->
        Enum.any?(meta.options, fn {n, _} -> n == name end)
      end)

    all_options = meta.options ++ inherited_globals

    # Options declared with `num_args:` accept several values per flag, which
    # OptionParser cannot express. Options with `allow_hyphen_values:` accept a
    # value starting with `-`, which OptionParser would read as a flag. Pull both
    # (and their value tokens) out of argv up front, then parse the remainder.
    {num_args_values, argv} = extract_num_args(argv, all_options)
    {hyphen_values, argv} = extract_hyphen_values(argv, all_options)

    parser_options =
      Enum.reject(all_options, fn {_name, o} = opt ->
        Keyword.has_key?(o, :num_args) or single_value_hyphen_opt?(opt)
      end)

    {option_parser_opts, option_aliases} = build_option_parser_spec(parser_options)

    {parsed, positional, invalid} =
      OptionParser.parse(argv, strict: option_parser_opts, aliases: option_aliases)

    if invalid != [] do
      print_invalid_options_error(command, invalid, opts, all_options)
      :handled
    else
      parsed_map = build_parsed_map(parsed, all_options)
      args = apply_defaults(all_options)
      args = apply_env_vars(args, all_options)
      args = Map.merge(args, parsed_map)
      args = Map.merge(args, num_args_values)
      args = Map.merge(args, hyphen_values)
      args = apply_value_delimiters(args, all_options)

      {declared_positional, rest_args} = Enum.split(positional, length(meta.arguments))

      supplied_positional =
        meta.arguments
        |> Enum.zip(declared_positional)
        |> Enum.map(fn {{name, _opts}, _value} -> name end)

      args =
        meta.arguments
        |> Enum.zip(declared_positional)
        |> Enum.reduce(args, fn {{name, arg_opts}, value}, acc ->
          Map.put(acc, name, coerce_arg(value, arg_opts))
        end)

      # Names the user actually supplied (parsed flags, num_args flags, and
      # positionals present in argv). Constraint checks key off this rather than
      # Map.has_key?/2 so that defaults, :count (0), and :multi ([]) do not read
      # as "provided". Env fallback is intentionally not counted as user input.
      provided =
        MapSet.new(
          Map.keys(parsed_map) ++
            Map.keys(num_args_values) ++ Map.keys(hyphen_values) ++ supplied_positional
        )

      args =
        case meta[:trailing_var_arg] do
          {tva_name, _tva_opts} -> Map.put(args, tva_name, rest_args)
          _ -> Map.put(args, :rest, rest_args)
        end

      missing =
        missing_required(meta.arguments, args) ++
          missing_required_options(all_options, args)

      missing =
        case meta[:trailing_var_arg] do
          {tva_name, tva_opts} ->
            if Keyword.get(tva_opts, :required, false) and rest_args == [] do
              missing ++ [tva_name]
            else
              missing
            end

          _ ->
            missing
        end

      cond do
        missing != [] ->
          print_missing_args_error(command, missing, opts)
          :handled

        true ->
          arg_names = MapSet.new(meta.arguments, fn {n, _} -> n end)

          with {:ok, args} <- apply_parsers(args, all_options ++ meta.arguments, arg_names),
               :ok <- validate_num_args(num_args_values, all_options),
               :ok <- validate_conditional_required(args, all_options, provided),
               :ok <- validate_constraints(all_options, provided),
               :ok <- validate_groups(provided, Map.get(meta, :groups, %{})),
               # Include arguments so argument-level :validate and :choices run.
               :ok <- validate_params(args, all_options ++ meta.arguments, arg_names),
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

  # Parse path for commands with `external_subcommands: true`. Uses parse_head
  # so the first non-option token (and everything after) is surfaced as the
  # external subcommand rather than being treated as a parent positional or as
  # an unknown-option error.
  defp parse_with_external_subcommand(command, meta, argv, opts) do
    parent_globals = Keyword.get(opts, :parent_globals, [])

    inherited_globals =
      Enum.reject(parent_globals, fn {name, _} ->
        Enum.any?(meta.options, fn {n, _} -> n == name end)
      end)

    all_options = meta.options ++ inherited_globals

    # Pull num_args and hyphen-value flags out first (head mode: stop at the
    # external subcommand), then parse the remainder. OptionParser cannot express
    # multi-value flags or `-`-leading values.
    {num_args_values, argv} = extract_num_args(argv, all_options, true)
    {hyphen_values, argv} = extract_hyphen_values(argv, all_options, true)

    parser_options =
      Enum.reject(all_options, fn {_name, o} = opt ->
        Keyword.has_key?(o, :num_args) or single_value_hyphen_opt?(opt)
      end)

    {option_parser_opts, option_aliases} = build_option_parser_spec(parser_options)

    {parsed, positional, invalid} =
      OptionParser.parse_head(argv, strict: option_parser_opts, aliases: option_aliases)

    if invalid != [] do
      print_invalid_options_error(command, invalid, opts, all_options)
      :handled
    else
      parsed_map = build_parsed_map(parsed, all_options)
      args = apply_defaults(all_options)
      args = apply_env_vars(args, all_options)
      args = Map.merge(args, parsed_map)
      args = Map.merge(args, num_args_values)
      args = Map.merge(args, hyphen_values)
      args = apply_value_delimiters(args, all_options)

      args =
        case positional do
          [] -> Map.put(args, :external_subcommand, nil)
          [name | rest] -> Map.put(args, :external_subcommand, {name, rest})
        end

      provided =
        MapSet.new(Map.keys(parsed_map) ++ Map.keys(num_args_values) ++ Map.keys(hyphen_values))

      missing = missing_required_options(all_options, args)

      cond do
        missing != [] ->
          print_missing_args_error(command, missing, opts)
          :handled

        true ->
          arg_names = MapSet.new(meta.arguments, fn {n, _} -> n end)

          with {:ok, args} <- apply_parsers(args, all_options ++ meta.arguments, arg_names),
               :ok <- validate_num_args(num_args_values, all_options),
               :ok <- validate_conditional_required(args, all_options, provided),
               :ok <- validate_constraints(all_options, provided),
               :ok <- validate_groups(provided, Map.get(meta, :groups, %{})),
               # Include arguments so argument-level :validate and :choices run.
               :ok <- validate_params(args, all_options ++ meta.arguments, arg_names),
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

  defp missing_required_options(options, args) do
    options
    |> Enum.filter(fn {_name, o} -> Keyword.get(o, :required, false) end)
    |> Enum.reject(fn {name, o} ->
      case Map.fetch(args, name) do
        {:ok, []} -> not Keyword.get(o, :multi, false)
        {:ok, _} -> true
        :error -> false
      end
    end)
    |> Enum.map(fn {name, _o} -> name end)
  end

  # -- Conditional required (required_if / required_unless) --

  defp validate_conditional_required(args, options, provided) do
    Enum.reduce_while(options, :ok, fn {name, opts}, _acc ->
      if MapSet.member?(provided, name) do
        {:cont, :ok}
      else
        check_conditional_required(name, opts, args, provided)
      end
    end)
  end

  defp check_conditional_required(name, opts, args, provided) do
    cond do
      Keyword.has_key?(opts, :required_if) ->
        case match_required_if(Keyword.fetch!(opts, :required_if), args, provided) do
          {:match, dep, val} ->
            {:halt,
             {:error,
              "--#{flag_string(name)} is required when --#{flag_string(dep)} is #{format_required_value(val)}"}}

          :no_match ->
            {:cont, :ok}
        end

      Keyword.has_key?(opts, :required_unless) ->
        deps = Keyword.fetch!(opts, :required_unless)

        if any_present?(deps, provided) do
          {:cont, :ok}
        else
          {:halt,
           {:error,
            "--#{flag_string(name)} is required unless #{format_dep_list(deps)} is provided"}}
        end

      Keyword.has_key?(opts, :required_if_all) ->
        checks = Keyword.fetch!(opts, :required_if_all)

        if match_required_if_all?(checks, args, provided) do
          {:halt, {:error, "--#{flag_string(name)} is required when #{format_if_all(checks)}"}}
        else
          {:cont, :ok}
        end

      Keyword.has_key?(opts, :required_unless_all) ->
        deps = Keyword.fetch!(opts, :required_unless_all)

        if all_present?(deps, provided) do
          {:cont, :ok}
        else
          {:halt,
           {:error,
            "--#{flag_string(name)} is required unless #{format_dep_list(deps)} are all provided"}}
        end

      true ->
        {:cont, :ok}
    end
  end

  # required_if matches when ANY condition holds; required_if_all when they all do.
  defp match_required_if_all?(checks, args, provided) when is_list(checks) do
    Enum.all?(checks, fn {dep, expected} ->
      MapSet.member?(provided, dep) and match?({:ok, ^expected}, Map.fetch(args, dep))
    end)
  end

  defp all_present?(name, provided) when is_atom(name), do: MapSet.member?(provided, name)

  defp all_present?(names, provided) when is_list(names),
    do: Enum.all?(names, &MapSet.member?(provided, &1))

  defp format_if_all(checks) do
    Enum.map_join(checks, " and ", fn {dep, val} ->
      "--#{flag_string(dep)} is #{format_required_value(val)}"
    end)
  end

  # Only deps the user actually supplied can trigger a required_if: a dependency
  # left at its default value must not force the requirement.
  defp match_required_if(checks, args, provided) when is_list(checks) do
    Enum.find_value(checks, :no_match, fn {dep, expected} ->
      if MapSet.member?(provided, dep) do
        case Map.fetch(args, dep) do
          {:ok, ^expected} -> {:match, dep, expected}
          _ -> nil
        end
      end
    end)
  end

  defp any_present?(name, provided) when is_atom(name), do: MapSet.member?(provided, name)

  defp any_present?(names, provided) when is_list(names),
    do: Enum.any?(names, &MapSet.member?(provided, &1))

  defp format_dep_list(name) when is_atom(name), do: "--#{flag_string(name)}"

  defp format_dep_list(names) when is_list(names),
    do: Enum.map_join(names, ", ", &"--#{flag_string(&1)}")

  defp format_required_value(val) when is_binary(val), do: "'#{val}'"
  defp format_required_value(val), do: inspect(val)

  # -- Per-option constraints (conflicts_with / requires) --

  defp validate_constraints(options, provided) do
    Enum.reduce_while(options, :ok, fn {name, opts}, _acc ->
      if MapSet.member?(provided, name) do
        check_constraints(name, opts, provided)
      else
        {:cont, :ok}
      end
    end)
  end

  defp check_constraints(name, opts, provided) do
    with :ok <- check_conflicts(name, opts, provided),
         :ok <- check_requires(name, opts, provided) do
      {:cont, :ok}
    else
      err -> {:halt, err}
    end
  end

  defp check_conflicts(name, opts, provided) do
    conflicts = list_of(Keyword.get(opts, :conflicts_with))

    case Enum.find(conflicts, &MapSet.member?(provided, &1)) do
      nil -> :ok
      other -> {:error, "--#{flag_string(name)} cannot be used with --#{flag_string(other)}"}
    end
  end

  defp check_requires(name, opts, provided) do
    requires = list_of(Keyword.get(opts, :requires))

    case Enum.find(requires, &(not MapSet.member?(provided, &1))) do
      nil -> :ok
      other -> {:error, "--#{flag_string(name)} requires --#{flag_string(other)}"}
    end
  end

  defp list_of(nil), do: []
  defp list_of(atom) when is_atom(atom), do: [atom]
  defp list_of(list) when is_list(list), do: list

  # -- Groups validation --

  defp validate_groups(_provided, groups) when map_size(groups) == 0, do: :ok

  defp validate_groups(provided, groups) do
    Enum.reduce_while(groups, :ok, fn {name, %{opts: opts, members: members}}, _acc ->
      set_members = Enum.filter(members, &MapSet.member?(provided, &1))

      cond do
        Keyword.get(opts, :mutually_exclusive, false) and length(set_members) > 1 ->
          flags = Enum.map_join(set_members, ", ", &"--#{flag_string(&1)}")
          {:halt, {:error, "options #{flags} are mutually exclusive (group: #{name})"}}

        Keyword.get(opts, :co_occurring, false) and set_members != [] and
            length(set_members) != length(members) ->
          flags = Enum.map_join(members, ", ", &"--#{flag_string(&1)}")
          {:halt, {:error, "options #{flags} must be used together (group: #{name})"}}

        Keyword.get(opts, :required, false) and set_members == [] ->
          flags = Enum.map_join(members, ", ", &"--#{flag_string(&1)}")
          {:halt, {:error, "one of #{flags} is required (group: #{name})"}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  # -- Defaults --

  defp apply_defaults(options) do
    Enum.reduce(options, %{}, fn {name, opts}, acc ->
      cond do
        Keyword.has_key?(opts, :default) ->
          Map.put(acc, name, Keyword.fetch!(opts, :default))

        Keyword.get(opts, :type) == :count ->
          Map.put(acc, name, 0)

        Keyword.get(opts, :multi, false) ->
          Map.put(acc, name, [])

        true ->
          acc
      end
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

  # -- Value delimiter --

  # Split value_delimiter options into a list and coerce each element. Runs after
  # all value sources are merged, so it covers user-supplied values, env
  # fallbacks, and string defaults uniformly. A :multi value (already a list) has
  # each occurrence split and the result flattened.
  defp apply_value_delimiters(args, options) do
    Enum.reduce(options, args, fn {name, opts}, acc ->
      case Keyword.get(opts, :value_delimiter) do
        nil ->
          acc

        delim ->
          case Map.fetch(acc, name) do
            {:ok, value} -> Map.put(acc, name, split_delimited(value, delim, opts))
            :error -> acc
          end
      end
    end)
  end

  defp split_delimited(value, delim, opts) when is_binary(value) do
    value |> String.split(delim) |> Enum.map(&coerce_arg(&1, opts))
  end

  defp split_delimited(values, delim, opts) when is_list(values) do
    values
    |> Enum.flat_map(fn
      v when is_binary(v) -> String.split(v, delim)
      v -> [v]
    end)
    |> Enum.map(&coerce_arg(&1, opts))
  end

  defp split_delimited(value, _delim, _opts), do: value

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

  # A :count option is always an integer (its default is 0), so an env fallback
  # must be coerced too. An unparseable value floors to 0 rather than leaking a
  # string into run/2.
  defp coerce_env(value, :count) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> 0
    end
  end

  defp coerce_env(value, _), do: value

  # -- Per-param validation --

  # -- Custom parsers (:parse) --

  # Apply each param's :parse fn to its value, transforming it into a domain
  # value. Runs before validation so :choices/:validate see the parsed value. A
  # list value (multi, num_args, value_delimiter) is parsed element-wise.
  defp apply_parsers(args, params, arg_names) do
    Enum.reduce_while(params, {:ok, args}, fn {name, opts}, {:ok, acc} ->
      with fun when is_function(fun, 1) <- Keyword.get(opts, :parse),
           {:ok, value} <- Map.fetch(acc, name) do
        case apply_parse_value(fun, value) do
          {:ok, parsed} -> {:cont, {:ok, Map.put(acc, name, parsed)}}
          {:error, msg} -> {:halt, {:error, "#{param_label(name, arg_names)}: #{msg}"}}
        end
      else
        _ -> {:cont, {:ok, acc}}
      end
    end)
  end

  defp apply_parse_value(fun, values) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn v, {:ok, acc} ->
      case call_user_fun(fun, v) do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      err -> err
    end
  end

  defp apply_parse_value(fun, value), do: call_user_fun(fun, value)

  # Run a user-supplied :parse / :validate function, turning a raised exception
  # into a clean {:error, msg} so a buggy function cannot crash the whole program
  # (and defeat Cheer.main/3's exit-code handling).
  defp call_user_fun(fun, value) do
    fun.(value)
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp validate_params(args, options, arg_names) do
    Enum.reduce_while(options, :ok, fn {name, opts}, _acc ->
      case Map.fetch(args, name) do
        {:ok, value} ->
          with :ok <- validate_choices(name, value, opts, arg_names),
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

  defp validate_choices(name, value, opts, arg_names) do
    case Keyword.get(opts, :choices) do
      nil ->
        :ok

      choices ->
        allowed = Enum.map(choices, &to_string/1)
        values = if is_list(value), do: value, else: [value]

        if Enum.all?(values, &(to_string(&1) in allowed)) do
          :ok
        else
          {:error, "#{param_label(name, arg_names)} must be one of: #{Enum.join(choices, ", ")}"}
        end
    end
  end

  defp validate_custom(_name, value, opts) do
    case Keyword.get(opts, :validate) do
      nil -> :ok
      fun when is_function(fun, 1) -> call_user_fun(fun, value)
    end
  end

  # A positional argument renders as <name>; an option as its kebab-cased flag.
  defp param_label(name, arg_names) do
    if MapSet.member?(arg_names, name), do: "<#{name}>", else: "--#{flag_string(name)}"
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

  defp match_subcommand([], _argv, _infer?), do: :none
  defp match_subcommand(_subcommands, [], _infer?), do: :none

  defp match_subcommand(subcommands, [token | rest], infer?) do
    exact =
      Enum.find(subcommands, fn sub_module ->
        sub_meta = sub_module.__cheer_meta__()
        sub_meta.name == token or token in Map.get(sub_meta, :aliases, [])
      end)

    cond do
      exact != nil ->
        {:ok, exact, rest}

      String.starts_with?(token, "-") ->
        :none

      infer? ->
        infer_subcommand(subcommands, token, rest)

      true ->
        {:error, token}
    end
  end

  defp infer_subcommand(subcommands, token, rest) do
    candidates =
      Enum.filter(subcommands, fn sub ->
        String.starts_with?(sub.__cheer_meta__().name, token)
      end)

    case candidates do
      [single] ->
        {:ok, single, rest}

      [] ->
        {:error, token}

      many ->
        names =
          many
          |> Enum.map(& &1.__cheer_meta__().name)
          |> Enum.sort()

        {:ambiguous, token, names}
    end
  end

  defp print_ambiguous_subcommand(token, candidates) do
    IO.puts("error: '#{token}' is ambiguous")
    IO.puts("candidates: #{Enum.join(candidates, ", ")}")
  end

  # -- num_args (multi-value options) --

  # Collect values for options declared with `num_args:`. OptionParser binds a
  # single value per flag, so `--point 1 2 3` would otherwise leave "2" and "3"
  # as positionals. This pulls the matched flag and up to `max` following value
  # tokens out of argv and returns `{%{point: [1, 2, 3]}, residual_argv}`.
  # Collection stops at the next flag-looking token (one starting with "-"),
  # at "--", or once `max` values are taken.
  #
  # `head?` mirrors OptionParser.parse_head: when true (external_subcommands),
  # extraction stops at the first positional token so the external subcommand
  # name and its args are left untouched for parse_head.
  defp extract_num_args(argv, options, head? \\ false) do
    num_args_opts = Enum.filter(options, fn {_name, o} -> Keyword.has_key?(o, :num_args) end)

    if num_args_opts == [] do
      {%{}, argv}
    else
      do_extract_num_args(argv, num_args_lookup(num_args_opts), %{}, [], head?)
    end
  end

  # Options with `allow_hyphen_values: true` that take a single value (not
  # num_args, boolean, or count) must have their value pulled out before
  # OptionParser, which would otherwise treat a `-`-prefixed value as a flag.
  #
  # `head?` (external_subcommands) stops extraction at the first positional so
  # the external subcommand name and its args are left for parse_head.
  defp extract_hyphen_values(argv, options, head? \\ false) do
    hyphen_opts = Enum.filter(options, &single_value_hyphen_opt?/1)

    if hyphen_opts == [] do
      {%{}, argv}
    else
      do_extract_hyphen_values(argv, num_args_lookup(hyphen_opts), %{}, [], head?)
    end
  end

  defp single_value_hyphen_opt?({_name, o}) do
    Keyword.get(o, :allow_hyphen_values, false) and
      not Keyword.has_key?(o, :num_args) and
      Keyword.get(o, :type, :string) not in [:boolean, :count]
  end

  defp do_extract_hyphen_values([], _lookup, collected, residual, _head?),
    do: {collected, Enum.reverse(residual)}

  defp do_extract_hyphen_values(["--" | rest], _lookup, collected, residual, _head?),
    do: {collected, Enum.reverse(residual) ++ ["--" | rest]}

  defp do_extract_hyphen_values([token | rest] = all, lookup, collected, residual, head?) do
    case num_args_flag(token, lookup) do
      {{name, opts}, nil} ->
        case rest do
          [value | rest2] ->
            collected = Map.put(collected, name, coerce_arg(value, opts))
            do_extract_hyphen_values(rest2, lookup, collected, residual, head?)

          [] ->
            # Flag with no following value: leave it for the normal parse path.
            do_extract_hyphen_values([], lookup, collected, [token | residual], head?)
        end

      {{name, opts}, inline} ->
        collected = Map.put(collected, name, coerce_arg(inline, opts))
        do_extract_hyphen_values(rest, lookup, collected, residual, head?)

      :nomatch ->
        # In head mode the first positional is the external subcommand: stop.
        if head? and not String.starts_with?(token, "-") do
          {collected, Enum.reverse(residual) ++ all}
        else
          do_extract_hyphen_values(rest, lookup, collected, [token | residual], head?)
        end
    end
  end

  defp num_args_lookup(num_args_opts) do
    Enum.flat_map(num_args_opts, fn {name, opts} = entry ->
      long = [{"--#{flag_string(name)}", entry}]

      short =
        case Keyword.get(opts, :short) do
          nil -> []
          s -> [{"-#{s}", entry}]
        end

      aliases =
        Enum.map(Keyword.get(opts, :aliases, []), fn a -> {"--#{flag_string(a)}", entry} end)

      long ++ short ++ aliases
    end)
    |> Map.new()
  end

  defp do_extract_num_args([], _lookup, collected, residual, _head?),
    do: {collected, Enum.reverse(residual)}

  defp do_extract_num_args(["--" | rest], _lookup, collected, residual, _head?),
    do: {collected, Enum.reverse(residual) ++ ["--" | rest]}

  defp do_extract_num_args([token | rest] = all, lookup, collected, residual, head?) do
    case num_args_flag(token, lookup) do
      {{name, opts}, inline} ->
        {_min, max} = num_args_bounds(Keyword.fetch!(opts, :num_args))

        {raw_values, rest2} =
          case inline do
            nil ->
              take_num_args_values(rest, max, [], Keyword.get(opts, :allow_hyphen_values, false))

            value ->
              {[value], rest}
          end

        values = Enum.map(raw_values, &coerce_arg(&1, opts))
        do_extract_num_args(rest2, lookup, Map.put(collected, name, values), residual, head?)

      :nomatch ->
        # In head mode the first positional is the external subcommand: stop and
        # hand it (plus the rest) to parse_head. Option-looking tokens are parent
        # flags, so keep scanning past them.
        if head? and not String.starts_with?(token, "-") do
          {collected, Enum.reverse(residual) ++ all}
        else
          do_extract_num_args(rest, lookup, collected, [token | residual], head?)
        end
    end
  end

  # Resolve a token to a num_args option. Returns `{entry, inline_value}` where
  # inline_value is the part after `=` for the `--flag=value` form, or nil for
  # the space-separated form.
  defp num_args_flag(token, lookup) do
    cond do
      Map.has_key?(lookup, token) ->
        {Map.fetch!(lookup, token), nil}

      String.starts_with?(token, "--") and String.contains?(token, "=") ->
        [flag, value] = String.split(token, "=", parts: 2)

        case Map.fetch(lookup, flag) do
          {:ok, entry} -> {entry, value}
          :error -> :nomatch
        end

      true ->
        :nomatch
    end
  end

  defp take_num_args_values(tokens, max, acc, _allow_hyphen?) when length(acc) >= max,
    do: {Enum.reverse(acc), tokens}

  defp take_num_args_values([], _max, acc, _allow_hyphen?), do: {Enum.reverse(acc), []}

  defp take_num_args_values(["--" | _] = tokens, _max, acc, _allow_hyphen?),
    do: {Enum.reverse(acc), tokens}

  defp take_num_args_values([token | rest], max, acc, allow_hyphen?) do
    # Stop at a flag-looking token, unless the option opted into hyphen values or
    # the token is a negative number (always a value in a num_args context, never
    # a flag).
    if flag_like?(token) and not allow_hyphen? and not negative_number?(token) do
      {Enum.reverse(acc), [token | rest]}
    else
      take_num_args_values(rest, max, [token | acc], allow_hyphen?)
    end
  end

  defp flag_like?(token), do: String.starts_with?(token, "-") and token != "-"
  defp negative_number?(token), do: Regex.match?(~r/^-\d+(\.\d+)?$/, token)

  defp validate_num_args(num_args_values, options) do
    Enum.reduce_while(num_args_values, :ok, fn {name, values}, _acc ->
      case Keyword.fetch(Keyword.get(options, name, []), :num_args) do
        :error ->
          {:cont, :ok}

        {:ok, spec} ->
          {min, max} = num_args_bounds(spec)
          got = length(values)

          if got >= min and got <= max do
            {:cont, :ok}
          else
            {:halt, {:error, num_args_error(name, min, max, got)}}
          end
      end
    end)
  end

  defp num_args_bounds(n) when is_integer(n), do: {n, n}

  defp num_args_bounds(%Range{first: first, last: last}),
    do: {min(first, last), max(first, last)}

  defp num_args_error(name, min, max, got) when min == max,
    do: "--#{flag_string(name)} expects #{min} value(s), got #{got}"

  defp num_args_error(name, min, max, got),
    do: "--#{flag_string(name)} expects between #{min} and #{max} values, got #{got}"

  defp flag_string(name) when is_atom(name),
    do: name |> Atom.to_string() |> String.replace("_", "-")

  # -- OptionParser spec --

  defp build_option_parser_spec(options) do
    spec =
      Enum.map(options, fn {name, opts} ->
        type = parser_type(opts)

        if Keyword.get(opts, :multi, false) do
          {name, [type, :keep]}
        else
          {name, type}
        end
      end)

    # Long-form option aliases get added as separate spec entries
    # that OptionParser will parse, then we remap them in build_parsed_map
    alias_specs =
      options
      |> Enum.filter(fn {_name, opts} -> Keyword.has_key?(opts, :aliases) end)
      |> Enum.flat_map(fn {_name, opts} ->
        type = parser_type(opts)

        type_spec =
          if Keyword.get(opts, :multi, false), do: [type, :keep], else: type

        Enum.map(Keyword.fetch!(opts, :aliases), fn a -> {a, type_spec} end)
      end)

    aliases =
      options
      |> Enum.filter(fn {_name, opts} -> Keyword.has_key?(opts, :short) end)
      |> Enum.map(fn {name, opts} -> {Keyword.fetch!(opts, :short), name} end)

    {spec ++ alias_specs, aliases}
  end

  # value_delimiter options are parsed as raw strings so OptionParser does not
  # try to coerce the whole "a,b,c" token; splitting and per-element coercion
  # happen afterward in apply_value_delimiters/2.
  defp parser_type(opts) do
    if Keyword.has_key?(opts, :value_delimiter) do
      :string
    else
      Keyword.get(opts, :type, :string)
    end
  end

  defp build_parsed_map(parsed, options) do
    multi_names =
      for {name, opts} <- options, Keyword.get(opts, :multi, false), into: MapSet.new(), do: name

    # Build alias -> primary name mapping
    alias_map =
      options
      |> Enum.filter(fn {_name, opts} -> Keyword.has_key?(opts, :aliases) end)
      |> Enum.flat_map(fn {name, opts} ->
        Enum.map(Keyword.fetch!(opts, :aliases), fn a -> {a, name} end)
      end)
      |> Map.new()

    Enum.reduce(parsed, %{}, fn {key, value}, acc ->
      # Remap alias to primary name
      primary = Map.get(alias_map, key, key)

      if MapSet.member?(multi_names, primary) do
        Map.update(acc, primary, [value], &(&1 ++ [value]))
      else
        Map.put(acc, primary, value)
      end
    end)
  end

  # -- Help / version detection --

  # True if one of `targets` appears before a `--` terminator. Everything after
  # `--` is a literal positional, so `tool -- --help` treats --help as an arg
  # rather than a help request (matching conventional CLI behavior).
  defp flag_requested?(argv, targets) do
    argv
    |> Enum.take_while(&(&1 != "--"))
    |> Enum.any?(&(&1 in targets))
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

    # Hidden commands stay dispatchable but are not advertised in suggestions or
    # the available-commands list.
    visible =
      Enum.reject(meta.subcommands, fn sub ->
        Map.get(sub.__cheer_meta__(), :hide, false)
      end)

    # "Did you mean?" suggestion
    if visible != [] do
      names =
        Enum.flat_map(visible, fn sub ->
          sub_meta = sub.__cheer_meta__()
          [sub_meta.name | Map.get(sub_meta, :aliases, [])]
        end)

      case suggest(token, names) do
        nil -> :ok
        suggestion -> IO.puts("\n  Did you mean '#{suggestion}'?")
      end

      IO.puts("\nAvailable commands:")

      for sub <- visible do
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

  defp print_invalid_options_error(command, invalid, opts, all_options) do
    flags = Enum.map_join(invalid, ", ", fn {flag, _} -> flag end)
    IO.puts("error: unknown option(s): #{flags}")

    candidates = option_name_candidates(all_options)

    Enum.each(invalid, fn {flag, _value} ->
      # Exclude an exact match so a known option given a bad value (OptionParser
      # reports it in `invalid` too) does not suggest the flag the user typed.
      with "--" <> name <- flag,
           suggestion when not is_nil(suggestion) <- suggest(name, candidates -- [name]) do
        IO.puts("\n  Did you mean '--#{suggestion}'?")
      else
        _ -> :ok
      end
    end)

    IO.puts("")
    Cheer.Help.print(command, opts)
  end

  defp option_name_candidates(all_options) do
    Enum.flat_map(all_options, fn {name, opts} ->
      [flag_string(name) | Enum.map(Keyword.get(opts, :aliases, []), &flag_string/1)]
    end)
  end
end

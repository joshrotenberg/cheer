defmodule Cheer.Command.DSL do
  @moduledoc """
  Macros for declaring commands, arguments, options, subcommands,
  lifecycle hooks, param groups, and validation.
  """

  @doc """
  Define a command block with the given `name`.

  All DSL calls (`about`, `argument`, `option`, `subcommand`, etc.) go inside the block.

      command "deploy" do
        about "Deploy the app"
        option :env, type: :string, required: true
      end
  """
  defmacro command(name, do: block) do
    quote do
      @cheer_command_name unquote(name)
      unquote(block)
    end
  end

  @doc "Set the command's description text, shown in help output."
  defmacro about(text), do: quote(do: @cheer_about(unquote(text)))

  @doc "Set the command's version string, printed by `--version` / `-V`."
  defmacro version(text), do: quote(do: @cheer_version(unquote(text)))

  @doc "Register a child subcommand module."
  defmacro subcommand(module), do: quote(do: @cheer_subcommands(unquote(module)))

  @doc """
  Declare a positional argument.

  Arguments are matched in declaration order. Options:

    * `:type` - `:string` (default), `:integer`, `:float`, or `:boolean`
    * `:required` - `true` or `false` (default)
    * `:help` - help text shown in `--help`
    * `:validate` - `fn value -> :ok | {:error, msg} end`
  """
  defmacro argument(name, opts \\ []) do
    {validate_ast, clean_opts} = Keyword.pop(opts, :validate)

    if validate_ast do
      fname = :"__cheer_validate_#{name}__"

      quote do
        @cheer_arguments {unquote(name), unquote(Macro.escape(clean_opts))}
        @cheer_has_validate unquote(name)
        def unquote(fname)(val), do: unquote(validate_ast).(val)
      end
    else
      quote do
        @cheer_arguments {unquote(name), unquote(Macro.escape(clean_opts))}
      end
    end
  end

  @doc """
  Declare a named option (flag).

  Options:

    * `:type` - `:string` (default), `:integer`, `:float`, `:boolean`, or `:count`
    * `:short` - single-character alias atom (e.g. `:p` for `-p`)
    * `:required` - `true` or `false` (default)
    * `:default` - default value when not provided (`:count` defaults to `0`, `:multi` defaults to `[]`)
    * `:multi` - `true` to allow repeated flags collected into a list (e.g. `--tag a --tag b`)
    * `:env` - environment variable name to read as fallback
    * `:choices` - list of allowed values
    * `:help` - help text shown in `--help`
    * `:validate` - `fn value -> :ok | {:error, msg} end`

  Boolean options automatically support `--no-<name>` negation (e.g. `--no-color`).

  Extra positional arguments after `--` are collected into `args[:rest]`.
  """
  defmacro option(name, opts \\ []) do
    {validate_ast, clean_opts} = Keyword.pop(opts, :validate)

    base =
      if validate_ast do
        fname = :"__cheer_validate_#{name}__"

        quote do
          @cheer_options {unquote(name), unquote(Macro.escape(clean_opts))}
          @cheer_has_validate unquote(name)
          def unquote(fname)(val), do: unquote(validate_ast).(val)
        end
      else
        quote do
          @cheer_options {unquote(name), unquote(Macro.escape(clean_opts))}
        end
      end

    quote do
      unquote(base)

      # If inside a group block, register this option in the group
      if @cheer_current_group do
        {group_name, group_opts} = @cheer_current_group
        @cheer_groups {group_name, group_opts, unquote(name)}
      end
    end
  end

  @doc "Cross-parameter validation function. Receives args map, returns `:ok` or `{:error, msg}`."
  defmacro validate(fun) do
    quote do
      count = Module.get_attribute(__MODULE__, :cheer_validator_count)
      Module.put_attribute(__MODULE__, :cheer_validator_count, count + 1)

      def __cheer_cross_validate__(unquote(Macro.var(:count, __MODULE__)), args) do
        unquote(fun).(args)
      end
    end
  end

  # -- Lifecycle hooks --

  @doc "Run a function on args before `run/2`. Receives and returns args map."
  defmacro before_run(fun) do
    quote do
      count = Module.get_attribute(__MODULE__, :cheer_before_run_count)
      Module.put_attribute(__MODULE__, :cheer_before_run_count, count + 1)

      def __cheer_before_run__(unquote(Macro.var(:count, __MODULE__)), args) do
        unquote(fun).(args)
      end
    end
  end

  @doc "Run a function on the result after `run/2`. Receives and returns result."
  defmacro after_run(fun) do
    quote do
      count = Module.get_attribute(__MODULE__, :cheer_after_run_count)
      Module.put_attribute(__MODULE__, :cheer_after_run_count, count + 1)

      def __cheer_after_run__(unquote(Macro.var(:count, __MODULE__)), result) do
        unquote(fun).(result)
      end
    end
  end

  @doc "Like `before_run`, but inherited by all child subcommands."
  defmacro persistent_before_run(fun) do
    quote do
      count = Module.get_attribute(__MODULE__, :cheer_persistent_before_run_count)
      Module.put_attribute(__MODULE__, :cheer_persistent_before_run_count, count + 1)

      def __cheer_persistent_before_run__(unquote(Macro.var(:count, __MODULE__)), args) do
        unquote(fun).(args)
      end
    end
  end

  # -- Param groups --

  @doc """
  Define a named group of options with a constraint.

  Supports:
    * `mutually_exclusive: true` -- at most one option in the group can be set
    * `co_occurring: true` -- all or none of the options must be set
  """
  defmacro group(name, opts, do: block) do
    quote do
      @cheer_current_group {unquote(name), unquote(opts)}
      unquote(block)
      @cheer_current_group nil
    end
  end
end

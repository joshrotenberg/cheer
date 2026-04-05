defmodule Cheer.Command do
  @moduledoc """
  Behaviour and macros for defining CLI commands.

  A command is a module that declares its name, description, arguments, options,
  and subcommands. Commands compose into trees of arbitrary depth.

  ## Example

      defmodule MyApp.CLI.Deploy do
        use Cheer.Command

        command "deploy" do
          about "Deploy to an environment"

          subcommand MyApp.CLI.Deploy.Staging
          subcommand MyApp.CLI.Deploy.Production
        end
      end

  Leaf commands (those with no subcommands) must implement `run/2`.
  Branch commands (those with subcommands) route to children automatically.
  """

  @doc """
  Called when this command is matched and has no further subcommands to dispatch to.
  Receives parsed arguments/options and raw remaining argv.
  """
  @callback run(args :: map(), raw :: [String.t()]) :: term()

  @optional_callbacks [run: 2]

  defmacro __using__(_opts) do
    quote do
      @behaviour Cheer.Command

      import Cheer.Command.DSL

      Module.register_attribute(__MODULE__, :cheer_command_name, accumulate: false)
      Module.register_attribute(__MODULE__, :cheer_about, accumulate: false)
      Module.register_attribute(__MODULE__, :cheer_long_about, accumulate: false)
      Module.register_attribute(__MODULE__, :cheer_version, accumulate: false)
      Module.register_attribute(__MODULE__, :cheer_before_help, accumulate: false)
      Module.register_attribute(__MODULE__, :cheer_after_help, accumulate: false)
      Module.register_attribute(__MODULE__, :cheer_aliases, accumulate: false)
      Module.register_attribute(__MODULE__, :cheer_arguments, accumulate: true)
      Module.register_attribute(__MODULE__, :cheer_options, accumulate: true)
      Module.register_attribute(__MODULE__, :cheer_subcommands, accumulate: true)
      Module.register_attribute(__MODULE__, :cheer_has_validate, accumulate: true)
      Module.register_attribute(__MODULE__, :cheer_groups, accumulate: true)

      # Counters for indexed function generation
      Module.put_attribute(__MODULE__, :cheer_validator_count, 0)
      Module.put_attribute(__MODULE__, :cheer_before_run_count, 0)
      Module.put_attribute(__MODULE__, :cheer_after_run_count, 0)
      Module.put_attribute(__MODULE__, :cheer_persistent_before_run_count, 0)

      # Current group context (set by `group` macro)
      Module.put_attribute(__MODULE__, :cheer_current_group, nil)

      @before_compile Cheer.Command.Compiler
    end
  end
end

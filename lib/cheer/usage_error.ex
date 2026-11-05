defmodule Cheer.UsageError do
  @moduledoc """
  A usage failure returned by `Cheer.parse/3` or `Cheer.run/3` with `errors: :return`.

  `kind` identifies the failure. `names` contains declared parameter names as
  atoms, or raw option/command tokens as strings when no declaration matches.
  It is empty for a missing subcommand or a command-level validator, which
  supplies only a message. `message` is plain text without an `error:` prefix,
  ANSI styling, help output, or suggestions.
  """

  @type kind ::
          :unknown_option
          | :invalid_value
          | :missing_required
          | :positional_count
          | :invalid
          | :unknown_command
          | :ambiguous_command
          | :subcommand_required

  @type t :: %__MODULE__{
          kind: kind(),
          names: [atom() | String.t()],
          message: String.t()
        }

  @enforce_keys [:kind, :names, :message]
  defstruct [:kind, :names, :message]
end

defmodule Cheer.Test do
  @moduledoc """
  In-process test runner for CLI commands.

  Invokes a command capturing stdout and return value, without spawning a subprocess.

  ## Usage

      result = Cheer.Test.run(MyCommand, ["--port", "8080"])
      assert result.return == {:ok, %{port: 8080}}
      assert result.output == ""
  """

  defstruct [:return, :output]

  @type t :: %__MODULE__{
          return: term(),
          output: String.t()
        }

  @doc """
  Run a command with the given argv, capturing output and return value.
  """
  @spec run(module(), [String.t()], keyword()) :: t()
  def run(command, argv, opts \\ []) do
    caller = self()

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        result = Cheer.run(command, argv, opts)
        send(caller, {:cheer_test_result, result})
      end)

    return =
      receive do
        {:cheer_test_result, result} -> result
      after
        0 -> nil
      end

    %__MODULE__{return: return, output: output}
  end
end

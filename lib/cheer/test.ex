defmodule Cheer.Test do
  @moduledoc """
  In-process test runner for CLI commands.

  Invokes a command capturing stdout, stderr, and the return value, without
  spawning a subprocess. Usage errors and the help printed after them go to
  stderr, so they appear in `error_output`; requested help and command output
  appear in `output`.

  ## Usage

      result = Cheer.Test.run(MyCommand, ["--port", "8080"])
      assert result.return == {:ok, %{port: 8080}}
      assert result.output == ""

      result = Cheer.Test.run(MyCommand, ["--bogus"])
      assert result.error_output =~ "unknown option"
  """

  defstruct [:return, :output, :error_output]

  @type t :: %__MODULE__{
          return: term(),
          output: String.t(),
          error_output: String.t()
        }

  @doc """
  Run a command with the given argv, capturing output and return value.
  """
  @spec run(module(), [String.t()], keyword()) :: t()
  def run(command, argv, opts \\ []) do
    caller = self()

    error_output =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        output =
          ExUnit.CaptureIO.capture_io(fn ->
            send(caller, {:cheer_test_result, Cheer.run(command, argv, opts)})
          end)

        send(caller, {:cheer_test_output, output})
      end)

    output = receive_tagged(:cheer_test_output, "")
    return = receive_tagged(:cheer_test_result, nil)

    %__MODULE__{return: return, output: output, error_output: error_output}
  end

  defp receive_tagged(tag, default) do
    receive do
      {^tag, value} -> value
    after
      0 -> default
    end
  end
end

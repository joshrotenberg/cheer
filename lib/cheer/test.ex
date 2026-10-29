defmodule Cheer.Test do
  @moduledoc """
  In-process test runner for CLI commands.

  Invokes a command capturing stdout, stderr, and the return value, without
  spawning a subprocess. `output` is what the call wrote to stdout. `error_output`
  is what cheer itself wrote as diagnostics: usage errors, suggestions, the help
  printed after an error, and deprecation warnings. It goes to a device private
  to the call, so it holds nothing from other processes and is safe to assert
  on in `async: true` tests. What a command's own `run/2` writes to `:stderr` is
  not included; capture that with `ExUnit.CaptureIO.capture_io(:stderr, ...)`.

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

    {:ok, device} = StringIO.open("")
    previous = Process.put(:cheer_error_device, device)

    try do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          send(caller, {:cheer_test_result, Cheer.run(command, argv, opts)})
        end)

      {_input, error_output} = StringIO.contents(device)
      return = receive_tagged(:cheer_test_result, nil)

      %__MODULE__{return: return, output: output, error_output: error_output}
    after
      restore_error_device(previous)
      StringIO.close(device)
    end
  end

  defp restore_error_device(nil), do: Process.delete(:cheer_error_device)
  defp restore_error_device(device), do: Process.put(:cheer_error_device, device)

  defp receive_tagged(tag, default) do
    receive do
      {^tag, value} -> value
    after
      0 -> default
    end
  end
end

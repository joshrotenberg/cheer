defmodule Cheer.TestRunnerTest do
  # Async on purpose: error_output must be safe to assert on beside other tests.
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  defmodule Leaf do
    use Cheer.Command

    command "leaf" do
      about("A leaf command")
      option(:old, type: :boolean, deprecated: "use --new", help: "Old flag")
      option(:new, type: :boolean, help: "New flag")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule Noisy do
    use Cheer.Command

    command "noisy" do
      about("Another process writes to stderr while this one runs")
    end

    @impl Cheer.Command
    def run(_args, _raw) do
      Task.async(fn -> IO.puts(:stderr, "noise from another process") end) |> Task.await()
      :ok
    end
  end

  test "error_output holds the usage error for this call" do
    result = Cheer.Test.run(Leaf, ["--bogus"])
    assert result.return == {:error, :usage}
    assert result.output == ""
    assert result.error_output =~ ~r/\Aerror: unknown option\(s\): --bogus/
  end

  test "error_output holds deprecation warnings" do
    result = Cheer.Test.run(Leaf, ["--old"])
    assert {:ok, %{old: true}} = result.return
    assert result.error_output =~ "--old is deprecated: use --new"
  end

  test "stderr written by other processes is not in error_output" do
    # The outer capture keeps the noise off the terminal; Cheer.Test.run must
    # not see it.
    noise =
      capture_io(:stderr, fn ->
        result = Cheer.Test.run(Noisy, [])
        assert result.return == :ok
        assert result.error_output == ""
      end)

    assert noise =~ "noise from another process"
  end

  test "concurrent calls each see only their own errors" do
    results =
      1..20
      |> Enum.map(fn i -> Task.async(fn -> {i, Cheer.Test.run(Leaf, ["--bogus-#{i}"])} end) end)
      |> Enum.map(&Task.await/1)

    for {i, result} <- results do
      assert result.error_output =~ "--bogus-#{i}"
      refute result.error_output =~ ~r/--bogus-(?!#{i}\b)\d+/
    end
  end

  test "the error device is restored after the call" do
    Cheer.Test.run(Leaf, ["--bogus"])
    assert Process.get(:cheer_error_device) == nil
  end
end

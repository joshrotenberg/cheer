defmodule Cheer.OutputStreamsTest do
  # Not async: capture_io(:stderr) sees stderr from every process, so these
  # assertions that stderr is empty must not run beside other tests.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  defmodule Leaf do
    use Cheer.Command

    command "leaf" do
      about("A leaf command")
      version("1.2.3")
      argument(:name, type: :string, required: true)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule Branch do
    use Cheer.Command

    command "branch" do
      about("A parent command")
      subcommand(Cheer.OutputStreamsTest.Leaf)
    end
  end

  defp streams(fun) do
    parent = self()
    err = capture_io(:stderr, fn -> send(parent, {:stdout, capture_io(fun)}) end)

    receive do
      {:stdout, out} -> {out, err}
    end
  end

  test "an unknown option goes to stderr, with nothing on stdout" do
    {out, err} = streams(fn -> Cheer.run(Leaf, ["x", "--bogus"]) end)
    assert out == ""
    assert err =~ "unknown option(s): --bogus"
    assert err =~ "Usage:"
  end

  test "a missing argument goes to stderr" do
    {out, err} = streams(fn -> Cheer.run(Leaf, []) end)
    assert out == ""
    assert err =~ "missing required"
  end

  test "an unknown command goes to stderr" do
    {out, err} = streams(fn -> Cheer.run(Branch, ["zzzzz"]) end)
    assert out == ""
    assert err =~ "unknown command"
  end

  test "requested help goes to stdout" do
    {out, err} = streams(fn -> Cheer.run(Leaf, ["--help"]) end)
    assert out =~ "Usage:"
    assert err == ""
  end

  test "version goes to stdout" do
    {out, err} = streams(fn -> Cheer.run(Leaf, ["--version"]) end)
    assert out =~ "1.2.3"
    assert err == ""
  end

  test "bare invocation of a parent prints help to stdout" do
    {out, err} = streams(fn -> Cheer.run(Branch, []) end)
    assert out =~ "Usage:"
    assert err == ""
  end

  test "Cheer.Test.run/3 separates the streams" do
    result = Cheer.Test.run(Leaf, ["x", "--bogus"])
    assert result.return == {:error, :usage}
    assert result.output == ""
    assert result.error_output =~ "unknown option(s): --bogus"
  end
end

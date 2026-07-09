defmodule Cheer.AnsiTest do
  # async: false because these tests toggle the global :elixir :ansi_enabled flag.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  defmodule ColorCmd do
    use Cheer.Command

    command "c" do
      about("demo")
      option(:port, type: :integer, short: :p, help: "Port")
    end

    @impl Cheer.Command
    def run(_args, _raw), do: :ok
  end

  setup do
    prev = Application.get_env(:elixir, :ansi_enabled)
    Application.put_env(:elixir, :ansi_enabled, true)
    System.delete_env("NO_COLOR")
    on_exit(fn -> Application.put_env(:elixir, :ansi_enabled, prev) end)
    :ok
  end

  test "paint emits ANSI codes when enabled" do
    assert Cheer.Ansi.paint("x", :red) == "\e[31mx\e[0m"
  end

  test "visible_length ignores the ANSI codes it adds" do
    assert Cheer.Ansi.visible_length(Cheer.Ansi.paint("hello", :cyan)) == 5
  end

  test "NO_COLOR disables styling even when a tty is available" do
    System.put_env("NO_COLOR", "1")
    on_exit(fn -> System.delete_env("NO_COLOR") end)

    refute Cheer.Ansi.enabled?()
    assert Cheer.Ansi.paint("x", :red) == "x"
  end

  test "help output is colorized: bold heading and cyan flag" do
    out = capture_io(fn -> Cheer.run(ColorCmd, ["--help"]) end)
    assert out =~ "\e[1mOPTIONS:"
    assert out =~ "\e[36m"
  end

  test "error output has a red error prefix" do
    err = capture_io(fn -> Cheer.run(ColorCmd, ["--nope", "x"]) end)
    assert err =~ "\e[31merror:"
  end
end

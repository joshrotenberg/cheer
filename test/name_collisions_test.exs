defmodule Cheer.NameCollisionsTest do
  # Not async: compile-time warnings are read from stderr, which
  # capture_io(:stderr) shares with every running process.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  # -- Within one command: compile-time warning --------------------------------

  defp compile_warnings(source) do
    capture_io(:stderr, fn -> Code.compile_string(source) end)
  end

  test "an argument and an option with the same name warn at compile time" do
    warnings =
      compile_warnings("""
      defmodule Cheer.NameCollisionsTest.ArgAndOpt do
        use Cheer.Command

        command "argopt" do
          argument :name, type: :string
          option :name, type: :string
        end

        def run(args, _raw), do: args
      end
      """)

    assert warnings =~ "Cheer.NameCollisionsTest.ArgAndOpt"
    assert warnings =~ ":name"
  end

  test "a trailing var arg and an option with the same name warn at compile time" do
    warnings =
      compile_warnings("""
      defmodule Cheer.NameCollisionsTest.TrailingAndOpt do
        use Cheer.Command

        command "trailing" do
          trailing_var_arg :files
          option :files, type: :string
        end

        def run(args, _raw), do: args
      end
      """)

    assert warnings =~ ":files"
  end

  test "distinct names compile without a collision warning" do
    warnings =
      compile_warnings("""
      defmodule Cheer.NameCollisionsTest.Distinct do
        use Cheer.Command

        command "distinct" do
          argument :source, type: :string
          option :file, type: :string
          trailing_var_arg :args
        end

        def run(args, _raw), do: args
      end
      """)

    refute warnings =~ "share"
  end

  # -- Against an inherited global: raised at dispatch -------------------------

  defmodule PositionalChild do
    use Cheer.Command

    command "erl" do
      about("Has a positional named like the parent's global")
      argument(:file, type: :string, required: true)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TrailingChild do
    use Cheer.Command

    command "many" do
      about("Has a trailing var arg named like the parent's global")
      trailing_var_arg(:file)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule OverrideChild do
    use Cheer.Command

    command "override" do
      about("Redeclares the parent's global as its own option")
      option(:file, type: :string, help: "Local file")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule Root do
    use Cheer.Command

    command "jot" do
      about("Root with a global option")
      option(:file, type: :string, short: :f, global: true)

      subcommand(Cheer.NameCollisionsTest.PositionalChild)
      subcommand(Cheer.NameCollisionsTest.TrailingChild)
      subcommand(Cheer.NameCollisionsTest.OverrideChild)
    end
  end

  test "a positional named like an inherited global raises at dispatch" do
    error =
      assert_raise ArgumentError, fn ->
        Cheer.run(Root, ["-f", "notes.json", "erl", "hello.erl"])
      end

    assert error.message =~ ":file"
    assert error.message =~ "PositionalChild"
  end

  test "the collision raises even when the global is not passed" do
    assert_raise ArgumentError, fn -> Cheer.run(Root, ["erl", "hello.erl"]) end
  end

  test "the collision raises in parse mode too" do
    assert_raise ArgumentError, fn -> Cheer.parse(Root, ["erl", "hello.erl"]) end
  end

  test "a trailing var arg named like an inherited global raises at dispatch" do
    assert_raise ArgumentError, ~r/:file/, fn -> Cheer.run(Root, ["many", "a", "b"]) end
  end

  test "redeclaring the global as a local option is still an override" do
    assert {:ok, %{file: "local.json"}} =
             Cheer.run(Root, ["override", "--file", "local.json"])
  end
end

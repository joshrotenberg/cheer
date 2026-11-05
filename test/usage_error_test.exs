defmodule Cheer.UsageErrorTest do
  # stderr capture is global, so silence assertions must not run concurrently.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Cheer.UsageError

  defmodule Leaf do
    use Cheer.Command

    command "leaf" do
      version("1.2.3")
      option(:wait_ms, type: :integer, short: :w, aliases: [:delay])
      option(:format, type: :string, choices: ["json", "text"])
      option(:point, type: :integer, num_args: 2)
      option(:mode, parse: fn _ -> {:error, "unsupported mode"} end)
      option(:port, type: :integer, validate: fn _ -> {:error, "port rejected"} end)
      option(:source, requires: :destination)
      option(:destination)
      option(:quiet, type: :boolean, conflicts_with: :verbose)
      option(:verbose, type: :boolean)
      option(:token, required_if: [format: "json"])

      group :output, mutually_exclusive: true do
        option(:json, type: :boolean)
        option(:csv, type: :boolean)
      end

      argument(:environment, choices: ["dev", "prod"])
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule Required do
    use Cheer.Command

    command "required" do
      argument(:input, required: true)
      option(:output, required: true)
      trailing_var_arg(:files, required: true)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule Positionals do
    use Cheer.Command

    command "positionals" do
      argument(:coords, num_args: 2)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule CrossValidated do
    use Cheer.Command

    command "cross-validated" do
      validate(fn _ -> {:error, "parameters do not agree"} end)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule External do
    use Cheer.Command

    command "external" do
      external_subcommands(true)
      option(:wait_ms, type: :integer, short: :w)
      option(:token, required: true)
      option(:format, choices: ["json"])
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule Deprecated do
    use Cheer.Command

    command "legacy" do
      deprecated("use leaf")
      argument(:input, required: true)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule Branch do
    use Cheer.Command

    command "branch" do
      infer_subcommands(true)
      subcommand_required(true)
      option(:wait_ms, type: :integer, global: true, short: :w, aliases: [:delay])
      option(:config, aliases: [:settings])
      subcommand(Cheer.UsageErrorTest.Leaf)
      subcommand(Cheer.UsageErrorTest.Deprecated)
    end
  end

  defp streams(fun) do
    caller = self()
    ref = make_ref()

    stderr =
      capture_io(:stderr, fn ->
        stdout = capture_io(fn -> send(caller, {ref, :result, fun.()}) end)
        send(caller, {ref, :stdout, stdout})
      end)

    assert_receive {^ref, :result, result}
    assert_receive {^ref, :stdout, stdout}
    {result, stdout, stderr}
  end

  defp assert_usage_error(command, argv, kind, names, expected_message \\ nil) do
    for entrypoint <- [:parse, :run] do
      {result, stdout, stderr} =
        streams(fn -> apply(Cheer, entrypoint, [command, argv, [errors: :return]]) end)

      assert {:error, %UsageError{kind: ^kind, names: ^names, message: message}} = result
      assert is_binary(message) and message != ""
      refute message =~ "\e["
      if expected_message, do: assert(message == expected_message)
      assert stdout == ""
      assert stderr == ""
    end
  end

  test "unknown options return raw tokens without help or suggestions" do
    assert_usage_error(Leaf, ["--formt", "--bogus"], :unknown_option, ["--formt", "--bogus"])
  end

  test "invalid integer values return the declared option name" do
    assert_usage_error(Leaf, ["--wait-ms", "wrong"], :invalid_value, [:wait_ms])
  end

  test "invalid values supplied through long aliases use the declared name" do
    assert_usage_error(Leaf, ["--delay", "wrong"], :invalid_value, [:wait_ms])
  end

  test "invalid values supplied through short aliases use the declared name" do
    assert_usage_error(Leaf, ["-w", "wrong"], :invalid_value, [:wait_ms])
  end

  test "invalid values for negated boolean flags use the declared name" do
    assert_usage_error(Leaf, ["--no-verbose=wrong"], :invalid_value, [:verbose])
  end

  test "missing option values and aliases identify the declared option" do
    for flag <- ["--wait-ms", "-w", "--delay"] do
      assert_usage_error(Leaf, [flag], :invalid_value, [:wait_ms], "missing value for --wait-ms")
    end
  end

  test "invalid values deduplicate the declared name across aliases" do
    assert_usage_error(Leaf, ["--wait-ms", "a", "-w", "b"], :invalid_value, [:wait_ms])
  end

  test "invalid value names preserve first occurrence order across aliases" do
    assert_usage_error(
      Leaf,
      ["--port", "bad", "--wait-ms", "a", "-w", "b", "--port", "wrong"],
      :invalid_value,
      [:port, :wait_ms]
    )

    assert_usage_error(
      Leaf,
      ["--wait-ms", "a", "--port", "bad", "-w", "b"],
      :invalid_value,
      [:wait_ms, :port]
    )
  end

  test "unknown option names are unique and preserve first occurrence order" do
    assert_usage_error(
      Leaf,
      ["--bogus", "--nope", "--bogus"],
      :unknown_option,
      ["--bogus", "--nope"]
    )
  end

  test "missing required arguments and options return declared names" do
    assert_usage_error(Required, [], :missing_required, [:input, :output, :files])
  end

  test "positional count errors return the declared argument name" do
    assert_usage_error(Positionals, ["1"], :positional_count, [:coords])
  end

  test "custom parser errors identify their parameter" do
    assert_usage_error(Leaf, ["--mode", "bad"], :invalid, [:mode])
  end

  test "custom validation errors identify their parameter without parsing the message" do
    assert_usage_error(Leaf, ["--port", "1"], :invalid, [:port])
  end

  test "choice errors identify an option" do
    assert_usage_error(Leaf, ["--format", "xml"], :invalid, [:format])
  end

  test "choice errors identify a positional argument" do
    assert_usage_error(Leaf, ["staging"], :invalid, [:environment])
  end

  test "option value count errors identify the option" do
    assert_usage_error(Leaf, ["--point", "1"], :invalid, [:point])
  end

  test "conditional required errors identify the required option" do
    assert_usage_error(Leaf, ["--format", "json"], :invalid, [:token])
  end

  test "requires errors identify both parameters" do
    assert_usage_error(Leaf, ["--source", "src"], :invalid, [:source, :destination])
  end

  test "conflict errors identify both parameters" do
    assert_usage_error(Leaf, ["--quiet", "--verbose"], :invalid, [:quiet, :verbose])
  end

  test "group errors identify their member options" do
    assert_usage_error(Leaf, ["--json", "--csv"], :invalid, [:json, :csv])
  end

  test "cross-parameter validation errors have no inferred names" do
    assert_usage_error(CrossValidated, [], :invalid, [])
  end

  test "unknown commands return the raw token without suggestions" do
    assert_usage_error(Branch, ["leef"], :unknown_command, ["leef"])
  end

  test "unknown help commands return the raw token" do
    assert_usage_error(Branch, ["help", "leef"], :unknown_command, ["leef"])
  end

  test "ambiguous commands return the raw token without listing candidates" do
    assert_usage_error(Branch, ["le"], :ambiguous_command, ["le"])
  end

  test "ambiguous help commands return the raw token" do
    assert_usage_error(Branch, ["help", "le"], :ambiguous_command, ["le"])
  end

  test "a required subcommand error returns no parameter names or help" do
    assert_usage_error(Branch, [], :subcommand_required, [])
  end

  test "unknown options before a subcommand return the raw token" do
    assert_usage_error(Branch, ["--bogus", "leaf"], :unknown_option, ["--bogus"])
  end

  test "invalid global values before a subcommand return the declared name" do
    assert_usage_error(Branch, ["--wait-ms", "wrong", "leaf"], :invalid_value, [:wait_ms])
  end

  test "invalid global aliases before a subcommand return the declared name" do
    assert_usage_error(Branch, ["--delay", "wrong", "leaf"], :invalid_value, [:wait_ms])
  end

  test "invalid inherited global values after a subcommand return the declared name" do
    assert_usage_error(Branch, ["legacy", "input", "--wait-ms", "wrong"], :invalid_value, [
      :wait_ms
    ])
  end

  test "parent local options before a subcommand identify the declared option" do
    assert_usage_error(Branch, ["--config", "cfg", "leaf"], :invalid, [:config])
  end

  test "parent local aliases before a subcommand identify the declared option" do
    assert_usage_error(Branch, ["--settings", "cfg", "leaf"], :invalid, [:config])
  end

  test "unknown external command options return raw tokens" do
    assert_usage_error(External, ["--bogus", "plugin"], :unknown_option, ["--bogus"])
  end

  test "invalid external command option values return declared names" do
    assert_usage_error(External, ["--wait-ms", "wrong", "plugin"], :invalid_value, [:wait_ms])
  end

  test "missing required external command options return declared names" do
    assert_usage_error(External, ["plugin"], :missing_required, [:token])
  end

  test "external command validation errors return declared names" do
    assert_usage_error(External, ["--token", "x", "--format", "xml", "plugin"], :invalid, [
      :format
    ])
  end

  test "usage failures through deprecated subcommands print no warning" do
    assert_usage_error(Branch, ["legacy"], :missing_required, [:input])
  end

  test "return mode also leaves a private error device empty" do
    {result, stdout, stderr} =
      streams(fn -> Cheer.Test.run(Leaf, ["--wait-ms", "wrong"], errors: :return) end)

    assert {:error, %UsageError{kind: :invalid_value, names: [:wait_ms]}} = result.return
    assert result.output == ""
    assert result.error_output == ""
    assert stdout == ""
    assert stderr == ""
  end

  test "print mode reports the declared option and expected type for invalid values" do
    for opts <- [[], [errors: :print]], entrypoint <- [:parse, :run] do
      {result, stdout, stderr} =
        streams(fn -> apply(Cheer, entrypoint, [Leaf, ["--wait-ms", "wrong"], opts]) end)

      assert result == {:error, :usage}
      assert stdout == ""
      assert stderr =~ "--wait-ms"
      assert stderr =~ "integer"
      assert stderr =~ "Usage:"
      refute stderr =~ "unknown option"
    end
  end

  test "print mode reports missing values without calling the option unknown" do
    for opts <- [[], [errors: :print]],
        entrypoint <- [:parse, :run],
        flag <- ["--wait-ms", "-w", "--delay"] do
      {result, stdout, stderr} =
        streams(fn -> apply(Cheer, entrypoint, [Leaf, [flag], opts]) end)

      assert result == {:error, :usage}
      assert stdout == ""
      assert stderr =~ "missing value for --wait-ms"
      assert stderr =~ "Usage:"
      refute stderr =~ "unknown option"
    end
  end

  test "invalid errors options raise before any output including requested help" do
    for entrypoint <- [:parse, :run],
        errors <- [:invalid, nil, "return"],
        argv <- [[], ["--help"]] do
      {error, stdout, stderr} =
        streams(fn ->
          assert_raise ArgumentError, fn ->
            apply(Cheer, entrypoint, [Leaf, argv, [errors: errors]])
          end
        end)

      assert error.message =~ ":print"
      assert error.message =~ ":return"
      assert stdout == ""
      assert stderr == ""
    end
  end

  test "mixed invalid entries return the first error category without printing" do
    assert_usage_error(Leaf, ["--bogus", "--wait-ms", "wrong"], :unknown_option, ["--bogus"])
    assert_usage_error(Leaf, ["--wait-ms", "wrong", "--bogus"], :invalid_value, [:wait_ms])
  end

  test "print mode reports both unknown options and invalid values" do
    {result, stdout, stderr} =
      streams(fn -> Cheer.parse(Leaf, ["--bogus", "--wait-ms", "wrong"], errors: :print) end)

    assert result == {:error, :usage}
    assert stdout == ""
    assert stderr =~ "unknown option(s): --bogus"
    assert stderr =~ "--wait-ms"
    assert stderr =~ "integer"
    refute stderr =~ "unknown option(s): --bogus, --wait-ms"
  end

  test "return mode preserves help and version output and handled results" do
    for {argv, expected} <- [{["--help"], "Usage:"}, {["--version"], "leaf 1.2.3"}],
        {entrypoint, expected_result} <- [parse: :handled, run: :ok] do
      {result, stdout, stderr} =
        streams(fn -> apply(Cheer, entrypoint, [Leaf, argv, [errors: :return]]) end)

      assert result == expected_result
      assert stdout =~ expected
      assert stderr == ""
    end
  end

  test "exit_code recognizes returned usage errors" do
    assert Cheer.exit_code(
             {:error, %UsageError{kind: :invalid_value, names: [:wait_ms], message: "bad value"}}
           ) == 2

    assert Cheer.exit_code({:error, :usage}) == 2
    assert Cheer.exit_code(:handled) == 0
    assert Cheer.exit_code({:ok, %{}}) == 0
  end
end

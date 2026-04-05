defmodule CheerTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  # -- Test command modules ---------------------------------------------------

  defmodule TestGreet do
    use Cheer.Command

    command "greet" do
      about("Say hello")

      argument(:name, type: :string, required: true, help: "Who to greet")
      option(:loud, type: :boolean, short: :l, help: "Shout")
    end

    @impl Cheer.Command
    def run(args, _raw) do
      {:ok, args}
    end
  end

  defmodule TestRoot do
    use Cheer.Command

    command "app" do
      about("Test app")

      subcommand(CheerTest.TestGreet)
    end
  end

  defmodule TestVersioned do
    use Cheer.Command

    command "myapp" do
      about("An app with a version")
      version("1.2.3")

      argument(:name, type: :string, required: false, help: "Optional name")
    end

    @impl Cheer.Command
    def run(args, _raw) do
      {:ok, args}
    end
  end

  defmodule TestNoVersion do
    use Cheer.Command

    command "plain" do
      about("No version set")
    end

    @impl Cheer.Command
    def run(args, _raw) do
      {:ok, args}
    end
  end

  defmodule TestDefaults do
    use Cheer.Command

    command "serve" do
      about("Serve something")

      option(:port, type: :integer, short: :p, default: 6379, help: "Port number")
      option(:host, type: :string, short: :H, default: "localhost", help: "Host")
      option(:verbose, type: :boolean, short: :v, help: "Verbose output")
    end

    @impl Cheer.Command
    def run(args, _raw) do
      {:ok, args}
    end
  end

  defmodule TestMultiArg do
    use Cheer.Command

    command "copy" do
      about("Copy files")

      argument(:source, type: :string, required: true, help: "Source path")
      argument(:dest, type: :string, required: true, help: "Destination path")
    end

    @impl Cheer.Command
    def run(args, _raw) do
      {:ok, args}
    end
  end

  defmodule TestBranch do
    use Cheer.Command

    command "native" do
      about("Native commands")

      subcommand(CheerTest.TestGreet)
      subcommand(CheerTest.TestDefaults)
    end
  end

  # -- Original tests (preserved) --------------------------------------------

  test "command metadata is compiled" do
    meta = TestGreet.__cheer_meta__()
    assert meta.name == "greet"
    assert meta.about == "Say hello"
    assert length(meta.arguments) == 1
    assert length(meta.options) == 1
  end

  test "router dispatches to leaf command" do
    assert {:ok, %{name: "world"}} = Cheer.run(TestGreet, ["world"])
  end

  test "router dispatches through subcommands" do
    assert {:ok, %{name: "world"}} = Cheer.run(TestRoot, ["greet", "world"])
  end

  test "options are parsed" do
    assert {:ok, %{name: "world", loud: true}} = Cheer.run(TestGreet, ["world", "--loud"])
  end

  test "short options are parsed" do
    assert {:ok, %{name: "world", loud: true}} = Cheer.run(TestGreet, ["world", "-l"])
  end

  # -- 1. Required argument validation ----------------------------------------

  describe "required argument validation" do
    test "prints error when required argument is missing" do
      output =
        capture_io(fn ->
          Cheer.run(TestGreet, [])
        end)

      assert output =~ "error: missing required argument(s): <name>"
      assert output =~ "ARGUMENTS:"
    end

    test "prints error when one of multiple required arguments is missing" do
      output =
        capture_io(fn ->
          Cheer.run(TestMultiArg, ["only_source"])
        end)

      assert output =~ "error: missing required argument(s): <dest>"
    end

    test "prints error when all required arguments are missing" do
      output =
        capture_io(fn ->
          Cheer.run(TestMultiArg, [])
        end)

      assert output =~ "<source>"
      assert output =~ "<dest>"
    end

    test "succeeds when required arguments are provided" do
      assert {:ok, %{source: "a.txt", dest: "b.txt"}} =
               Cheer.run(TestMultiArg, ["a.txt", "b.txt"])
    end
  end

  # -- 2. Default values for options ------------------------------------------

  describe "default values for options" do
    test "applies defaults when options are not provided" do
      assert {:ok, args} = Cheer.run(TestDefaults, [])
      assert args[:port] == 6379
      assert args[:host] == "localhost"
    end

    test "overrides defaults when options are explicitly provided" do
      assert {:ok, args} = Cheer.run(TestDefaults, ["--port", "8080", "--host", "0.0.0.0"])
      assert args[:port] == 8080
      assert args[:host] == "0.0.0.0"
    end

    test "options without defaults remain absent" do
      assert {:ok, args} = Cheer.run(TestDefaults, [])
      refute Map.has_key?(args, :verbose)
    end

    test "defaults appear in help text" do
      output = capture_io(fn -> Cheer.run(TestDefaults, ["--help"]) end)
      assert output =~ "[default: 6379]"
      assert output =~ "[default: localhost]"
    end
  end

  # -- 3. No-args behavior for branch commands --------------------------------

  describe "no-args branch command behavior" do
    test "prints help when a branch command is invoked with no args" do
      output =
        capture_io(fn ->
          Cheer.run(TestBranch, [])
        end)

      assert output =~ "COMMANDS:"
      assert output =~ "greet"
      assert output =~ "serve"
    end

    test "prints help when root branch is invoked with no args" do
      output =
        capture_io(fn ->
          Cheer.run(TestRoot, [])
        end)

      assert output =~ "COMMANDS:"
      assert output =~ "greet"
    end
  end

  # -- 4. Version flag --------------------------------------------------------

  describe "version flag" do
    test "metadata includes version when declared" do
      meta = TestVersioned.__cheer_meta__()
      assert meta.version == "1.2.3"
    end

    test "metadata version is nil when not declared" do
      meta = TestNoVersion.__cheer_meta__()
      assert meta.version == nil
    end

    test "--version prints the version string" do
      output =
        capture_io(fn ->
          Cheer.run(TestVersioned, ["--version"])
        end)

      assert output =~ "myapp 1.2.3"
    end

    test "-V prints the version string" do
      output =
        capture_io(fn ->
          Cheer.run(TestVersioned, ["-V"])
        end)

      assert output =~ "myapp 1.2.3"
    end

    test "--version on a command without version says version not set" do
      output =
        capture_io(fn ->
          Cheer.run(TestNoVersion, ["--version"])
        end)

      assert output =~ "version not set"
    end

    test "help text shows -V flag when version is set" do
      output = capture_io(fn -> Cheer.run(TestVersioned, ["--help"]) end)
      assert output =~ "--version"
    end

    test "help text does not show -V flag when version is not set" do
      output = capture_io(fn -> Cheer.run(TestNoVersion, ["--help"]) end)
      refute output =~ "--version"
    end
  end

  # -- 5. Unknown subcommand error messages -----------------------------------

  describe "unknown subcommand error" do
    test "prints error with unknown command name" do
      output =
        capture_io(fn ->
          Cheer.run(TestRoot, ["bogus"])
        end)

      assert output =~ "error: unknown command 'bogus'"
    end

    test "lists available subcommands" do
      output =
        capture_io(fn ->
          Cheer.run(TestBranch, ["nope"])
        end)

      assert output =~ "error: unknown command 'nope'"
      assert output =~ "Available commands:"
      assert output =~ "greet"
      assert output =~ "serve"
    end

    test "unknown command on root with single subcommand" do
      output =
        capture_io(fn ->
          Cheer.run(TestRoot, ["deploy"])
        end)

      assert output =~ "error: unknown command 'deploy'"
      assert output =~ "greet"
    end
  end

  # -- Help flag still works --------------------------------------------------

  describe "help flag" do
    test "--help on leaf command prints help" do
      output = capture_io(fn -> Cheer.run(TestGreet, ["--help"]) end)
      assert output =~ "Say hello"
      assert output =~ "<name>"
    end

    test "-h on leaf command prints help" do
      output = capture_io(fn -> Cheer.run(TestGreet, ["-h"]) end)
      assert output =~ "Say hello"
    end

    test "--help on branch command prints help" do
      output = capture_io(fn -> Cheer.run(TestRoot, ["--help"]) end)
      assert output =~ "COMMANDS:"
    end
  end

  # -- Help subcommand ---------------------------------------------------------

  describe "help subcommand" do
    test "help with no args shows root help" do
      output = capture_io(fn -> Cheer.run(TestRoot, ["help"]) end)
      assert output =~ "COMMANDS:"
      assert output =~ "greet"
    end

    test "help <subcommand> shows subcommand help" do
      output = capture_io(fn -> Cheer.run(TestRoot, ["help", "greet"]) end)
      assert output =~ "Say hello"
      assert output =~ "<name>"
    end

    test "help with unknown subcommand shows error" do
      output = capture_io(fn -> Cheer.run(TestRoot, ["help", "nope"]) end)
      assert output =~ "error: unknown command 'nope'"
    end
  end

  # -- Program name in help ----------------------------------------------------

  describe "program name" do
    test "uses command name by default in usage" do
      output = capture_io(fn -> Cheer.run(TestGreet, ["--help"]) end)
      assert output =~ "Usage: greet"
    end

    test "uses custom prog name when provided" do
      output = capture_io(fn -> Cheer.run(TestGreet, ["--help"], prog: "my-tool") end)
      assert output =~ "Usage: my-tool"
    end
  end

  # -- Invalid options ---------------------------------------------------------

  describe "invalid options" do
    test "reports unknown flags" do
      output =
        capture_io(fn ->
          Cheer.run(TestGreet, ["world", "--unknown-flag"])
        end)

      assert output =~ "error: unknown option(s): --unknown-flag"
    end

    test "reports unknown short flags" do
      output =
        capture_io(fn ->
          Cheer.run(TestDefaults, ["--bogus", "val"])
        end)

      assert output =~ "error: unknown option(s)"
    end
  end

  # -- Environment variable fallback -------------------------------------------

  defmodule TestEnvVar do
    use Cheer.Command

    command "serve" do
      about("Serve with env")

      option(:port, type: :integer, short: :p, default: 6379, env: "TEST_CLAP_PORT", help: "Port")
      option(:host, type: :string, default: "localhost", env: "TEST_CLAP_HOST", help: "Host")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "environment variable fallback" do
    test "uses env var when option not provided" do
      System.put_env("TEST_CLAP_PORT", "9999")
      assert {:ok, args} = Cheer.run(TestEnvVar, [])
      assert args[:port] == 9999
    after
      System.delete_env("TEST_CLAP_PORT")
    end

    test "explicit flag overrides env var" do
      System.put_env("TEST_CLAP_PORT", "9999")
      assert {:ok, args} = Cheer.run(TestEnvVar, ["--port", "8080"])
      assert args[:port] == 8080
    after
      System.delete_env("TEST_CLAP_PORT")
    end

    test "falls back to default when no env var or flag" do
      System.delete_env("TEST_CLAP_PORT")
      assert {:ok, args} = Cheer.run(TestEnvVar, [])
      assert args[:port] == 6379
    end

    test "env var works for string options" do
      System.put_env("TEST_CLAP_HOST", "0.0.0.0")
      assert {:ok, args} = Cheer.run(TestEnvVar, [])
      assert args[:host] == "0.0.0.0"
    after
      System.delete_env("TEST_CLAP_HOST")
    end

    test "env var shown in help text" do
      output = capture_io(fn -> Cheer.run(TestEnvVar, ["--help"]) end)
      assert output =~ "TEST_CLAP_PORT"
    end
  end

  # -- Per-param validation ----------------------------------------------------

  defmodule TestValidation do
    use Cheer.Command

    command "validated" do
      about("Validated params")

      option(:port,
        type: :integer,
        required: true,
        validate: fn val ->
          if val in 1024..65535, do: :ok, else: {:error, "port must be 1024-65535"}
        end,
        help: "Port number"
      )

      option(:format, type: :string, choices: ["json", "table", "raw"], help: "Output format")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "per-param validation" do
    test "passes when validation succeeds" do
      assert {:ok, %{port: 8080}} = Cheer.run(TestValidation, ["--port", "8080"])
    end

    test "fails when validation rejects value" do
      output = capture_io(fn -> Cheer.run(TestValidation, ["--port", "80"]) end)
      assert output =~ "port must be 1024-65535"
    end

    test "choices restricts to allowed values" do
      assert {:ok, %{format: "json"}} =
               Cheer.run(TestValidation, ["--port", "8080", "--format", "json"])
    end

    test "choices rejects invalid value" do
      output =
        capture_io(fn -> Cheer.run(TestValidation, ["--port", "8080", "--format", "yaml"]) end)

      assert output =~ "must be one of"
    end

    test "choices shown in help" do
      output = capture_io(fn -> Cheer.run(TestValidation, ["--help"]) end)
      assert output =~ "json"
      assert output =~ "table"
      assert output =~ "raw"
    end
  end

  # -- Cross-param validation --------------------------------------------------

  defmodule TestCrossValidation do
    use Cheer.Command

    command "tls" do
      about("TLS config")

      option(:tls, type: :boolean, help: "Enable TLS")
      option(:cert_file, type: :string, help: "Certificate file")

      validate(fn args ->
        if args[:tls] && !args[:cert_file] do
          {:error, "--tls requires --cert-file"}
        else
          :ok
        end
      end)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "cross-param validation" do
    test "passes when constraints satisfied" do
      assert {:ok, _} = Cheer.run(TestCrossValidation, ["--tls", "--cert-file", "cert.pem"])
    end

    test "passes when neither param set" do
      assert {:ok, _} = Cheer.run(TestCrossValidation, [])
    end

    test "fails when constraint violated" do
      output = capture_io(fn -> Cheer.run(TestCrossValidation, ["--tls"]) end)
      assert output =~ "--tls requires --cert-file"
    end
  end

  # -- Argument type coercion --------------------------------------------------

  defmodule TestTypedArgs do
    use Cheer.Command

    command "math" do
      about("Do math")

      argument(:x, type: :integer, required: true, help: "First number")
      argument(:y, type: :integer, required: true, help: "Second number")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "argument type coercion" do
    test "coerces integer arguments" do
      assert {:ok, %{x: 10, y: 20}} = Cheer.run(TestTypedArgs, ["10", "20"])
    end

    test "integer arguments are actual integers" do
      {:ok, args} = Cheer.run(TestTypedArgs, ["10", "20"])
      assert is_integer(args.x)
      assert is_integer(args.y)
    end
  end

  # -- Lifecycle hooks ---------------------------------------------------------

  defmodule TestHooksLeaf do
    use Cheer.Command

    command "hooked" do
      about("Test hooks")

      option(:name, type: :string, default: "world")

      before_run(fn args ->
        Map.put(args, :setup, true)
      end)

      after_run(fn result ->
        {:wrapped, result}
      end)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestHooksChild do
    use Cheer.Command

    command "child" do
      about("Child command")
      option(:name, type: :string, default: "kid")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestHooksParent do
    use Cheer.Command

    command "parent" do
      about("Parent with persistent hooks")

      persistent_before_run(fn args ->
        Map.put(args, :from_parent, true)
      end)

      subcommand(CheerTest.TestHooksChild)
    end
  end

  describe "lifecycle hooks" do
    test "before_run transforms args before run/2" do
      assert {:wrapped, {:ok, %{setup: true}}} = Cheer.run(TestHooksLeaf, [])
    end

    test "after_run transforms the result of run/2" do
      assert {:wrapped, {:ok, _}} = Cheer.run(TestHooksLeaf, [])
    end

    test "persistent_before_run propagates to child commands" do
      assert {:ok, %{from_parent: true, name: "kid"}} =
               Cheer.run(TestHooksParent, ["child"])
    end
  end

  # -- Mutually exclusive / co-occurring groups --------------------------------

  defmodule TestGroups do
    use Cheer.Command

    command "output" do
      about("Test param groups")

      group :format, mutually_exclusive: true do
        option(:json, type: :boolean, help: "JSON output")
        option(:csv, type: :boolean, help: "CSV output")
        option(:table, type: :boolean, help: "Table output")
      end

      group :auth, co_occurring: true do
        option(:username, type: :string, help: "Username")
        option(:password, type: :string, help: "Password")
      end

      option(:verbose, type: :boolean, help: "Verbose")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "param groups" do
    test "mutually exclusive: allows one option" do
      assert {:ok, %{json: true}} = Cheer.run(TestGroups, ["--json"])
    end

    test "mutually exclusive: rejects multiple" do
      output = capture_io(fn -> Cheer.run(TestGroups, ["--json", "--csv"]) end)
      assert output =~ "mutually exclusive"
    end

    test "co-occurring: allows both present" do
      assert {:ok, %{username: "me", password: "pw"}} =
               Cheer.run(TestGroups, ["--username", "me", "--password", "pw"])
    end

    test "co-occurring: rejects partial" do
      output = capture_io(fn -> Cheer.run(TestGroups, ["--username", "me"]) end)
      assert output =~ "must be used together"
    end

    test "co-occurring: allows neither" do
      assert {:ok, _} = Cheer.run(TestGroups, [])
    end

    test "groups shown in help" do
      output = capture_io(fn -> Cheer.run(TestGroups, ["--help"]) end)
      assert output =~ "format"
      assert output =~ "auth"
    end
  end

  # -- "Did you mean?" suggestions --------------------------------------------

  describe "typo suggestions" do
    test "suggests similar command name" do
      output = capture_io(fn -> Cheer.run(TestBranch, ["grete"]) end)
      assert output =~ "Did you mean"
      assert output =~ "greet"
    end

    test "no suggestion when nothing close" do
      output = capture_io(fn -> Cheer.run(TestBranch, ["zzzzz"]) end)
      refute output =~ "Did you mean"
    end
  end

  # -- Test runner -------------------------------------------------------------

  describe "Cheer.Test" do
    test "captures output and return value" do
      result = Cheer.Test.run(TestGreet, ["hello"])
      assert result.return == {:ok, %{name: "hello", rest: []}}
      assert result.output == ""
    end

    test "captures IO output" do
      result = Cheer.Test.run(TestGreet, ["--help"])
      assert result.output =~ "Say hello"
    end

    test "captures missing arg error" do
      result = Cheer.Test.run(TestGreet, [])
      assert result.output =~ "missing required"
    end
  end

  # -- Shell completion --------------------------------------------------------

  describe "Cheer.Completion" do
    test "generates bash completion" do
      script = Cheer.Completion.generate(TestRoot, :bash, prog: "myapp")
      assert script =~ "complete -F _myapp myapp"
      assert script =~ "greet"
    end

    test "generates zsh completion" do
      script = Cheer.Completion.generate(TestRoot, :zsh, prog: "myapp")
      assert script =~ "#compdef myapp"
      assert script =~ "greet"
    end

    test "generates fish completion" do
      script = Cheer.Completion.generate(TestRoot, :fish, prog: "myapp")
      assert script =~ "complete -c myapp"
      assert script =~ "greet"
    end

    test "includes option flags in bash" do
      script = Cheer.Completion.generate(TestDefaults, :bash, prog: "serve")
      assert script =~ "--port"
      assert script =~ "--host"
      assert script =~ "-p"
    end
  end

  # -- REPL mode ---------------------------------------------------------------

  describe "Cheer.Repl" do
    test "processes commands and exits" do
      output =
        capture_io("help\nexit\n", fn ->
          Cheer.Repl.start(TestRoot, prog: "test")
        end)

      assert output =~ "test interactive shell"
      assert output =~ "COMMANDS:"
      assert output =~ "Bye!"
    end

    test "dispatches commands through the tree" do
      output =
        capture_io("greet world\nexit\n", fn ->
          Cheer.Repl.start(TestRoot, prog: "test")
        end)

      assert output =~ "test interactive shell"
    end
  end

  # -- Command tree introspection ---------------------------------------------

  describe "Cheer.tree" do
    test "returns command tree as data" do
      tree = Cheer.tree(TestRoot)
      assert tree.name == "app"
      assert length(tree.subcommands) == 1
      assert hd(tree.subcommands).name == "greet"
    end

    test "includes options and arguments in tree" do
      tree = Cheer.tree(TestGreet)
      assert length(tree.arguments) == 1
      assert length(tree.options) == 1
    end

    test "nested tree" do
      tree = Cheer.tree(TestBranch)
      assert tree.name == "native"
      assert length(tree.subcommands) == 2
      names = Enum.map(tree.subcommands, & &1.name) |> Enum.sort()
      assert names == ["greet", "serve"]
    end
  end

  # -- :count type ----------------------------------------------------------

  defmodule TestCount do
    use Cheer.Command

    command "verbose" do
      about("Test count")

      option(:verbose, type: :count, short: :v, help: "Increase verbosity")
      argument(:name, type: :string, required: true, help: "Name")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "count type" do
    test "single flag" do
      assert {:ok, args} = Cheer.run(TestCount, ["hello", "-v"])
      assert args[:verbose] == 1
    end

    test "repeated flags" do
      assert {:ok, args} = Cheer.run(TestCount, ["hello", "-v", "-v", "-v"])
      assert args[:verbose] == 3
    end

    test "combined short flags" do
      assert {:ok, args} = Cheer.run(TestCount, ["hello", "-vvv"])
      assert args[:verbose] == 3
    end

    test "defaults to 0 when not provided" do
      assert {:ok, args} = Cheer.run(TestCount, ["hello"])
      assert args[:verbose] == 0
    end

    test "help text shows repeatable" do
      output = capture_io(fn -> Cheer.run(TestCount, ["--help"]) end)
      assert output =~ "(repeatable)"
    end
  end

  # -- Multi-value options ---------------------------------------------------

  defmodule TestMultiValue do
    use Cheer.Command

    command "multi" do
      about("Test multi-value")

      option(:tag, type: :string, multi: true, short: :t, help: "Tags")
      option(:port, type: :integer, multi: true, help: "Ports")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestMultiRequired do
    use Cheer.Command

    command "multi-req" do
      about("Test multi required")

      option(:tag, type: :string, multi: true, required: true, help: "Tags")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "multi-value options" do
    test "collects repeated flags into a list" do
      assert {:ok, args} = Cheer.run(TestMultiValue, ["--tag", "a", "--tag", "b"])
      assert args[:tag] == ["a", "b"]
    end

    test "single value is still a list" do
      assert {:ok, args} = Cheer.run(TestMultiValue, ["--tag", "solo"])
      assert args[:tag] == ["solo"]
    end

    test "defaults to empty list" do
      assert {:ok, args} = Cheer.run(TestMultiValue, [])
      assert args[:tag] == []
      assert args[:port] == []
    end

    test "works with short flags" do
      assert {:ok, args} = Cheer.run(TestMultiValue, ["-t", "x", "-t", "y"])
      assert args[:tag] == ["x", "y"]
    end

    test "works with integer type" do
      assert {:ok, args} = Cheer.run(TestMultiValue, ["--port", "80", "--port", "443"])
      assert args[:port] == [80, 443]
    end

    test "required multi rejects empty" do
      output = capture_io(fn -> Cheer.run(TestMultiRequired, []) end)
      assert output =~ "missing required"
    end

    test "required multi accepts values" do
      assert {:ok, args} = Cheer.run(TestMultiRequired, ["--tag", "a"])
      assert args[:tag] == ["a"]
    end

    test "help text shows multiple" do
      output = capture_io(fn -> Cheer.run(TestMultiValue, ["--help"]) end)
      assert output =~ "(multiple)"
    end
  end

  # -- Boolean negation (--no-*) ---------------------------------------------

  describe "boolean negation" do
    test "--no-loud sets boolean to false" do
      assert {:ok, args} = Cheer.run(TestGreet, ["hello", "--no-loud"])
      assert args[:loud] == false
    end

    test "--no-verbose sets boolean to false" do
      assert {:ok, args} = Cheer.run(TestDefaults, ["--no-verbose"])
      assert args[:verbose] == false
    end

    test "help text shows [no-] for boolean options" do
      output = capture_io(fn -> Cheer.run(TestGreet, ["--help"]) end)
      assert output =~ "--[no-]loud"
    end

    test "completion includes --no- variants for booleans" do
      script = Cheer.Completion.generate(TestDefaults, :bash, prog: "serve")
      assert script =~ "--no-verbose"
    end
  end

  # -- Double-dash separator -------------------------------------------------

  describe "-- separator" do
    test "extra args after -- are collected in :rest" do
      assert {:ok, args} = Cheer.run(TestGreet, ["world", "--", "--not-a-flag", "extra"])
      assert args[:name] == "world"
      assert args[:rest] == ["--not-a-flag", "extra"]
    end

    test "no separator gives empty rest" do
      assert {:ok, args} = Cheer.run(TestGreet, ["world"])
      assert args[:rest] == []
    end

    test "separator with no extra args gives empty rest" do
      assert {:ok, args} = Cheer.run(TestGreet, ["world", "--"])
      assert args[:rest] == []
    end

    test "help usage line shows [-- <args>...]" do
      output = capture_io(fn -> Cheer.run(TestGreet, ["--help"]) end)
      assert output =~ "[-- <args>...]"
    end
  end

  # -- Hidden options and commands (#10) ---------------------------------------

  defmodule TestHidden do
    use Cheer.Command

    command "tool" do
      about("Tool with hidden stuff")

      option(:debug, type: :boolean, hide: true, help: "Debug mode")
      option(:verbose, type: :boolean, short: :v, help: "Verbose output")
      argument(:input, type: :string, hide: true, help: "Hidden input")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "hidden options and arguments" do
    test "hidden option is not shown in help" do
      output = capture_io(fn -> Cheer.run(TestHidden, ["--help"]) end)
      refute output =~ "debug"
      assert output =~ "verbose"
    end

    test "hidden option still parses" do
      assert {:ok, %{debug: true}} = Cheer.run(TestHidden, ["--debug"])
    end

    test "hidden argument is not shown in help" do
      output = capture_io(fn -> Cheer.run(TestHidden, ["--help"]) end)
      refute output =~ "<input>"
    end

    test "hidden argument still parses" do
      assert {:ok, %{input: "foo"}} = Cheer.run(TestHidden, ["foo"])
    end
  end

  # -- Subcommand aliases (#12) ------------------------------------------------

  defmodule TestAliasedSub do
    use Cheer.Command

    command "checkout" do
      about("Check out a branch")
      aliases(["co", "ck"])

      argument(:branch, type: :string, required: true, help: "Branch name")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestAliasRoot do
    use Cheer.Command

    command "git" do
      about("Git-like tool")

      subcommand(CheerTest.TestAliasedSub)
    end
  end

  describe "subcommand aliases" do
    test "dispatches via primary name" do
      assert {:ok, %{branch: "main"}} = Cheer.run(TestAliasRoot, ["checkout", "main"])
    end

    test "dispatches via alias" do
      assert {:ok, %{branch: "main"}} = Cheer.run(TestAliasRoot, ["co", "main"])
    end

    test "dispatches via second alias" do
      assert {:ok, %{branch: "main"}} = Cheer.run(TestAliasRoot, ["ck", "main"])
    end

    test "aliases shown in help" do
      output = capture_io(fn -> Cheer.run(TestAliasRoot, ["--help"]) end)
      assert output =~ "checkout"
      assert output =~ "co, ck"
    end

    test "did you mean considers aliases" do
      output = capture_io(fn -> Cheer.run(TestAliasRoot, ["checkou"]) end)
      assert output =~ "Did you mean"
      assert output =~ "checkout"
    end
  end

  # -- Long help (#9) ----------------------------------------------------------

  defmodule TestLongHelp do
    use Cheer.Command

    command "analyzer" do
      about("Analyze data")
      long_about("Analyze data from multiple sources.\nSupports CSV, JSON, and Parquet formats.")

      option(:format,
        type: :string,
        help: "Output format",
        long_help: "Output format for the analysis results.\nSupported: json, table, csv."
      )
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "long help" do
    test "-h shows short about" do
      output = capture_io(fn -> Cheer.run(TestLongHelp, ["-h"]) end)
      assert output =~ "Analyze data"
      refute output =~ "Supports CSV, JSON, and Parquet"
    end

    test "--help shows long about" do
      output = capture_io(fn -> Cheer.run(TestLongHelp, ["--help"]) end)
      assert output =~ "Supports CSV, JSON, and Parquet"
    end

    test "-h shows short option help" do
      output = capture_io(fn -> Cheer.run(TestLongHelp, ["-h"]) end)
      assert output =~ "Output format"
      refute output =~ "Supported: json, table, csv"
    end

    test "--help shows long option help" do
      output = capture_io(fn -> Cheer.run(TestLongHelp, ["--help"]) end)
      assert output =~ "Supported: json, table, csv"
    end
  end

  # -- Value names (#20) -------------------------------------------------------

  defmodule TestValueNames do
    use Cheer.Command

    command "convert" do
      about("Convert files")

      argument(:input,
        type: :string,
        required: true,
        value_name: "INPUT_FILE",
        help: "Input path"
      )

      option(:output, type: :string, short: :o, value_name: "OUTPUT_FILE", help: "Output path")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "value names" do
    test "value_name appears in argument help" do
      output = capture_io(fn -> Cheer.run(TestValueNames, ["--help"]) end)
      assert output =~ "<INPUT_FILE>"
    end

    test "value_name appears in option help" do
      output = capture_io(fn -> Cheer.run(TestValueNames, ["--help"]) end)
      assert output =~ "<OUTPUT_FILE>"
    end

    test "value_name appears in usage line" do
      output = capture_io(fn -> Cheer.run(TestValueNames, ["--help"]) end)
      assert output =~ "Usage: convert <INPUT_FILE>"
    end
  end

  # -- Before/after help text (#16) --------------------------------------------

  defmodule TestHelpText do
    use Cheer.Command

    command "mytool" do
      about("A tool")
      before_help("MyTool v1.0 -- the best tool")
      after_help("EXAMPLES:\n  mytool --verbose input.txt")

      option(:verbose, type: :boolean, help: "Verbose")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "before/after help text" do
    test "before_help appears at the top" do
      output = capture_io(fn -> Cheer.run(TestHelpText, ["--help"]) end)
      assert output =~ "MyTool v1.0 -- the best tool"
      # before_help should come before usage
      [before_pos] = Regex.run(~r/MyTool v1.0/, output, return: :index)
      [usage_pos] = Regex.run(~r/Usage:/, output, return: :index)
      assert elem(before_pos, 0) < elem(usage_pos, 0)
    end

    test "after_help appears at the bottom" do
      output = capture_io(fn -> Cheer.run(TestHelpText, ["--help"]) end)
      assert output =~ "EXAMPLES:"
      assert output =~ "mytool --verbose input.txt"
      # after_help should come after --help line
      [help_pos] = Regex.run(~r/Print help/, output, return: :index)
      [after_pos] = Regex.run(~r/EXAMPLES:/, output, return: :index)
      assert elem(after_pos, 0) > elem(help_pos, 0)
    end
  end

  # -- Global options (#13) ----------------------------------------------------

  defmodule TestGlobalChild do
    use Cheer.Command

    command "deploy" do
      about("Deploy the app")
      option(:target, type: :string, required: true, help: "Deploy target")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestGlobalRoot do
    use Cheer.Command

    command "app" do
      about("App with global options")

      option(:verbose, type: :boolean, short: :v, global: true, help: "Verbose output")
      option(:config, type: :string, global: true, default: "config.toml", help: "Config file")

      subcommand(CheerTest.TestGlobalChild)
    end
  end

  describe "global options" do
    test "global option available in subcommand" do
      assert {:ok, %{verbose: true, target: "prod"}} =
               Cheer.run(TestGlobalRoot, ["deploy", "--verbose", "--target", "prod"])
    end

    test "global option default inherited" do
      assert {:ok, %{config: "config.toml", target: "prod"}} =
               Cheer.run(TestGlobalRoot, ["deploy", "--target", "prod"])
    end

    test "global option overridden in subcommand" do
      assert {:ok, %{config: "custom.toml", target: "prod"}} =
               Cheer.run(TestGlobalRoot, [
                 "deploy",
                 "--config",
                 "custom.toml",
                 "--target",
                 "prod"
               ])
    end

    test "global option shown in subcommand help" do
      output = capture_io(fn -> Cheer.run(TestGlobalRoot, ["deploy", "--help"]) end)
      assert output =~ "verbose"
      assert output =~ "config"
      assert output =~ "target"
    end

    test "global option not duplicated if subcommand has same name" do
      output = capture_io(fn -> Cheer.run(TestGlobalRoot, ["deploy", "--help"]) end)
      assert output =~ "verbose"
    end
  end
end

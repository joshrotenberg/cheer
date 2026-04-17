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

  describe "option flag rendering" do
    defmodule TestUnderscoreOption do
      use Cheer.Command

      command "under" do
        about("Underscore option names")
        option(:base_port, type: :integer, help: "Starting port")
        option(:replicas_per_master, type: :integer, help: "Replicas")
      end

      @impl Cheer.Command
      def run(args, _raw), do: {:ok, args}
    end

    test "help renders atom option names as kebab-case, matching the parser" do
      output = capture_io(fn -> Cheer.run(TestUnderscoreOption, ["--help"]) end)
      # The parser accepts --base-port (OptionParser kebab-case convention);
      # help has to show the same form so users type what they read.
      assert output =~ "--base-port"
      assert output =~ "--replicas-per-master"
      refute output =~ "--base_port"
      refute output =~ "--replicas_per_master"
    end

    test "the rendered flag is accepted by the parser" do
      output =
        capture_io(fn ->
          Cheer.run(TestUnderscoreOption, ["--base-port", "17500"])
        end)

      # No "unknown option(s)" error means the flag parsed.
      refute output =~ "unknown option"
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
          if val in 1024..65_535, do: :ok, else: {:error, "port must be 1024-65535"}
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

    test "generates powershell completion (#23)" do
      script = Cheer.Completion.generate(TestRoot, :powershell, prog: "myapp")
      assert script =~ "Register-ArgumentCompleter -Native -CommandName 'myapp'"
      assert script =~ "using namespace System.Management.Automation"
      assert script =~ "'myapp' {"
      assert script =~ "[CompletionResult]::new('greet'"
      assert script =~ "[CompletionResultType]::ParameterValue"
    end

    test "powershell completion nests subcommands under semicolon-joined keys (#23)" do
      script = Cheer.Completion.generate(TestRoot, :powershell, prog: "myapp")
      assert script =~ "'myapp;greet' {"
    end

    test "powershell option flags appear at the right level (#23)" do
      script = Cheer.Completion.generate(TestDefaults, :powershell, prog: "serve")
      assert script =~ "'serve' {"
      assert script =~ "[CompletionResult]::new('--port'"
      assert script =~ "[CompletionResult]::new('--host'"
      assert script =~ "[CompletionResultType]::ParameterName"
    end

    test "powershell flag names are kebab-cased to match the parser (#23)" do
      defmodule TestPwshUnderscores do
        use Cheer.Command

        command "app" do
          about("App")
          option(:base_port, type: :integer, help: "Base port")
        end

        @impl Cheer.Command
        def run(_args, _raw), do: :ok
      end

      script = Cheer.Completion.generate(TestPwshUnderscores, :powershell, prog: "app")
      assert script =~ "'--base-port'"
      refute script =~ "'--base_port'"
    end

    test "powershell completion escapes single quotes in help text (#23)" do
      defmodule TestPwshQuotes do
        use Cheer.Command

        command "app" do
          about("App")
          option(:flag, type: :boolean, help: "Josh's flag")
        end

        @impl Cheer.Command
        def run(_args, _raw), do: :ok
      end

      script = Cheer.Completion.generate(TestPwshQuotes, :powershell, prog: "app")
      assert script =~ "'Josh''s flag'"
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

    test "help usage line omits [-- <args>...] when no trailing_var_arg declared (#37)" do
      output = capture_io(fn -> Cheer.run(TestGreet, ["--help"]) end)
      refute output =~ "[-- <args>...]"
      refute output =~ "-- <args>"
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

  # -- subcommand_required (#21) -----------------------------------------------

  defmodule TestSubRequired do
    use Cheer.Command

    command "strict" do
      about("Requires a subcommand")
      subcommand_required(true)

      subcommand(CheerTest.TestGreet)
    end
  end

  describe "subcommand_required" do
    test "shows error when no subcommand given" do
      output = capture_io(fn -> Cheer.run(TestSubRequired, []) end)
      assert output =~ "error: a subcommand is required"
    end

    test "still shows help after the error" do
      output = capture_io(fn -> Cheer.run(TestSubRequired, []) end)
      assert output =~ "COMMANDS:"
    end

    test "works normally when subcommand is provided" do
      assert {:ok, %{name: "world"}} = Cheer.run(TestSubRequired, ["greet", "world"])
    end
  end

  # -- Custom usage line (#17) -------------------------------------------------

  defmodule TestCustomUsage do
    use Cheer.Command

    command "tool" do
      about("A tool")
      usage("tool [FLAGS] <input> [output]")

      argument(:input, type: :string, required: true, help: "Input file")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "custom usage line" do
    test "overrides auto-generated usage" do
      output = capture_io(fn -> Cheer.run(TestCustomUsage, ["--help"]) end)
      assert output =~ "Usage: tool [FLAGS] <input> [output]"
      refute output =~ "Usage: tool <input>"
    end
  end

  # -- propagate_version (#24) -------------------------------------------------

  defmodule TestPropChild do
    use Cheer.Command

    command "sub" do
      about("A child")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestPropRoot do
    use Cheer.Command

    command "myapp" do
      about("Propagates version")
      version("2.0.0")
      propagate_version(true)

      subcommand(CheerTest.TestPropChild)
    end
  end

  describe "propagate_version" do
    test "subcommand inherits version" do
      output = capture_io(fn -> Cheer.run(TestPropRoot, ["sub", "--version"]) end)
      assert output =~ "2.0.0"
    end

    test "root still has its own version" do
      output = capture_io(fn -> Cheer.run(TestPropRoot, ["--version"]) end)
      assert output =~ "myapp 2.0.0"
    end
  end

  # -- Option aliases (#11) ----------------------------------------------------

  defmodule TestOptAliases do
    use Cheer.Command

    command "style" do
      about("Style options")

      option(:color, type: :string, aliases: [:colour], help: "Color theme")
      option(:output, type: :string, short: :o, aliases: [:out], help: "Output path")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "option aliases" do
    test "primary name works" do
      assert {:ok, %{color: "red"}} = Cheer.run(TestOptAliases, ["--color", "red"])
    end

    test "alias works" do
      assert {:ok, %{color: "blue"}} = Cheer.run(TestOptAliases, ["--colour", "blue"])
    end

    test "alias with short flag" do
      assert {:ok, %{output: "out.txt"}} = Cheer.run(TestOptAliases, ["--out", "out.txt"])
    end

    test "aliases shown in help" do
      output = capture_io(fn -> Cheer.run(TestOptAliases, ["--help"]) end)
      assert output =~ "--colour"
      assert output =~ "--out"
    end
  end

  # -- trailing_var_arg (#26) --------------------------------------------------

  defmodule TestTrailing do
    use Cheer.Command

    command "exec" do
      about("Execute a command")

      argument(:program, type: :string, required: true, help: "Program to run")
      trailing_var_arg(:args, help: "Arguments to pass")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestTrailingRequired do
    use Cheer.Command

    command "cat" do
      about("Concatenate files")

      trailing_var_arg(:files, required: true, help: "Files to concatenate")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "trailing_var_arg" do
    test "collects trailing args under declared name" do
      assert {:ok, %{program: "ls", args: ["-la", "/tmp"]}} =
               Cheer.run(TestTrailing, ["ls", "--", "-la", "/tmp"])
    end

    test "empty trailing gives empty list" do
      assert {:ok, %{program: "ls", args: []}} = Cheer.run(TestTrailing, ["ls"])
    end

    test "shown in help" do
      output = capture_io(fn -> Cheer.run(TestTrailing, ["--help"]) end)
      assert output =~ "<args>..."
      assert output =~ "Arguments to pass"
    end

    test "shown in usage line" do
      output = capture_io(fn -> Cheer.run(TestTrailing, ["--help"]) end)
      assert output =~ "[args]..."
    end

    test "required trailing shown with required marker" do
      output = capture_io(fn -> Cheer.run(TestTrailingRequired, ["--help"]) end)
      assert output =~ "<files>..."
      assert output =~ "(required)"
    end

    test "required trailing errors when empty" do
      output = capture_io(fn -> Cheer.run(TestTrailingRequired, []) end)
      assert output =~ "missing required"
      assert output =~ "files"
    end

    test "required trailing succeeds with values" do
      assert {:ok, %{files: ["a.txt", "b.txt"]}} =
               Cheer.run(TestTrailingRequired, ["a.txt", "b.txt"])
    end
  end

  # -- display_order and help_heading -----------------------------------------

  defmodule TestDisplayOrderOpts do
    use Cheer.Command

    command "ordered" do
      about("Options with display_order")

      option(:zulu, type: :string, help: "Z opt", display_order: 1)
      option(:alpha, type: :string, help: "A opt", display_order: 2)
      option(:middle, type: :string, help: "M opt")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestDisplayOrderArgs do
    use Cheer.Command

    command "ordered-args" do
      about("Arguments with display_order")

      argument(:second, type: :string, help: "Shown second", display_order: 2)
      argument(:first, type: :string, help: "Shown first", display_order: 1)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestSubAlpha do
    use Cheer.Command

    command "alpha" do
      about("Alpha sub")
      display_order(2)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestSubBeta do
    use Cheer.Command

    command "beta" do
      about("Beta sub")
      display_order(1)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestSubGamma do
    use Cheer.Command

    command "gamma" do
      about("Gamma sub")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestDisplayOrderSubs do
    use Cheer.Command

    command "router" do
      about("Subcommands with display_order")

      subcommand(CheerTest.TestSubAlpha)
      subcommand(CheerTest.TestSubBeta)
      subcommand(CheerTest.TestSubGamma)
    end
  end

  defmodule TestHelpHeading do
    use Cheer.Command

    command "headed" do
      about("Options with custom headings")

      option(:host, type: :string, help: "Hostname", help_heading: "Network")
      option(:port, type: :integer, help: "Port", help_heading: "Network")
      option(:user, type: :string, help: "Username", help_heading: "Auth")
      option(:password, type: :string, help: "Password", help_heading: "Auth")
      option(:verbose, type: :boolean, help: "Be verbose")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestHeadingWithOrder do
    use Cheer.Command

    command "headed-ordered" do
      about("Mixed headings and display_order")

      option(:b_opt, type: :string, help: "B", help_heading: "Net", display_order: 2)
      option(:a_opt, type: :string, help: "A", help_heading: "Net", display_order: 1)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestDisplayOrderHidden do
    use Cheer.Command

    command "ordered-hidden" do
      about("display_order combined with hide")

      option(:visible, type: :string, help: "Shown", display_order: 2)
      option(:secret, type: :string, help: "Hidden", display_order: 1, hide: true)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "display_order for options" do
    test "options sorted by display_order, unordered fall back to declaration order" do
      output = capture_io(fn -> Cheer.run(TestDisplayOrderOpts, ["--help"]) end)
      zulu_pos = :binary.match(output, "--zulu") |> elem(0)
      alpha_pos = :binary.match(output, "--alpha") |> elem(0)
      middle_pos = :binary.match(output, "--middle") |> elem(0)
      assert zulu_pos < alpha_pos
      assert alpha_pos < middle_pos
    end

    test "hidden options stay hidden even with display_order" do
      output = capture_io(fn -> Cheer.run(TestDisplayOrderHidden, ["--help"]) end)
      refute output =~ "--secret"
      assert output =~ "--visible"
    end
  end

  describe "display_order for arguments" do
    test "arguments are reordered in help" do
      output = capture_io(fn -> Cheer.run(TestDisplayOrderArgs, ["--help"]) end)
      first_pos = :binary.match(output, "<first>") |> elem(0)
      second_pos = :binary.match(output, "<second>") |> elem(0)
      assert first_pos < second_pos
    end
  end

  describe "display_order for subcommands" do
    test "subcommands sorted by their declared display_order" do
      output = capture_io(fn -> Cheer.run(TestDisplayOrderSubs, ["--help"]) end)
      beta_pos = :binary.match(output, "beta") |> elem(0)
      alpha_pos = :binary.match(output, "alpha") |> elem(0)
      gamma_pos = :binary.match(output, "gamma") |> elem(0)
      assert beta_pos < alpha_pos
      assert alpha_pos < gamma_pos
    end
  end

  describe "help_heading for options" do
    test "options grouped under custom headings" do
      output = capture_io(fn -> Cheer.run(TestHelpHeading, ["--help"]) end)
      assert output =~ "OPTIONS:"
      assert output =~ "NETWORK:"
      assert output =~ "AUTH:"
    end

    test "default section appears before custom heading sections" do
      output = capture_io(fn -> Cheer.run(TestHelpHeading, ["--help"]) end)
      options_pos = :binary.match(output, "OPTIONS:") |> elem(0)
      network_pos = :binary.match(output, "NETWORK:") |> elem(0)
      assert options_pos < network_pos
    end

    test "first-appearance order of headings is preserved" do
      output = capture_io(fn -> Cheer.run(TestHelpHeading, ["--help"]) end)
      network_pos = :binary.match(output, "NETWORK:") |> elem(0)
      auth_pos = :binary.match(output, "AUTH:") |> elem(0)
      assert network_pos < auth_pos
    end

    test "options under a heading are listed under it (not in default)" do
      output = capture_io(fn -> Cheer.run(TestHelpHeading, ["--help"]) end)
      # --host should appear after NETWORK: and before AUTH:
      network_pos = :binary.match(output, "NETWORK:") |> elem(0)
      host_pos = :binary.match(output, "--host") |> elem(0)
      auth_pos = :binary.match(output, "AUTH:") |> elem(0)
      assert network_pos < host_pos
      assert host_pos < auth_pos
    end

    test "display_order applies within a heading section" do
      output = capture_io(fn -> Cheer.run(TestHeadingWithOrder, ["--help"]) end)
      a_pos = :binary.match(output, "--a-opt") |> elem(0)
      b_pos = :binary.match(output, "--b-opt") |> elem(0)
      assert a_pos < b_pos
    end

    test "no default OPTIONS section when every option has a heading" do
      output = capture_io(fn -> Cheer.run(TestHeadingWithOrder, ["--help"]) end)
      assert output =~ "NET:"
      # The default OPTIONS: section header should not appear when every
      # visible option lives under a custom heading.
      refute output =~ ~r/^OPTIONS:/m
    end
  end

  # -- infer_subcommands ------------------------------------------------------

  defmodule TestInferCheckout do
    use Cheer.Command

    command "checkout" do
      about("Check out a branch")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, {:checkout, args}}
  end

  defmodule TestInferCheck do
    use Cheer.Command

    command "check" do
      about("Run checks")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, {:check, args}}
  end

  defmodule TestInferStatus do
    use Cheer.Command

    command "status" do
      about("Show status")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, {:status, args}}
  end

  defmodule TestInferRoot do
    use Cheer.Command

    command "git" do
      about("Tiny git")
      infer_subcommands(true)

      subcommand(CheerTest.TestInferCheckout)
      subcommand(CheerTest.TestInferCheck)
      subcommand(CheerTest.TestInferStatus)
    end
  end

  defmodule TestNoInferRoot do
    use Cheer.Command

    command "git" do
      about("Tiny git, no inference")

      subcommand(CheerTest.TestInferCheckout)
      subcommand(CheerTest.TestInferStatus)
    end
  end

  describe "infer_subcommands" do
    test "unique prefix resolves to the matching subcommand" do
      assert {:ok, {:status, _}} = Cheer.run(TestInferRoot, ["sta"])
    end

    test "ambiguous prefix prints error and lists candidates" do
      output = capture_io(fn -> Cheer.run(TestInferRoot, ["che"]) end)
      assert output =~ "error: 'che' is ambiguous"
      assert output =~ "candidates:"
      assert output =~ "check"
      assert output =~ "checkout"
    end

    test "exact match wins over prefix" do
      # `check` is also a prefix of `checkout`, but exact match takes priority
      assert {:ok, {:check, _}} = Cheer.run(TestInferRoot, ["check"])
    end

    test "non-matching prefix falls back to unknown command" do
      output = capture_io(fn -> Cheer.run(TestInferRoot, ["xyz"]) end)
      assert output =~ "error: unknown command 'xyz'"
    end

    test "inference is disabled by default" do
      output = capture_io(fn -> Cheer.run(TestNoInferRoot, ["sta"]) end)
      assert output =~ "error: unknown command 'sta'"
    end

    test "inferred subcommand still receives flags" do
      output = capture_io(fn -> Cheer.run(TestInferRoot, ["sta", "--help"]) end)
      assert output =~ "Show status"
    end

    test "help <prefix> resolves the inferred command" do
      output = capture_io(fn -> Cheer.run(TestInferRoot, ["help", "sta"]) end)
      assert output =~ "Show status"
    end

    test "help <ambiguous-prefix> reports the ambiguity" do
      output = capture_io(fn -> Cheer.run(TestInferRoot, ["help", "che"]) end)
      assert output =~ "is ambiguous"
    end

    test "empty argv on an inferring branch shows help (no crash)" do
      output = capture_io(fn -> Cheer.run(TestInferRoot, []) end)
      assert output =~ "Tiny git"
      assert output =~ "COMMANDS:"
    end
  end

  # -- conflicts_with / requires ----------------------------------------------

  defmodule TestConflicts do
    use Cheer.Command

    command "conflicts" do
      about("Test conflicts_with")

      option(:json, type: :boolean, conflicts_with: :yaml, help: "JSON output")
      option(:yaml, type: :boolean, help: "YAML output")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestConflictsList do
    use Cheer.Command

    command "conflicts-list" do
      about("Test conflicts_with as a list")

      option(:json, type: :boolean, conflicts_with: [:yaml, :toml])
      option(:yaml, type: :boolean)
      option(:toml, type: :boolean)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestRequires do
    use Cheer.Command

    command "requires" do
      about("Test requires")

      option(:user, type: :string, requires: :password, help: "User")
      option(:password, type: :string, help: "Password")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestRequiresList do
    use Cheer.Command

    command "requires-list" do
      about("Test requires as a list")

      option(:deploy, type: :boolean, requires: [:env, :region])
      option(:env, type: :string)
      option(:region, type: :string)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "conflicts_with" do
    test "succeeds when only one of the conflicting options is set" do
      assert {:ok, %{json: true}} = Cheer.run(TestConflicts, ["--json"])
      assert {:ok, %{yaml: true}} = Cheer.run(TestConflicts, ["--yaml"])
    end

    test "errors when both conflicting options are set" do
      output = capture_io(fn -> Cheer.run(TestConflicts, ["--json", "--yaml"]) end)
      assert output =~ "error: --json cannot be used with --yaml"
    end

    test "fires regardless of CLI argument order (declaration order wins)" do
      # :yaml does not declare conflicts_with, but :json does. Validation
      # iterates options in declaration order, so the error message is always
      # phrased in terms of the option that owns the constraint.
      output = capture_io(fn -> Cheer.run(TestConflicts, ["--yaml", "--json"]) end)
      assert output =~ "error: --json cannot be used with --yaml"
    end

    test "succeeds when neither is set" do
      assert {:ok, _} = Cheer.run(TestConflicts, [])
    end

    test "list form errors on first conflict found" do
      output = capture_io(fn -> Cheer.run(TestConflictsList, ["--json", "--toml"]) end)
      assert output =~ "error: --json cannot be used with --toml"
    end

    test "list form succeeds when no conflicts present" do
      assert {:ok, _} = Cheer.run(TestConflictsList, ["--json"])
    end
  end

  describe "requires" do
    test "succeeds when both required options are present" do
      assert {:ok, %{user: "alice", password: "secret"}} =
               Cheer.run(TestRequires, ["--user", "alice", "--password", "secret"])
    end

    test "errors when option is set without its dependency" do
      output = capture_io(fn -> Cheer.run(TestRequires, ["--user", "alice"]) end)
      assert output =~ "error: --user requires --password"
    end

    test "succeeds when neither option is set" do
      assert {:ok, _} = Cheer.run(TestRequires, [])
    end

    test "list form errors when any required option is missing" do
      output = capture_io(fn -> Cheer.run(TestRequiresList, ["--deploy", "--env", "prod"]) end)
      assert output =~ "error: --deploy requires --region"
    end

    test "list form succeeds when all required options are present" do
      assert {:ok, _} =
               Cheer.run(TestRequiresList, ["--deploy", "--env", "prod", "--region", "us-east"])
    end
  end

  # -- required_if / required_unless ------------------------------------------

  defmodule TestRequiredIf do
    use Cheer.Command

    command "req-if" do
      about("Test required_if")

      option(:format, type: :string, choices: ["json", "table", "raw"], help: "Format")
      option(:output, type: :string, required_if: [format: "json"], help: "Output file")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestRequiredIfMulti do
    use Cheer.Command

    command "req-if-multi" do
      about("Test required_if with multiple conditions")

      option(:mode, type: :string, choices: ["dev", "prod", "test"])
      option(:env, type: :string)
      option(:secret, type: :string, required_if: [mode: "prod", env: "live"])
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestRequiredIfNonString do
    use Cheer.Command

    command "req-if-typed" do
      about("Test required_if with non-string trigger values")

      option(:retries, type: :integer)
      option(:dry_run, type: :boolean)
      option(:notify, type: :string, required_if: [retries: 0, dry_run: true])
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestRequiredUnless do
    use Cheer.Command

    command "req-unless" do
      about("Test required_unless")

      option(:config, type: :string, required_unless: :inline, help: "Config file")
      option(:inline, type: :boolean, help: "Use inline config")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestRequiredUnlessList do
    use Cheer.Command

    command "req-unless-list" do
      about("Test required_unless as a list")

      option(:input, type: :string, required_unless: [:stdin, :url])
      option(:stdin, type: :boolean)
      option(:url, type: :string)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "required_if" do
    test "not required when condition does not hold" do
      assert {:ok, _} = Cheer.run(TestRequiredIf, ["--format", "table"])
    end

    test "required when condition holds and missing" do
      output = capture_io(fn -> Cheer.run(TestRequiredIf, ["--format", "json"]) end)
      assert output =~ "error: --output is required when --format is 'json'"
    end

    test "succeeds when condition holds and option provided" do
      assert {:ok, _} =
               Cheer.run(TestRequiredIf, ["--format", "json", "--output", "out.json"])
    end

    test "not required when neither condition option is set" do
      assert {:ok, _} = Cheer.run(TestRequiredIf, [])
    end

    test "fires on the first matching condition in a multi-pair list" do
      output = capture_io(fn -> Cheer.run(TestRequiredIfMulti, ["--mode", "prod"]) end)
      assert output =~ "error: --secret is required when --mode is 'prod'"
    end

    test "fires when only the second condition matches" do
      output = capture_io(fn -> Cheer.run(TestRequiredIfMulti, ["--env", "live"]) end)
      assert output =~ "error: --secret is required when --env is 'live'"
    end

    test "matches integer trigger values" do
      output = capture_io(fn -> Cheer.run(TestRequiredIfNonString, ["--retries", "0"]) end)
      assert output =~ "error: --notify is required when --retries is 0"
    end

    test "matches boolean trigger values" do
      output = capture_io(fn -> Cheer.run(TestRequiredIfNonString, ["--dry-run"]) end)
      assert output =~ "error: --notify is required when --dry_run is true"
    end

    test "no match when integer value differs" do
      assert {:ok, _} = Cheer.run(TestRequiredIfNonString, ["--retries", "3"])
    end
  end

  describe "required_unless" do
    test "errors when option missing and dependency absent" do
      output = capture_io(fn -> Cheer.run(TestRequiredUnless, []) end)
      assert output =~ "error: --config is required unless --inline is provided"
    end

    test "succeeds when dependency is present" do
      assert {:ok, _} = Cheer.run(TestRequiredUnless, ["--inline"])
    end

    test "succeeds when option itself is present" do
      assert {:ok, _} = Cheer.run(TestRequiredUnless, ["--config", "app.conf"])
    end

    test "list form requires any one of the dependencies" do
      assert {:ok, _} = Cheer.run(TestRequiredUnlessList, ["--stdin"])
      assert {:ok, _} = Cheer.run(TestRequiredUnlessList, ["--url", "http://x"])
    end

    test "list form errors when none of the dependencies are present" do
      output = capture_io(fn -> Cheer.run(TestRequiredUnlessList, []) end)
      assert output =~ "error: --input is required unless --stdin, --url is provided"
    end
  end

  # -- Subcommand usage line (#37) ---------------------------------------------

  defmodule TestSubUsageLeaf do
    use Cheer.Command

    command "info" do
      about("Show detailed info for one instance")
      argument(:name, type: :string, required: true, help: "Instance name")
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  defmodule TestSubUsageRoot do
    use Cheer.Command

    command "demo" do
      about("Demo root")
      subcommand(TestSubUsageLeaf)
    end

    @impl Cheer.Command
    def run(args, _raw), do: {:ok, args}
  end

  describe "subcommand usage line (#37)" do
    test "missing-arg error shows full subcommand path in usage" do
      output = capture_io(fn -> Cheer.run(TestSubUsageRoot, ["info"]) end)
      assert output =~ "error: missing required argument(s): <name>"
      assert output =~ "Usage: demo info <name>"
    end

    test "subcommand --help shows full subcommand path in usage" do
      output = capture_io(fn -> Cheer.run(TestSubUsageRoot, ["info", "--help"]) end)
      assert output =~ "Usage: demo info <name>"
    end

    test "help <sub> also shows full subcommand path" do
      output = capture_io(fn -> Cheer.run(TestSubUsageRoot, ["help", "info"]) end)
      assert output =~ "Usage: demo info <name>"
    end

    test "caller-supplied :prog is extended, not replaced" do
      output =
        capture_io(fn -> Cheer.run(TestSubUsageRoot, ["info", "--help"], prog: "my-app") end)

      assert output =~ "Usage: my-app info <name>"
    end

    test "subcommand usage does not append bogus [-- <args>...]" do
      output = capture_io(fn -> Cheer.run(TestSubUsageRoot, ["info", "--help"]) end)
      refute output =~ "[-- <args>...]"
    end
  end
end

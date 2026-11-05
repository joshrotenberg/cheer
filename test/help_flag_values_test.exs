defmodule Cheer.HelpFlagValuesTest do
  # stderr capture is global, so silence assertions must not run concurrently.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  defmodule AcceptsHyphens do
    use Cheer.Command

    command "sub" do
      parse_only()
      aliases(["s"])
      version("1.2.3")

      option(:prompt, type: :string, short: :p, aliases: [:message], allow_hyphen_values: true)

      option(:pair,
        type: :string,
        short: :P,
        aliases: [:values],
        num_args: 2,
        allow_hyphen_values: true
      )

      option(:tags, type: :string, num_args: 1..3, allow_hyphen_values: true)
      option(:quiet, type: :boolean, short: :q)
      option(:verbose, type: :count, short: :v)
      option(:color, type: :string, default_missing_value: "always")
      option(:mode, type: :boolean)
      trailing_var_arg(:rest)
    end
  end

  defmodule RejectsHyphens do
    use Cheer.Command

    command "sub" do
      parse_only()
      option(:prompt, type: :string, short: :p, aliases: [:message])
      option(:pair, type: :string, short: :P, aliases: [:values], num_args: 2)
      option(:tags, type: :string, num_args: 1..3)
    end
  end

  defmodule Nested do
    use Cheer.Command

    command "ops" do
      aliases(["o"])
      subcommand(Cheer.HelpFlagValuesTest.AcceptsHyphens)
    end
  end

  defmodule Root do
    use Cheer.Command

    command "tool" do
      version("9.8.7")
      infer_subcommands(true)
      option(:quiet, type: :boolean, short: :q, global: true)

      option(:config,
        type: :string,
        short: :c,
        aliases: [:settings],
        global: true,
        allow_hyphen_values: true
      )

      option(:mode, type: :string, global: true)
      subcommand(Cheer.HelpFlagValuesTest.AcceptsHyphens)
      subcommand(Cheer.HelpFlagValuesTest.Nested)
    end
  end

  defmodule RejectingRoot do
    use Cheer.Command

    command "tool" do
      subcommand(Cheer.HelpFlagValuesTest.RejectsHyphens)
    end
  end

  defmodule External do
    use Cheer.Command

    command "external" do
      parse_only()
      external_subcommands(true)
      version("1.2.3")
      option(:prompt, type: :string, allow_hyphen_values: true)
    end
  end

  for errors <- [:print, :return] do
    describe "errors: #{inspect(errors)}" do
      @errors errors

      test "a long option consumes help and version tokens as values" do
        for value <- ["-h", "--help", "--version", "-V"] do
          assert_parsed(AcceptsHyphens, ["--prompt", value], @errors, %{prompt: value})
        end
      end

      test "short and long aliases consume help and version tokens as values" do
        for option <- ["-p", "--message"], value <- ["-h", "--help", "--version", "-V"] do
          assert_parsed(AcceptsHyphens, [option, value], @errors, %{prompt: value})
        end
      end

      test "subcommands consume their option values using their own declarations" do
        assert_parsed(Root, ["sub", "--prompt", "--version"], @errors, %{
          prompt: "--version"
        })
      end

      test "exact num_args counts consume help and version in either value position" do
        for option <- ["--pair", "-P", "--values"],
            values <- [["x", "-V"], ["-h", "x"], ["--help", "--version"]] do
          assert_parsed(AcceptsHyphens, [option | values], @errors, %{pair: values})
        end
      end

      test "a long option rejecting hyphen values reports usage errors" do
        for value <- ["-h", "--help", "--version", "-V"] do
          assert_usage_error(RejectsHyphens, ["--prompt", value], @errors)
        end
      end

      test "short and long aliases rejecting hyphen values report usage errors" do
        for option <- ["-p", "--message"], value <- ["-h", "--help", "--version", "-V"] do
          assert_usage_error(RejectsHyphens, [option, value], @errors)
        end
      end

      test "subcommand options rejecting hyphen values report usage errors" do
        assert_usage_error(RejectingRoot, ["sub", "--prompt", "--version"], @errors)
      end

      test "exact num_args options rejecting hyphen values report usage errors" do
        for option <- ["--pair", "-P", "--values"],
            values <- [["x", "-V"], ["-h", "x"], ["--help", "--version"]] do
          assert_usage_error(RejectsHyphens, [option | values], @errors)
        end
      end

      test "standalone long help still prints root help" do
        assert_help(Root, ["--help"], @errors, "Usage: tool")
      end

      test "standalone short help still prints subcommand help" do
        assert_help(Root, ["sub", "-h"], @errors, "Usage: tool sub")
      end

      test "help after a consumed ordinary value still prints help" do
        assert_help(AcceptsHyphens, ["--prompt", "x", "-h"], @errors, "Usage: sub")
      end

      test "help after a consumed help value still prints help" do
        assert_help(AcceptsHyphens, ["--prompt", "--help", "-h"], @errors, "Usage: sub")
      end

      test "real version flags still print version" do
        for argv <- [["--version"], ["-V"], ["--prompt", "x", "-V"], ["--prompt", "-h", "-V"]] do
          {result, stdout, stderr} =
            streams(fn -> Cheer.parse(AcceptsHyphens, argv, errors: @errors) end)

          assert result == :handled
          assert stdout == "sub 1.2.3\n"
          assert stderr == ""
        end
      end

      test "nested paths and subcommand aliases select the leaf option declarations" do
        for path <- [["ops", "sub"], ["o", "s"], ["op", "s"]] do
          assert_parsed(Root, path ++ ["-p", "-h"], @errors, %{prompt: "-h"})
        end
      end

      test "inherited globals consume values through long names, aliases and short names" do
        for path <- [["sub"], ["ops", "sub"]],
            option <- ["--config", "--settings", "-c"],
            value <- ["--help", "-V"] do
          assert_parsed(Root, path ++ [option, value], @errors, %{config: value})
        end
      end

      test "leaf declarations override inherited globals when determining value positions" do
        assert_help(Root, ["sub", "--mode", "-h"], @errors, "Usage: tool sub")
      end

      test "hoisted global booleans preserve subcommand help" do
        assert_help(Root, ["-q", "ops", "sub", "-h"], @errors, "Usage: tool ops sub")
      end

      test "inline values do not consume a following flag" do
        assert_parsed(AcceptsHyphens, ["--prompt=-h"], @errors, %{prompt: "-h"})
        assert_parsed(AcceptsHyphens, ["--message=--version"], @errors, %{prompt: "--version"})
        assert_help(AcceptsHyphens, ["--prompt=-h", "--help"], @errors, "Usage: sub")
        assert_help(AcceptsHyphens, ["--pair=x", "-h"], @errors, "Usage: sub")
      end

      test "help and version names with inline values are ordinary invalid options" do
        for token <- ["--help=true", "--version=true"] do
          assert_usage_error(AcceptsHyphens, [token], @errors)
        end
      end

      test "the terminator keeps subsequent help and version tokens positional" do
        assert_parsed(AcceptsHyphens, ["--", "--help", "-h", "--version", "-V"], @errors, %{
          rest: ["--help", "-h", "--version", "-V"]
        })
      end

      test "help follows booleans, counts and options with default_missing_value" do
        for option <- ["--quiet", "-q", "--verbose", "-v", "--color"] do
          assert_help(AcceptsHyphens, [option, "-h"], @errors, "Usage: sub")
        end
      end

      test "ranged num_args consume hyphen values through their maximum" do
        assert_parsed(AcceptsHyphens, ["--tags", "x", "-h", "-V"], @errors, %{
          tags: ["x", "-h", "-V"]
        })

        assert_help(AcceptsHyphens, ["--tags", "x", "y", "z", "-h"], @errors, "Usage: sub")
      end

      test "ranged num_args allow help after their required minimum without hyphen values" do
        assert_help(RejectsHyphens, ["--tags", "x", "-h"], @errors, "Usage: sub")
        assert_usage_error(RejectsHyphens, ["--tags", "-h"], @errors)
      end

      test "options before an external subcommand still consume help and version values" do
        for value <- ["-h", "--version"] do
          assert_parsed(
            External,
            ["--prompt", value, "other"],
            @errors,
            %{prompt: value, external_subcommand: {"other", []}},
            External
          )
        end
      end

      test "parent options after an external subcommand do not consume help flags" do
        assert_help(External, ["other", "--prompt", "-h"], @errors, "Usage: external")
      end

      test "parent options after an external subcommand do not consume version flags" do
        {result, stdout, stderr} =
          streams(fn ->
            Cheer.parse(External, ["other", "--prompt", "--version"], errors: @errors)
          end)

        assert result == :handled
        assert stdout == "external 1.2.3\n"
        assert stderr == ""
      end
    end
  end

  defp assert_parsed(command, argv, errors, expected, resolved_command \\ AcceptsHyphens) do
    {result, stdout, stderr} = streams(fn -> Cheer.parse(command, argv, errors: errors) end)

    assert {:ok, ^resolved_command, args} = result
    assert Map.take(args, Map.keys(expected)) == expected
    assert stdout == ""
    assert stderr == ""
  end

  defp assert_usage_error(command, argv, errors) do
    {result, stdout, stderr} = streams(fn -> Cheer.parse(command, argv, errors: errors) end)

    case errors do
      :print ->
        assert result == {:error, :usage}
        assert stderr =~ "error:"

      :return ->
        assert {:error, %Cheer.UsageError{message: message}} = result
        assert message != ""
        assert stderr == ""
    end

    assert stdout == ""
  end

  defp assert_help(command, argv, errors, usage) do
    {result, stdout, stderr} = streams(fn -> Cheer.parse(command, argv, errors: errors) end)

    assert result == :handled
    assert stdout =~ usage
    assert stderr == ""
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
end

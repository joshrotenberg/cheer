defmodule Cheer.MultiHyphenValuesTest do
  use ExUnit.Case, async: true

  defmodule Multi do
    use Cheer.Command

    command "multi" do
      parse_only()

      option(:prompt,
        type: :string,
        multi: true,
        short: :p,
        aliases: [:message],
        allow_hyphen_values: true
      )

      option(:defaulted,
        type: :string,
        multi: true,
        default: ["preset"],
        allow_hyphen_values: true
      )

      trailing_var_arg(:rest)
    end
  end

  defmodule PlainMulti do
    use Cheer.Command

    command "plain-multi" do
      parse_only()
      option(:prompt, type: :string, multi: true)
      option(:defaulted, type: :string, multi: true, default: ["preset"])
    end
  end

  defmodule Single do
    use Cheer.Command

    command "single" do
      parse_only()
      option(:prompt, type: :string, short: :p, aliases: [:message], allow_hyphen_values: true)
    end
  end

  defmodule External do
    use Cheer.Command

    command "external" do
      parse_only()
      external_subcommands(true)
      option(:prompt, type: :string, multi: true, allow_hyphen_values: true)
    end
  end

  for errors <- [:print, :return] do
    describe "errors: #{inspect(errors)}" do
      @errors errors

      test "preserves duplicate values from repeated occurrences" do
        assert {:ok, Multi, %{prompt: ["@-", "@-"]}} =
                 Cheer.parse(Multi, ["--prompt", "@-", "--prompt", "@-"], errors: @errors)
      end

      test "collects mixed hyphen and plain values in occurrence order" do
        argv = ["--prompt", "-x", "--prompt", "y", "-p", "--z", "--prompt=-w"]

        assert {:ok, Multi, %{prompt: ["-x", "y", "--z", "-w"]}} =
                 Cheer.parse(Multi, argv, errors: @errors)
      end

      test "collects repeated long, short and alias options" do
        for flag <- ["--prompt", "-p", "--message"] do
          argv = [flag, "-first", flag, "plain", flag, "--last"]

          assert {:ok, Multi, %{prompt: ["-first", "plain", "--last"]}} =
                   Cheer.parse(Multi, argv, errors: @errors)
        end
      end

      test "collects repeated inline values for long names and aliases" do
        for flag <- ["--prompt", "--message"] do
          argv = ["#{flag}=-first", "#{flag}=plain", "#{flag}=--last"]

          assert {:ok, Multi, %{prompt: ["-first", "plain", "--last"]}} =
                   Cheer.parse(Multi, argv, errors: @errors)
        end
      end

      test "combines aliases with long, short and inline occurrences" do
        argv = ["--message", "-alias", "--prompt", "plain", "-p", "--short", "--message=-inline"]

        assert {:ok, Multi, %{prompt: ["-alias", "plain", "--short", "-inline"]}} =
                 Cheer.parse(Multi, argv, errors: @errors)
      end

      test "returns a list for a single occurrence" do
        for argv <- [["--prompt", "-x"], ["-p", "-x"], ["--message", "-x"], ["--prompt=-x"]] do
          assert {:ok, Multi, %{prompt: ["-x"]}} = Cheer.parse(Multi, argv, errors: @errors)
        end
      end

      test "keeps collected values when the option terminator is reached" do
        argv = ["--prompt", "-first", "--prompt", "plain", "--", "--prompt", "-ignored"]

        assert {:ok, Multi, %{prompt: ["-first", "plain"], rest: ["--prompt", "-ignored"]}} =
                 Cheer.parse(Multi, argv, errors: @errors)
      end

      test "keeps collected values before an external subcommand" do
        argv = ["--prompt", "-first", "--prompt", "plain", "plugin", "--prompt", "-ignored"]

        assert {:ok, External,
                %{
                  prompt: ["-first", "plain"],
                  external_subcommand: {"plugin", ["--prompt", "-ignored"]}
                }} = Cheer.parse(External, argv, errors: @errors)
      end

      test "uses the same implicit default as an ordinary multi option" do
        assert {:ok, PlainMulti, %{prompt: expected}} =
                 Cheer.parse(PlainMulti, [], errors: @errors)

        assert expected == []
        assert {:ok, Multi, %{prompt: ^expected}} = Cheer.parse(Multi, [], errors: @errors)
      end

      test "uses the same explicit default as an ordinary multi option" do
        assert {:ok, PlainMulti, %{defaulted: expected}} =
                 Cheer.parse(PlainMulti, [], errors: @errors)

        assert expected == ["preset"]
        assert {:ok, Multi, %{defaulted: ^expected}} = Cheer.parse(Multi, [], errors: @errors)
      end

      test "single-value options keep the last occurrence for every spelling" do
        for flag <- ["--prompt", "-p", "--message"] do
          assert {:ok, Single, %{prompt: "--last"}} =
                   Cheer.parse(Single, [flag, "-first", flag, "plain", flag, "--last"],
                     errors: @errors
                   )
        end

        for flag <- ["--prompt", "--message"] do
          assert {:ok, Single, %{prompt: "--last"}} =
                   Cheer.parse(Single, ["#{flag}=-first", "#{flag}=plain", "#{flag}=--last"],
                     errors: @errors
                   )
        end

        argv = ["--message", "-alias", "--prompt", "plain", "-p", "--short", "--message=-inline"]

        assert {:ok, Single, %{prompt: "-inline"}} = Cheer.parse(Single, argv, errors: @errors)
      end
    end
  end
end

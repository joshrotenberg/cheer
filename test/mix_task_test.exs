defmodule Mix.Tasks.CheerHelperTest do
  use Cheer.MixTask

  command "cheer_helper_test" do
    about("Greet from a mix task")

    argument(:name, type: :string, required: true, help: "Who to greet")
    option(:loud, type: :boolean, short: :l, help: "SHOUT")
  end

  @impl Cheer.Command
  def run(%{name: name} = args, _raw) do
    greeting = "Hello, #{name}!"
    if args[:loud], do: String.upcase(greeting), else: greeting
  end
end

defmodule Cheer.MixTaskTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.CheerHelperTest

  test "run/1 dispatches to the command and returns its value" do
    assert CheerHelperTest.run(["world"]) == "Hello, world!"
    assert CheerHelperTest.run(["world", "--loud"]) == "HELLO, WORLD!"
  end

  test "run/1 exits with {:shutdown, 2} on a usage failure" do
    capture_io(fn ->
      assert catch_exit(CheerHelperTest.run([])) == {:shutdown, 2}
    end)
  end

  test "run/1 renders help with a `mix <task>` program name" do
    output = capture_io(fn -> CheerHelperTest.run(["--help"]) end)
    assert output =~ "mix cheer_helper_test"
  end

  test "@shortdoc defaults to the command about text" do
    assert Mix.Task.shortdoc(CheerHelperTest) == "Greet from a mix task"
  end

  test "derives the mix task name from the module" do
    assert Cheer.MixTask.__task_name__(CheerHelperTest) == "cheer_helper_test"

    assert Cheer.MixTask.__task_name__(Module.concat(["Mix", "Tasks", "Db", "Migrate"])) ==
             "db.migrate"
  end
end

defmodule Mix.Tasks.Greet do
  @moduledoc """
  Greet someone with style.

  A Cheer command driving a Mix task via `use Cheer.MixTask`, which generates the
  Mix `run/1` entry point (dispatch through the command, `mix greet` program
  name, and the `exit({:shutdown, 2})` idiom on a usage failure).

  ## Examples

      mix greet world
      mix greet world --loud --times 3
      GREET_GREETING=Hey mix greet Ada
      mix greet --help
  """

  use Cheer.MixTask

  command "greet" do
    about "Greet someone with style"

    argument :name, type: :string, required: true, help: "Who to greet"

    option :greeting, type: :string, default: "Hello", env: "GREET_GREETING",
      help: "Greeting word"

    option :loud, type: :boolean, short: :l, help: "SHOUT the greeting"

    option :times, type: :integer, short: :n, default: 1,
      validate: fn n -> if n in 1..10, do: :ok, else: {:error, "times must be 1-10"} end,
      help: "Repeat the greeting"
  end

  @impl Cheer.Command
  def run(%{name: name} = args, _raw) do
    greeting = "#{args[:greeting]}, #{name}!"
    greeting = if args[:loud], do: String.upcase(greeting), else: greeting

    for _ <- 1..args[:times] do
      Mix.shell().info(greeting)
    end

    :ok
  end
end

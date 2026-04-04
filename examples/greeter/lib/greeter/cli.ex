defmodule Greeter.CLI do
  @moduledoc """
  Minimal single-command example showing arguments, options, validation,
  defaults, and env var fallback.

  ## Try it

      mix run -e 'Greeter.CLI.main(["world"])'
      mix run -e 'Greeter.CLI.main(["world", "--loud"])'
      mix run -e 'Greeter.CLI.main(["world", "--greeting", "Hi"])'
      mix run -e 'Greeter.CLI.main(["world", "--times", "3"])'
      mix run -e 'Greeter.CLI.main(["--help"])'

  Or build as an escript:

      mix escript.build
      ./greeter world --loud --times 3
  """

  use Cheer.Command

  command "greeter" do
    about "Greet someone with style"
    version "1.0.0"

    argument :name, type: :string, required: true, help: "Who to greet"

    option :greeting, type: :string, default: "Hello", env: "GREETER_GREETING",
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
      IO.puts(greeting)
    end

    :ok
  end

  def main(argv) do
    Cheer.run(__MODULE__, argv, prog: "greeter")
  end
end

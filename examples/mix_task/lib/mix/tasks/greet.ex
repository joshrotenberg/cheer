defmodule Mix.Tasks.Greet do
  @shortdoc "Greet someone with style"

  @moduledoc """
  #{@shortdoc}

  A single Cheer command driving a Mix task. Because `Mix.Task` needs `run/1`
  and `Cheer.Command` needs `run/2`, one module can be both.

  ## Examples

      mix greet world
      mix greet world --loud --times 3
      GREET_GREETING=Hey mix greet Ada
      mix greet --help
  """

  use Mix.Task
  use Cheer.Command

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

  # Mix entry point. Delegate to Cheer and translate a usage failure into the
  # Mix exit idiom. Do not use Cheer.main/3 here: it calls System.halt, which
  # hard-kills the VM and skips Mix cleanup.
  @impl Mix.Task
  def run(argv) do
    case Cheer.run(__MODULE__, argv, prog: "mix greet") do
      {:error, :usage} -> exit({:shutdown, 2})
      other -> other
    end
  end

  # Cheer leaf handler. Runs once argv has parsed and validated cleanly.
  @impl Cheer.Command
  def run(%{name: name} = args, _raw) do
    greeting = "#{args[:greeting]}, #{name}!"
    greeting = if args[:loud], do: String.upcase(greeting), else: greeting

    for _ <- 1..args[:times] do
      IO.puts(greeting)
    end

    :ok
  end
end

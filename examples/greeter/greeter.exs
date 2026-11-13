#!/usr/bin/env elixir
# The greeter as a single-file script. No Mix project and no build step:
#
#     chmod +x greeter.exs
#     ./greeter.exs world --loud --times 3
#     ./greeter.exs --help

Mix.install([
  {:cheer, "~> 0.3"}
])

defmodule Greeter.CLI do
  use Cheer.Command

  command "greeter" do
    about("Greet someone with style")
    version("1.0.0")

    argument(:name, type: :string, required: true, help: "Who to greet")

    option(:greeting,
      type: :string,
      default: "Hello",
      env: "GREETER_GREETING",
      help: "Greeting word"
    )

    option(:loud, type: :boolean, short: :l, help: "SHOUT the greeting")

    option(:times,
      type: :integer,
      short: :n,
      default: 1,
      validate: fn n -> if n in 1..10, do: :ok, else: {:error, "times must be 1-10"} end,
      help: "Repeat the greeting"
    )
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
end

Cheer.main(Greeter.CLI, System.argv(), prog: "greeter")

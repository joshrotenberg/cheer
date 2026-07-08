defmodule GreetTask.MixProject do
  use Mix.Project

  def project do
    [
      app: :greet_task,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: deps()
    ]
  end

  defp deps do
    [
      {:cheer, path: "../.."}
    ]
  end
end

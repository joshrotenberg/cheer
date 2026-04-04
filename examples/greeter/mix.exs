defmodule Greeter.MixProject do
  use Mix.Project

  def project do
    [
      app: :greeter,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: deps(),
      escript: [main_module: Greeter.CLI]
    ]
  end

  defp deps do
    [
      {:cheer, path: "../.."}
    ]
  end
end

defmodule Devtool.MixProject do
  use Mix.Project

  def project do
    [
      app: :devtool,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: deps(),
      escript: [main_module: Devtool.CLI]
    ]
  end

  defp deps do
    [
      {:cheer, path: "../.."}
    ]
  end
end

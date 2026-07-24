defmodule Server.MixProject do
  use Mix.Project

  def project do
    [
      app: :server,
      version: "0.1.0",
      elixir: "~> 1.15",
      deps: deps()
    ]
  end

  # `mod:` is what makes Server.Application.start/2 the entry point. A Burrito
  # binary boots the BEAM and starts applications; it never calls a main
  # function, so this is where argv gets read.
  def application do
    [
      extra_applications: [:logger],
      mod: {Server.Application, []}
    ]
  end

  defp deps do
    [
      {:cheer, path: "../.."}
    ]
  end
end

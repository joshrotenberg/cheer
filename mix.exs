defmodule Cheer.MixProject do
  use Mix.Project

  @version "0.1.5"
  @source_url "https://github.com/joshrotenberg/cheer"

  def project do
    [
      app: :cheer,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Cheer",
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      dialyzer: [plt_file: {:no_warn, "_build/dev/dialyxir_#{System.otp_release()}.plt"}]
    ]
  end

  def application do
    [
      extra_applications: extra_applications(Mix.env())
    ]
  end

  # ExUnit is referenced by Cheer.Test (an in-process test helper) and is needed
  # at dev/test time so dialyzer can resolve ExUnit.CaptureIO. Production
  # releases must not bundle or start :ex_unit.
  defp extra_applications(:prod), do: [:logger]
  defp extra_applications(_), do: [:logger, :ex_unit]

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    A clap-inspired CLI framework for Elixir. Declarative command trees with
    typed options, validation, env var fallback, lifecycle hooks, param groups,
    shell completion, REPL mode, and in-process testing.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "getting_started",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "docs/getting_started.md",
        "docs/concepts.md",
        "docs/guides/options.md",
        "docs/guides/arguments.md",
        "docs/guides/subcommands.md",
        "docs/guides/validation.md",
        "docs/guides/constraints.md",
        "docs/guides/help_and_output.md",
        "docs/guides/lifecycle_hooks.md",
        "docs/guides/shell_completion.md",
        "docs/guides/repl.md",
        "docs/guides/testing.md",
        "docs/cookbook/greeter.md",
        "docs/cookbook/devtool.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        "Getting Started": ~r{^docs/(getting_started|concepts)\.md$},
        Guides: ~r{^docs/guides/.*\.md$},
        Cookbook: ~r{^docs/cookbook/.*\.md$}
      ]
    ]
  end
end

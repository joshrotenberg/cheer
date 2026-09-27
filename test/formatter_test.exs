defmodule Cheer.FormatterTest do
  use ExUnit.Case, async: true

  test ".formatter.exs exports every DSL macro that takes arguments" do
    {config, _} = Code.eval_file(".formatter.exs")
    exported = config |> Keyword.fetch!(:export) |> Keyword.fetch!(:locals_without_parens)

    missing =
      for {name, arity} <- Cheer.Command.DSL.__info__(:macros),
          arity > 0,
          {name, arity} not in exported,
          do: {name, arity}

    assert missing == [], "add these to .formatter.exs: #{inspect(missing)}"
  end
end

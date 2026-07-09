defmodule Cheer.Ansi do
  @moduledoc false
  # ANSI styling for help and error output, gated on an ANSI-capable terminal and
  # `NO_COLOR` being unset. When output is not a tty (piped, redirected, captured
  # in tests, CI), styling is disabled and text renders plain, so non-interactive
  # output is byte-for-byte unchanged.

  @doc "True when ANSI styling should be applied."
  def enabled? do
    IO.ANSI.enabled?() and System.get_env("NO_COLOR") in [nil, ""]
  end

  @doc "Wrap `text` in the given ANSI style (an atom or list of atoms) when enabled."
  def paint(text, style) do
    if enabled?() do
      # IO.ANSI.format/2 appends the reset itself when emit? is true.
      [style, text]
      |> List.flatten()
      |> IO.ANSI.format(true)
      |> IO.iodata_to_binary()
    else
      text
    end
  end

  @doc "Visible length of a string, ignoring ANSI escape sequences."
  def visible_length(string) do
    string
    |> String.replace(~r/\e\[[0-9;]*m/, "")
    |> String.length()
  end
end

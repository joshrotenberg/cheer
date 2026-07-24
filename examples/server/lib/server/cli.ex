defmodule Server.CLI do
  @moduledoc """
  The command tree. Nothing here knows it belongs to a long-running app: the
  interface is declared the same way as in an escript, and
  `Server.Application.start/2` decides what to do with the parse result.

  ## Try it

      mix run --no-halt -- serve
      mix run --no-halt -- serve --port 8080 --transport stdio
      mix run -- --help
      mix run -- serve --transport carrier-pigeon
  """

  use Cheer.Command

  command "server" do
    about "A long-running server with a CLI front end"
    version "1.0.0"

    subcommand Server.CLI.Serve
  end
end

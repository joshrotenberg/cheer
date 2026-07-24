defmodule Server.CLI.Serve do
  @moduledoc """
  The command that configures the supervision tree.

  `run/2` is never called: `Server.Application` uses `Cheer.parse/3`, which
  stops after validation and hands back the args. The callback is still part of
  the `Cheer.Command` behaviour, so it stays here for anything that dispatches
  this tree with `Cheer.run/3` instead, such as a test.
  """

  use Cheer.Command

  command "serve" do
    about "Start the server"

    option :port,
      type: :integer,
      short: :p,
      default: 4000,
      env: "SERVER_PORT",
      help: "Port to listen on"

    option :transport,
      type: :string,
      short: :t,
      default: "http",
      choices: ["http", "stdio"],
      help: "Transport to serve"
  end

  @impl Cheer.Command
  def run(args, _raw), do: {:serve, args}
end

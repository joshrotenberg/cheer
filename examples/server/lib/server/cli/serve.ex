defmodule Server.CLI.Serve do
  @moduledoc """
  The command that configures the supervision tree.

  `parse_only()` says this command is resolved with `Cheer.parse/3` and never
  dispatched, so there is no `run/2` here and the compiler does not ask for one.
  `Server.Application` decides what to do with the args.
  """

  use Cheer.Command

  command "serve" do
    parse_only()

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
end

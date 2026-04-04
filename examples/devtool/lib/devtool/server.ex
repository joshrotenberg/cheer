defmodule Devtool.Server do
  use Cheer.Command

  command "server" do
    about "Server management"

    subcommand Devtool.Server.Start
    subcommand Devtool.Server.Stop
  end
end

defmodule Devtool.Server.Start do
  use Cheer.Command

  command "start" do
    about "Start the dev server"

    option :port, type: :integer, short: :p, default: 4000, env: "DEV_PORT",
      validate: fn p -> if p in 1024..65535, do: :ok, else: {:error, "port must be 1024-65535"} end,
      help: "Port to listen on"

    option :host, type: :string, short: :H, default: "localhost", help: "Bind address"

    group :protocol, mutually_exclusive: true do
      option :http, type: :boolean, help: "Use HTTP"
      option :https, type: :boolean, help: "Use HTTPS"
    end
  end

  @impl Cheer.Command
  def run(args, _raw) do
    protocol = if args[:https], do: "https", else: "http"
    IO.puts("Starting server at #{protocol}://#{args[:host]}:#{args[:port]}")
    IO.puts("(started in #{elapsed(args)}ms)")
    :ok
  end

  defp elapsed(%{start_time: t}), do: System.monotonic_time(:millisecond) - t
  defp elapsed(_), do: 0
end

defmodule Devtool.Server.Stop do
  use Cheer.Command

  command "stop" do
    about "Stop the dev server"

    option :force, type: :boolean, short: :f, help: "Force stop without draining"
  end

  @impl Cheer.Command
  def run(args, _raw) do
    if args[:force] do
      IO.puts("Force stopping server...")
    else
      IO.puts("Gracefully stopping server...")
    end

    :ok
  end
end

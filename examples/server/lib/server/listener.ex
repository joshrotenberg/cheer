defmodule Server.Listener do
  @moduledoc """
  Stand-in for whatever the server actually runs. It exists to show that the
  parsed args reach the supervision tree as ordinary child arguments.
  """

  use GenServer

  require Logger

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  @impl GenServer
  def init(args) do
    Logger.info("listening on port #{args.port} over #{args.transport}")
    {:ok, args}
  end
end

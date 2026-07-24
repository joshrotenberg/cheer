defmodule Server.Application do
  @moduledoc """
  The entry point.

  A long-running app cannot use `Cheer.main/3`: `main/3` halts, and `start/2`
  has to return `{:ok, pid}` for the VM to keep running. `Cheer.parse/3`
  returns instead, so argv can configure the supervision tree, and the cases
  where there is nothing to supervise halt explicitly.

  `Cheer.argv/0` covers both the `mix run --no-halt -- serve` form and a
  Burrito binary, which does not populate `System.argv/0`.
  """

  use Application

  @impl true
  def start(_type, _args) do
    case Cheer.parse(Server.CLI, Cheer.argv(), prog: "server") do
      {:ok, Server.CLI.Serve, args} ->
        children = [{Server.Listener, args}]
        Supervisor.start_link(children, strategy: :one_for_one, name: Server.Supervisor)

      # Help or a version was printed. Nothing to run, so halt rather than
      # returning: start/2 has no "started nothing, exit cleanly" reply.
      :handled ->
        System.halt(0)

      # The error is already printed. 2 is the code Cheer.main/3 uses, via
      # Cheer.exit_code/1.
      {:error, :usage} ->
        System.halt(2)
    end
  end
end

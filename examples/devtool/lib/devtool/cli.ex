defmodule Devtool.CLI do
  @moduledoc """
  Multi-command CLI example with nested subcommands, lifecycle hooks,
  param groups, and shell completion.

  ## Try it

      mix run -e 'Devtool.CLI.main(["server", "start"])'
      mix run -e 'Devtool.CLI.main(["server", "start", "--port", "8080"])'
      mix run -e 'Devtool.CLI.main(["db", "migrate", "--target", "20240101"])'
      mix run -e 'Devtool.CLI.main(["db", "seed", "--env", "staging"])'
      mix run -e 'Devtool.CLI.main(["--help"])'
      mix run -e 'Devtool.CLI.main(["server", "--help"])'
  """

  use Cheer.Command

  command "devtool" do
    about "Developer toolkit"
    version "0.1.0"

    persistent_before_run fn args ->
      Map.put(args, :start_time, System.monotonic_time(:millisecond))
    end

    subcommand Devtool.Server
    subcommand Devtool.Db
  end

  def main(argv) do
    Cheer.run(__MODULE__, argv, prog: "devtool")
  end
end

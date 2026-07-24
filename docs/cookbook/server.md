# Long-running server: argv as configuration

An escript and a Mix task both assume the process exits when the command
returns. A server does not: argv configures a supervision tree that keeps
running afterwards. The command tree is declared the same way; only the entry
point changes.

Full runnable project: [`examples/server/`](https://github.com/joshrotenberg/cheer/tree/main/examples/server).

## The entry point

`Application.start/2` reads argv, and the parse result decides what to
supervise:

```elixir
defmodule Server.Application do
  use Application

  @impl true
  def start(_type, _args) do
    case Cheer.parse(Server.CLI, Cheer.argv(), prog: "server") do
      {:ok, Server.CLI.Serve, args} ->
        children = [{Server.Listener, args}]
        Supervisor.start_link(children, strategy: :one_for_one, name: Server.Supervisor)

      :handled ->
        System.halt(0)

      {:error, :usage} ->
        System.halt(2)
    end
  end
end
```

`mod:` in `mix.exs` is what makes this the entry point:

```elixir
def application do
  [
    extra_applications: [:logger],
    mod: {Server.Application, []}
  ]
end
```

## Why `parse/3` and not `main/3`

`Cheer.main/3` halts the VM. That is the whole point of an escript entry point
and exactly wrong here: `start/2` has to return `{:ok, pid}` for the VM to keep
running.

`Cheer.parse/3` stops after resolution and validation and hands back the matched
command with its args, so the command tree describes the interface and the
supervision tree consumes the result. `run/2` is never called.

`Cheer.run/3` also returns rather than halting, so it works too. The cost is
that the leaf handler becomes a stub whose only job is to smuggle the parsed
options back out through its return value:

```elixir
case Cheer.run(Server.CLI, Cheer.argv(), prog: "server") do
  {:serve, args}   -> Supervisor.start_link(children(args), strategy: :one_for_one)
  :ok              -> System.halt(0)
  {:error, :usage} -> System.halt(2)
end
```

That shape has a second problem: `run/3` returns `:ok` for `--help` and
`--version`, which is indistinguishable from a handler that legitimately
returns `:ok`. `parse/3` reports that case as `:handled` instead, so the caller
does not have to constrain what its own handlers may return.

Use `run/3` when the handlers do real work and returning a config value is
incidental; use `parse/3` when argv is configuration.

## Halting, and exit codes

`start/2` has no "started nothing, exit cleanly" reply, so the cases with
nothing to supervise halt explicitly. `2` for a usage failure is the code
`Cheer.main/3` uses; `Cheer.exit_code/1` is the same mapping if you would rather
not restate it:

```elixir
result ->
  System.halt(Cheer.exit_code(result))
```

## Burrito

Under [Burrito](https://github.com/burrito-elixir/burrito), the wrapper boots
the BEAM and starts your applications. It never calls a main function, so
`main_module` in the release config is metadata: `Application.start/2` is the
real entry point, and that is where argv has to be read.

A Burrito binary also does not populate `System.argv/0`. Its arguments arrive
through `Burrito.Util.Args.argv/0`, which is what `Cheer.argv/0` returns when
`Burrito.Util.running_standalone?/0` is true.

The guard matters as much as the call. Keying off "is Burrito loaded" rather
than "is Burrito driving this run" hijacks argv under `mix test` and
`iex -S mix`, where the arguments belong to the test runner or the shell.

Getting the argv source wrong fails silently rather than loudly: `System.argv/0`
returns `[]`, every option falls through to its default, and the binary does
something plausible but wrong. A `--transport stdio` that quietly stays on the
`:http` default starts a web server while the client waits forever for a
handshake.

## `start/2` runs in dev too

Every way of starting the application runs `start/2`, including `iex -S mix` and
`mix test`. Those pass no argv of their own, so a bare command tree prints help
and halts, taking the shell or the test run with it.

When that is a problem, gate the dispatch:

```elixir
@impl true
def start(_type, _args) do
  if Application.get_env(:server, :dispatch_argv?, true) do
    dispatch(Cheer.argv())
  else
    Supervisor.start_link([], strategy: :one_for_one, name: Server.Supervisor)
  end
end
```

```elixir
# config/test.exs
config :server, dispatch_argv?: false
```

## Testing

`parse/3` makes the command tree testable without starting anything: it is a
pure question about argv, and the supervision tree never enters into it.

```elixir
test "serve defaults to http on 4000" do
  assert {:ok, Server.CLI.Serve, args} = Cheer.parse(Server.CLI, ["serve"])
  assert args.port == 4000
  assert args.transport == "http"
end

test "an unknown transport is a usage failure" do
  assert Cheer.parse(Server.CLI, ["serve", "--transport", "carrier-pigeon"]) ==
           {:error, :usage}
end
```

`Cheer.Test.run/3` still covers the handler path for trees where the handlers do
work. See [Testing](../guides/testing.md).

## Run it

```sh
cd examples/server
mix deps.get

mix run --no-halt -- serve
# [info] listening on port 4000 over http

mix run --no-halt -- serve --port 8080 --transport stdio
# [info] listening on port 8080 over stdio

SERVER_PORT=9000 mix run --no-halt -- serve
# [info] listening on port 9000 over http

mix run -- --help
# Usage: server <COMMAND>
# ... (exits 0)

mix run -- serve --transport carrier-pigeon
# error: --transport must be one of: http, stdio
# (exits 2)
```

## What it shows

- **`Cheer.parse/3`** -- resolution and validation without dispatch, so argv can
  configure a supervision tree.
- **`Cheer.argv/0`** -- the right argv under `mix run`, an escript, and a
  Burrito binary.
- **`:handled`** -- help and version reported distinctly from a handler that
  returns `:ok`.
- **Explicit halts** -- `start/2` returns `{:ok, pid}` or the VM exits; there is
  no third option.
- **The dev-shell caveat** -- `start/2` also runs under `iex -S mix` and
  `mix test`.

## See also

- Cookbook: [Greeter](greeter.md) -- the same declarations as an escript that
  exits when the command returns.
- Cookbook: [Mix task](mix_task.md) -- the other entry point that must not halt
  the VM.
- Guides: [Testing](../guides/testing.md),
  [Help and output](../guides/help_and_output.md).

# Devtool: nested subcommands with hooks and groups

A multi-command developer toolkit. `devtool server start`, `devtool db
migrate`, etc. Exercises subcommand nesting, a persistent lifecycle hook,
per-command hooks, mutually exclusive option groups, choices, and cross-param
validation.

Full runnable project: [`examples/devtool/`](https://github.com/joshrotenberg/cheer/tree/main/examples/devtool).

## Layout

```
devtool
  server
    start   -- starts the dev server
    stop    -- stops it
  db
    migrate -- runs migrations
    seed    -- seeds the database
```

## The root

```elixir
defmodule Devtool.CLI do
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
```

`persistent_before_run` declared on the root propagates to every descendant.
Every leaf-command handler sees `args[:start_time]` regardless of which
subcommand was invoked.

## A branch: `server`

```elixir
defmodule Devtool.Server do
  use Cheer.Command

  command "server" do
    about "Server management"

    subcommand Devtool.Server.Start
    subcommand Devtool.Server.Stop
  end
end
```

Branches have no `run/2` -- cheer routes to children automatically.

## A leaf with a group and a validator: `server start`

```elixir
defmodule Devtool.Server.Start do
  use Cheer.Command

  command "start" do
    about "Start the dev server"

    option :port, type: :integer, short: :p, default: 4000, env: "DEV_PORT",
      validate: fn p -> if p in 1024..65535, do: :ok, else: {:error, "port must be 1024-65535"} end,
      help: "Port to listen on"

    option :host, type: :string, short: :H, default: "localhost", help: "Bind address"

    group :protocol, mutually_exclusive: true do
      option :http,  type: :boolean, help: "Use HTTP"
      option :https, type: :boolean, help: "Use HTTPS"
    end
  end

  @impl Cheer.Command
  def run(args, _raw) do
    protocol = if args[:https], do: "https", else: "http"
    IO.puts("Starting server at #{protocol}://#{args[:host]}:#{args[:port]}")
    IO.puts("(started in #{elapsed(args)}ms)")
  end

  defp elapsed(%{start_time: t}), do: System.monotonic_time(:millisecond) - t
  defp elapsed(_), do: 0
end
```

Passing both `--http --https` produces a friendly error from the group
constraint.

## A leaf with hooks, a parser, and a deprecated flag: `db migrate`

```elixir
defmodule Devtool.Db.Migrate do
  use Cheer.Command

  command "migrate" do
    about "Run database migrations"

    option :target,  type: :string, short: :t, help: "Target migration version"
    option :dry_run, type: :boolean, help: "Show what would be run without applying"

    # :parse turns the raw string into a domain value (a positive integer).
    option :steps, type: :string,
      parse: fn s ->
        case Integer.parse(s) do
          {n, ""} when n > 0 -> {:ok, n}
          _ -> {:error, "steps must be a positive integer"}
        end
      end,
      help: "Apply only this many pending migrations"

    # :deprecated shows a marker in help and warns to stderr on use.
    option :to, type: :string, deprecated: "use --target instead",
      help: "Deprecated alias for --target"

    before_run fn args ->
      IO.puts("Connecting to database...")
      args
    end

    after_run fn result ->
      IO.puts("Done.")
      result
    end
  end

  @impl Cheer.Command
  def run(args, _raw) do
    prefix = if args[:dry_run], do: "[dry run] ", else: ""
    limit  = if args[:steps], do: " (#{args[:steps]} step(s))", else: ""

    case args[:target] || args[:to] do
      nil    -> IO.puts("#{prefix}Running all pending migrations#{limit}...")
      target -> IO.puts("#{prefix}Migrating to version #{target}#{limit}...")
    end
  end
end
```

Hooks run in order: root `persistent_before_run`, then this command's
`before_run`, then `run/2`, then `after_run`. `--steps abc` fails before `run/2`
with `error: --steps: steps must be a positive integer`, and using `--to` prints
a deprecation warning to stderr.

## A leaf with choices and cross-param validation: `db seed`

```elixir
defmodule Devtool.Db.Seed do
  use Cheer.Command

  command "seed" do
    about "Seed the database"

    option :env, type: :string, default: "development",
      choices: ["development", "staging", "test"],
      help: "Target environment"

    option :clean, type: :boolean, help: "Truncate tables before seeding"

    # :value_delimiter splits one value into a list: --tables users,posts
    option :tables, type: :string, value_delimiter: ",",
      help: "Only seed these tables (comma-separated)"

    validate fn args ->
      if args[:clean] && args[:env] == "staging" do
        {:error, "cannot use --clean with staging environment"}
      else
        :ok
      end
    end
  end

  @impl Cheer.Command
  def run(args, _raw) do
    if args[:clean], do: IO.puts("Truncating tables...")

    case args[:tables] do
      nil    -> IO.puts("Seeding #{args[:env]} database...")
      tables -> IO.puts("Seeding #{args[:env]} database (tables: #{Enum.join(tables, ", ")})...")
    end
  end
end
```

Type coercion, choices validation, and the cross-param `validate` all run
before `run/2`. `--tables users,posts` arrives as `["users", "posts"]`.

## Run it

```sh
cd examples/devtool
mix deps.get

mix run -e 'Devtool.CLI.main(["server", "start", "--port", "8080", "--https"])'
# Starting server at https://localhost:8080
# (started in 0ms)

mix run -e 'Devtool.CLI.main(["db", "migrate", "--target", "20240101"])'
# Connecting to database...
# Migrating to version 20240101...
# Done.

mix run -e 'Devtool.CLI.main(["db", "seed", "--env", "staging", "--clean"])'
# error: cannot use --clean with staging environment

mix run -e 'Devtool.CLI.main(["db", "migrate", "--steps", "3"])'
# Connecting to database...
# Running all pending migrations (3 step(s))...
# Done.

mix run -e 'Devtool.CLI.main(["db", "seed", "--tables", "users,posts"])'
# Seeding development database (tables: users, posts)...

mix run -e 'Devtool.CLI.main(["server", "--help"])'
```

## Generate a reference document

`Cheer.Reference` walks the command tree and renders a markdown reference, handy
for a docs site:

```sh
mix run -e 'IO.puts(Cheer.Reference.generate(Devtool.CLI, :markdown, prog: "devtool"))'
```

## What it shows

- **Nested command tree** with branches that have no `run/2`.
- **Persistent lifecycle hook** propagated from the root to every leaf.
- **Per-command `before_run` / `after_run`** hooks.
- **Mutually exclusive option group** with auto-generated error message.
- **Choices** for string-enum options.
- **Cross-param validator** enforcing a rule across two options.
- **Custom parser** (`:parse`) turning `--steps` into a positive integer.
- **Deprecation marker** (`:deprecated`) on `--to`.
- **Delimited values** (`:value_delimiter`) splitting `--tables`.
- **Env var fallback** combined with a validator.
- **Markdown reference generation** via `Cheer.Reference`.

## See also

- Guides: [Subcommands](../guides/subcommands.md),
  [Lifecycle hooks](../guides/lifecycle_hooks.md),
  [Constraints](../guides/constraints.md).
- Next cookbook: [Mix task](mix_task.md) -- drive a `mix` command with the same
  command definition.

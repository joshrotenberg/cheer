# Script: a single-file CLI with Mix.install

A complete CLI in one executable `.exs` file. `Mix.install/2` declares the
dependencies at the top of the script, so there is no Mix project and no build
step: edit the file and run it.

## The script

`hexq` queries the hex.pm API. It uses [Req](https://hex.pm/packages/req) for
HTTP, which is the reason to reach for `Mix.install` over a plain `elixir`
script.

```elixir
#!/usr/bin/env elixir
Mix.install([
  {:cheer, "~> 0.3"},
  {:req, "~> 0.5"}
])

defmodule Hexq do
  use Cheer.Command

  command "hexq" do
    about "Query hex.pm from a single-file script"
    version "0.1.0"
    subcommand_required true

    subcommand Hexq.Info
    subcommand Hexq.Versions
  end

  def get!(path), do: Req.get!("https://hex.pm/api/" <> path).body
end

defmodule Hexq.Info do
  use Cheer.Command

  command "info" do
    about "Show a package's latest version and downloads"
    argument :package, type: :string, required: true
  end

  @impl Cheer.Command
  def run(%{package: name}, _raw) do
    pkg = Hexq.get!("packages/#{name}")

    IO.write("""
    #{pkg["name"]} #{pkg["latest_stable_version"]}
    downloads: #{pkg["downloads"]["all"]} all, #{pkg["downloads"]["recent"]} recent
    """)
  end
end

defmodule Hexq.Versions do
  use Cheer.Command

  command "versions" do
    about "List a package's releases"
    aliases ["v"]
    argument :package, type: :string, required: true
    option :limit, type: :integer, short: :n, default: 5, help: "How many to show"
  end

  @impl Cheer.Command
  def run(args, _raw) do
    "packages/#{args.package}"
    |> Hexq.get!()
    |> Map.fetch!("releases")
    |> Enum.take(args.limit)
    |> Enum.each(fn r -> IO.puts("#{r["version"]}  #{String.slice(r["inserted_at"], 0, 10)}") end)
  end
end

Cheer.main(Hexq, System.argv(), prog: "hexq")
```

The command modules are ordinary cheer commands; nothing about them is specific
to a script. The last line is the entry point. `Cheer.main/3` halts the VM with
exit code 0, or 2 on a usage error, as it does in an escript. `System.argv/0`
holds the arguments after the script name.

## Running it

```sh
chmod +x hexq.exs
./hexq.exs info cheer
./hexq.exs v cheer -n 3
./hexq.exs --help
```

The first run fetches and compiles the dependencies. Later runs reuse the
`Mix.install` cache, which is keyed on the dependency list and the Elixir and
OTP versions. Changing a dependency or upgrading Elixir compiles once more.
`MIX_INSTALL_DIR` moves the cache, and `Mix.install(deps, force: true)` rebuilds
it.

On an Apple Silicon Mac with Elixir 1.20 and OTP 29, `./hexq.exs --version`
took 3.7 to 4.4 seconds on the first run and about 0.4 to 0.5 seconds after
that, over a few runs. The same command as an escript took about 0.2 seconds.

## Formatting the script

`mix format` on a lone script has no Mix project to read cheer's exported
formatter settings from:

- With no `.formatter.exs`, it rewrites the DSL with parentheses
  (`about("...")`). The code still works.
- `import_deps: [:cheer]` fails with `Unknown dependency :cheer given to
  :import_deps`, because `import_deps` reads dependencies from a `mix.exs`.

To keep the DSL paren-free, put a `.formatter.exs` beside the script that
lists the macros it uses:

```elixir
[
  inputs: ["*.exs"],
  locals_without_parens: [
    about: 1,
    version: 1,
    subcommand_required: 1,
    subcommand: 1,
    command: 2,
    argument: 2,
    option: 2,
    aliases: 1
  ]
]
```

## Choosing a shape

| | Script (`Mix.install`) | Escript | Burrito binary |
|---|---|---|---|
| The user's machine needs | Elixir, and network access on the first run | Erlang/OTP | Nothing |
| Build step | None | `mix escript.build` | `mix release` per target |
| Startup | First run compiles; then the cost of starting Elixir | Starting the VM | Starting the VM; the first run also unpacks |
| Ships as | One source file | One file | One file per OS and architecture |

A script suits internal tools that change often and run where Elixir is
installed, and commands whose own work outlasts startup, such as calling a
remote API. An escript suits tools for machines with Erlang but not Elixir.
Burrito suits machines with neither.

## What it shows

- **`Mix.install/2`** -- dependencies declared in the script, cached between
  runs.
- **A full command tree in one file** -- a root, two subcommands, an alias, a
  typed option with a default, and `subcommand_required`.
- **`Cheer.main/3` as the last line** -- the same entry point and exit codes as
  an escript.

## See also

- Cookbook: [Greeter](greeter.md) -- the same kind of CLI built as an escript.
- Cookbook: [Server](server.md) -- Burrito binaries and `Cheer.argv/0`.
- Guides: [Help and output](../guides/help_and_output.md).

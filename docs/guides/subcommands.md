# Subcommands

Commands compose. Any command can register child modules as subcommands,
producing a tree of arbitrary depth.

## Basic nesting

```elixir
defmodule Devtool.CLI do
  use Cheer.Command

  command "devtool" do
    about "Developer toolkit"

    subcommand Devtool.Server
    subcommand Devtool.Db
  end
end

defmodule Devtool.Server do
  use Cheer.Command

  command "server" do
    about "Server management"

    subcommand Devtool.Server.Start
    subcommand Devtool.Server.Stop
  end
end
```

Each subcommand is a full command module with its own options, arguments,
help, and optional children.

## Require a subcommand

By default, invoking a parent command with no child shows help. To treat
that as an error instead:

```elixir
command "devtool" do
  subcommand_required true
  # ...
end
```

## Aliases

```elixir
defmodule MyApp.CLI.Checkout do
  use Cheer.Command

  command "checkout" do
    aliases ["co", "ck"]
    # ...
  end
end
```

`my-app co`, `my-app ck`, and `my-app checkout` all resolve to the same
module.

## Prefix inference

Allow any unambiguous prefix to resolve to a declared subcommand:

```elixir
command "git" do
  infer_subcommands true

  subcommand MyApp.CLI.Checkout
  subcommand MyApp.CLI.Status
end
```

```
git sta      -> status
git che      -> error: 'che' is ambiguous; candidates: check, checkout
```

Exact matches always win over prefix inference. Aliases are not
prefix-matched.

## "Did you mean?"

Unknown subcommands produce a typo suggestion:

```
$ my-app chekout
error: unknown command 'chekout'

  Did you mean 'checkout'?
```

Suggestions are ranked by Jaro distance and gated at 0.7 similarity.

## External subcommands (plugins)

Let a command accept unknown subcommand tokens and surface them to
`run/2`. Enables git-style plugin dispatchers:

```elixir
command "my-tool" do
  external_subcommands true
  subcommand MyApp.CLI.Status   # declared subs still take precedence
end

@impl Cheer.Command
def run(args, _raw) do
  case args[:external_subcommand] do
    {name, rest} -> System.cmd("my-tool-#{name}", rest)
    nil          -> :ok
  end
end
```

Behavior:

- Declared subcommands match first.
- First non-option token not matching a declared sub becomes the external
  subcommand name. Everything after it passes through verbatim, including
  flags the parent does not know about.
- `args[:external_subcommand]` is `nil` when no external sub was invoked,
  `{name, rest}` when one was. Pattern matches are total.

## Propagating version

By default only the root's `-V` / `--version` prints its version. To share
with children:

```elixir
command "my-tool" do
  version "1.0.0"
  propagate_version true
end
```

## Help for a specific subcommand

All of these show the same help:

```
my-tool server start --help
my-tool server start -h
my-tool help server start
```

## See also

- [Lifecycle hooks](lifecycle_hooks.md) for `persistent_before_run`, which
  applies to every descendant.
- [Help and output](help_and_output.md) for `display_order` on subcommands.

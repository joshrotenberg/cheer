# Lifecycle hooks

Run code before or after `run/2`. Handy for setup, teardown, logging, and
sharing state across a command tree.

## `before_run`

Runs after all parsing and validation, just before `run/2`. Receives the
`args` map, must return an `args` map.

```elixir
command "migrate" do
  option :target, type: :string

  before_run fn args ->
    IO.puts("Connecting to database...")
    args
  end
end
```

Use it to inject derived state into `args`, open connections, or log start
events.

## `after_run`

Runs after `run/2` returns. Receives the return value, must return a value
(typically the same one).

```elixir
after_run fn result ->
  IO.puts("Done.")
  result
end
```

Useful for cleanup, timing, or unconditional logging.

## `persistent_before_run` (inherited)

Like `before_run`, but inherited by every descendant command. Declared on
the root; runs for every subcommand invocation, before each command's own
`before_run` hooks.

```elixir
command "my-tool" do
  persistent_before_run fn args ->
    Map.put(args, :start_time, System.monotonic_time(:millisecond))
  end

  subcommand MyTool.Server
  subcommand MyTool.Db
end
```

Every leaf-command handler under `my-tool` sees `args[:start_time]`.

## Multiple hooks

Each hook macro can be called more than once. Hooks run in declaration
order.

```elixir
before_run &add_tracing/1
before_run &add_logger/1
before_run &add_timing/1
```

## Ordering

For a subcommand invocation, the full ordering is:

1. Every ancestor's `persistent_before_run` hooks, root-first.
2. This command's `before_run` hooks, declaration order.
3. `run/2`.
4. This command's `after_run` hooks, declaration order.

There is no `persistent_after_run` -- parent cleanup typically belongs in
the root handler or in explicit supervision logic.

## See also

- [Subcommands](subcommands.md) for how persistent hooks flow through
  nested trees.

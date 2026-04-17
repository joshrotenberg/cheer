# Testing

Cheer ships an in-process test runner that captures output and returns the
handler's return value. No subprocess, no argv escaping, no port juggling.

## Basic

```elixir
test "greet prints a greeting" do
  result = Cheer.Test.run(MyApp.CLI.Greet, ["world"])

  assert result.return == :ok
  assert result.output =~ "Hello, world!"
end
```

`Cheer.Test.run/3` takes the same arguments as `Cheer.run/3`: a command
module, argv, and an optional `prog`.

## Return shape

```elixir
%Cheer.Test{
  return: term(),       # whatever your run/2 returned (or :ok if cheer handled an error)
  output: String.t()    # everything written to stdout during the invocation
}
```

## Testing validation failures

When validation fails, cheer prints an error and does not invoke `run/2`.
Assert on the captured output:

```elixir
test "rejects out-of-range times" do
  result = Cheer.Test.run(MyApp.CLI.Greet, ["world", "--times", "100"])

  assert result.output =~ "must be 1-10"
  refute result.output =~ "Hello"
end
```

## Testing subcommand routing

```elixir
test "db migrate with a target" do
  result = Cheer.Test.run(Devtool.CLI, ["db", "migrate", "--target", "20240101"])

  assert result.output =~ "Migrating to version 20240101"
end
```

Same as production: the router walks the tree, parses each level's options,
and dispatches to the leaf's `run/2`.

## Testing help output

```elixir
test "help includes all subcommands" do
  result = Cheer.Test.run(Devtool.CLI, ["--help"])

  assert result.output =~ "server"
  assert result.output =~ "db"
end
```

## Integration tests

For end-to-end tests that exercise the real escript binary, use the
usual `System.cmd/2` against your built artifact. Cheer's test runner
is for fast, in-process unit tests of parsing and handler logic, not
for testing the escript launcher itself.

## See also

- [REPL mode](repl.md) -- interactive equivalent of the in-process
  runner.

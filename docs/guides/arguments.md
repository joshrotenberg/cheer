# Arguments

Positional inputs. Matched in declaration order.

## Basic

```elixir
command "greet" do
  argument :name, type: :string, required: true, help: "Who to greet"
end
```

```
greet world           # args[:name] == "world"
greet                 # error: missing required argument(s): <name>
```

## Types and coercion

```elixir
argument :port,    type: :integer
argument :ratio,   type: :float
argument :enabled, type: :boolean
argument :name,    type: :string   # default
```

## Optional arguments

Omit `required: true` to make an argument optional. Optional arguments must
follow all required ones in declaration order.

```elixir
argument :source, type: :string, required: true
argument :dest,   type: :string   # optional
```

## Value placeholders

Override the help-output name:

```elixir
argument :input, type: :string, value_name: "FILE"
# Usage: convert <FILE>
```

## Variadic arguments (`:num_args`)

An argument can collect several positional tokens into a list with `:num_args`,
an exact integer or a range:

```elixir
argument :files, type: :string, num_args: 1..3, help: "One to three files"
# a b c  ->  args[:files] == ["a", "b", "c"]

argument :point, type: :integer, num_args: 2
# 1 2    ->  args[:point] == [1, 2]
```

Consumption is greedy up to the max, so a variadic argument should be declared
last; a plain argument still takes exactly one token. Too few tokens is a usage
error (`<files> expects between 1 and 3 values, got 0`). This is a bounded
alternative to `trailing_var_arg`, which collects an unbounded rest.

## Trailing variadic args

Collect an arbitrary number of trailing tokens under a named key:

```elixir
command "exec" do
  argument :program, type: :string, required: true, help: "Program to run"
  trailing_var_arg :args, help: "Arguments to pass through"
end
```

```
exec ls -- -la /tmp
# args[:program] == "ls"
# args[:args]    == ["-la", "/tmp"]
```

If `required: true` is set on `trailing_var_arg`, at least one token must be
provided.

Without a declared `trailing_var_arg`, tokens after `--` are available as
`args[:rest]`.

## Validation

```elixir
argument :port, type: :integer,
  validate: fn p -> if p in 1024..65_535, do: :ok, else: {:error, "bad port"} end
```

See [Validation](validation.md) for more.

## Extended help (`:long_help`)

Like options, an argument can carry a longer description shown by `--help` (the
long form) while `:help` is used in the short `-h` output:

```elixir
argument :path, type: :string,
  help: "File to process",
  long_help: "Path to the input file. Relative paths resolve against the current directory."
```

## Hidden arguments

```elixir
argument :internal, type: :string, hide: true
```

Accepted by the parser; omitted from help output.

## Deprecated arguments

Mark an argument deprecated with `true` (a bare marker) or a string reason. The
marker shows in help:

```elixir
argument :path, type: :string, deprecated: "use --file instead"
```

## See also

- [Options](options.md) -- non-positional flags.
- [Help and output](help_and_output.md) -- `:display_order` for arguments.

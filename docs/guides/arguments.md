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

## Hidden arguments

```elixir
argument :internal, type: :string, hide: true
```

Accepted by the parser; omitted from help output.

## See also

- [Options](options.md) -- non-positional flags.
- [Help and output](help_and_output.md) -- `:display_order` for arguments.

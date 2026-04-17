# Options

Flags accepted by a command. Long form is derived from the atom name
(`:base_port` becomes `--base-port`); short aliases and every other behavior
are opt-in.

## Types

```elixir
option :port,    type: :integer
option :ratio,   type: :float
option :name,    type: :string     # default
option :verbose, type: :boolean    # also supports --no-verbose
option :v,       type: :count      # -vv -> 2
```

Typed values are coerced before your handler sees them. Invalid values
produce an error and never reach `run/2`.

## Short aliases

```elixir
option :port, type: :integer, short: :p
```

Accepts `-p 4000` or `--port 4000`.

## Defaults and env var fallback

```elixir
option :port, type: :integer, default: 4000, env: "PORT"
```

Priority: CLI flag > `PORT` env var > default.

## Choices

```elixir
option :format, type: :string, choices: ["json", "csv", "table"]
```

Rejected values produce an error before `run/2` runs.

## Repeated flags (`:multi`)

```elixir
option :tag, type: :string, multi: true
# --tag a --tag b  ->  args[:tag] == ["a", "b"]
```

Distinct from multi-value (consuming multiple tokens after one flag), which
is tracked as a future feature.

## Aliases (long-form)

```elixir
option :color, type: :string, aliases: [:colour]
# --color red and --colour red both set args[:color]
```

## Global options

Propagate an option to every subcommand:

```elixir
option :verbose, type: :boolean, global: true
```

Children inherit the option spec but can override by redeclaring.

## Hiding options

```elixir
option :internal, type: :boolean, hide: true
```

Still accepted by the parser, not shown in help.

## Boolean negation

Every boolean option automatically accepts its `--no-<name>` inverse:

```elixir
option :color, type: :boolean, default: true

# --color        -> true
# --no-color     -> false
```

## Putting it together

```elixir
option :port, type: :integer, short: :p,
  default: 4000, env: "PORT",
  validate: fn p -> if p in 1024..65_535, do: :ok, else: {:error, "invalid port"} end,
  help: "Port to listen on"
```

## See also

- [Validation](validation.md) for `:validate` and cross-param validators.
- [Constraints](constraints.md) for `:conflicts_with`, `:requires`,
  `:required_if`, `:required_unless`, and groups.
- [Help and output](help_and_output.md) for `:help_heading`, `:display_order`,
  and other presentation controls.

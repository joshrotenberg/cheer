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

## Multi-value flags (`:num_args`)

`:num_args` collects several values from a single flag invocation into a list.
Pass an integer for an exact count or a range for a variable count:

```elixir
option :point, type: :integer, num_args: 2
# --point 1 2   ->  args[:point] == [1, 2]

option :tags, type: :string, num_args: 1..3
# --tags a b c  ->  args[:tags] == ["a", "b", "c"]
```

Both the space-separated form (`--point 1 2`) and the `--flag=value` form work.
Collection stops at the next flag (a token starting with `-`) or at `--`, and
each value is coerced to the option's `:type`. A count outside the declared
range is a usage error:

```
--point 1   ->   error: --point expects 2 value(s), got 1
```

This is distinct from `:multi`, which repeats the whole flag (`--tag a --tag b`)
rather than consuming multiple tokens after one flag.

## Hyphen-leading values (`:allow_hyphen_values`)

A value that starts with `-` normally looks like a flag, so it is rejected.
Negative numbers are always accepted (`--range -5 5`). For other hyphen-leading
values, set `:allow_hyphen_values`:

```elixir
option :pattern, type: :string, allow_hyphen_values: true
# --pattern -v   ->  args[:pattern] == "-v"

option :range, type: :integer, num_args: 2, allow_hyphen_values: true
# --range -a -b  ->  args[:range] == ["-a", "-b"]
```

A single-value option consumes exactly the next token as its value, so a
following flag is still parsed normally (`--pattern x --verbose`). With
`:num_args`, collection consumes hyphen-leading tokens up to the declared count.

## Delimited values (`:value_delimiter`)

`:value_delimiter` splits one value on a string into a list:

```elixir
option :tags, type: :string, value_delimiter: ","
# --tags a,b,c  ->  args[:tags] == ["a", "b", "c"]

option :ids, type: :integer, value_delimiter: ","
# --ids 1,2,3   ->  args[:ids] == [1, 2, 3]
```

Each element is coerced to the option's `:type` and validated against
`:choices`. A string `:default` is split the same way, and it combines with
`:multi` (each occurrence is split and the results flattened). This differs
from `:num_args`, which reads several separate tokens after one flag.

## Custom value parsers (`:parse`)

`:parse` transforms a value into a domain type (an atom, a `Date`, a struct)
after `:type` coercion. See [Validation](validation.md) for the full contract:

```elixir
option :mode, type: :string, parse: fn
  "r" -> {:ok, :read}
  "w" -> {:ok, :write}
  _ -> {:error, "must be r or w"}
end
# --mode r  ->  args[:mode] == :read
```

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

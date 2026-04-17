# Validation

Three layers: type coercion (automatic), per-param validation (inline), and
cross-param validation (after all args are parsed).

## Per-param: choices

The cheapest form. Enumerate the accepted values:

```elixir
option :format, type: :string, choices: ["json", "csv", "table"]
```

Rejected values produce `error: --format must be one of: json, csv, table`.

Also works on arguments:

```elixir
argument :env, type: :string, choices: ["dev", "staging", "prod"]
```

## Per-param: inline validator

Any function that returns `:ok` or `{:error, message}`:

```elixir
option :port, type: :integer,
  validate: fn p ->
    if p in 1024..65_535, do: :ok, else: {:error, "port must be 1024-65535"}
  end
```

Runs after type coercion, so the value you receive is already the declared
type.

## Cross-param validators

Run after every option and argument has been parsed. Receives the full
`args` map.

```elixir
validate fn args ->
  cond do
    args[:tls] and is_nil(args[:cert]) -> {:error, "--tls requires --cert"}
    args[:since] && args[:until] && args[:since] > args[:until] ->
      {:error, "--since must be before --until"}
    true -> :ok
  end
end
```

You can declare multiple `validate` blocks per command. They run in
declaration order; the first `{:error, ...}` halts the pipeline.

## Order of evaluation

For a single invocation, validation runs in this order:

1. Type coercion (automatic, based on `:type`).
2. Defaults and env var fallback.
3. Required-argument and required-option checks.
4. Choices (`:choices`).
5. Per-param `:validate` functions.
6. Cross-param validators (`validate fn args -> ... end`).
7. Conditional-required (`:required_if`, `:required_unless`).
8. Per-option constraints (`:conflicts_with`, `:requires`).
9. Group constraints (`mutually_exclusive`, `co_occurring`).

The first failure halts; your `run/2` is only called if everything passes.

## See also

- [Constraints](constraints.md) for conditional-required, conflicts, requires,
  and groups.
- [Options](options.md) and [Arguments](arguments.md) for the declarations
  validation operates on.

# Constraints

Relational rules between options: when something must be present, when things
can coexist, when they cannot.

## Conditional required

### `:required_if`

Required when another option holds a specific value:

```elixir
option :format, type: :string, choices: ["json", "table"]
option :output, type: :string, required_if: [format: "json"]
```

```
error: --output is required when --format is 'json'
```

Multiple conditions: any match triggers the requirement.

```elixir
option :region, type: :string, required_if: [env: "prod", env: "staging"]
```

### `:required_unless`

Required unless any of the named options is present. Accepts an atom or a
list:

```elixir
option :config, type: :string, required_unless: :inline
option :config, type: :string, required_unless: [:inline, :stdin]
```

```
error: --config is required unless --inline, --stdin is provided
```

## Per-option relations

### `:conflicts_with`

Declares that two options cannot be set together:

```elixir
option :json, type: :boolean, conflicts_with: :yaml
option :json, type: :boolean, conflicts_with: [:yaml, :toml]
```

```
error: --json cannot be used with --yaml
```

### `:requires`

The inverse: setting one option implies another must also be set:

```elixir
option :user,   type: :string, requires: :password
option :deploy, type: :boolean, requires: [:env, :region]
```

```
error: --deploy requires --env
```

## Groups

Group a set of options under a named constraint.

### Mutually exclusive

At most one of the group's options can be set:

```elixir
group :format, mutually_exclusive: true do
  option :json, type: :boolean
  option :csv,  type: :boolean
  option :yaml, type: :boolean
end
```

```
error: options --json, --yaml are mutually exclusive (group: format)
```

### Co-occurring

All or none of the group's options must be set:

```elixir
group :auth, co_occurring: true do
  option :username, type: :string
  option :password, type: :string
end
```

```
error: options --username, --password must be used together (group: auth)
```

## Picking the right tool

- One option conditionally required based on another's **value**: `:required_if`.
- One option required unless another is **present**: `:required_unless`.
- Two or three specific options that must or must not coexist: `:conflicts_with`
  / `:requires` on a single option.
- A larger set of options with one constraint (format flags, auth flags):
  `group` with `mutually_exclusive` or `co_occurring`.
- Anything with its own logic: a cross-param `validate` function.

See [Validation](validation.md) for the latter.

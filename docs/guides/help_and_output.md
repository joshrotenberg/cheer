# Help and output

Cheer generates help from the same metadata you use to declare the command.
Customization is all opt-in.

## Short vs long help

Every command gets two help forms:

- `-h` prints short help, built from `about` and `help` fields.
- `--help` prints long help, preferring `long_about` over `about` and
  `long_help` over `help` where those are set.

```elixir
command "deploy" do
  about "Deploy to an environment"
  long_about """
  Deploy the current HEAD to a target environment. Accepts an environment
  name and an optional region.
  """
end

option :env, type: :string,
  help: "Target environment",
  long_help: "Target environment (one of: dev, staging, prod)"
```

## Before and after help

Wrap the auto-generated output with fixed text:

```elixir
command "my-app" do
  before_help "MyApp CLI\n"
  after_help "Report issues at github.com/me/my-app"
end
```

## Custom usage line

Override the auto-generated usage:

```elixir
command "deploy" do
  usage "my-app deploy [--env <ENV>] [--dry-run] [TARGET]"
end
```

## Grouping options under headings

Use `:help_heading` to put options under a custom section:

```elixir
option :host, type: :string, help_heading: "Network"
option :port, type: :integer, help_heading: "Network"
option :user, type: :string, help_heading: "Auth"
option :pass, type: :string, help_heading: "Auth"
```

Default behavior: options without a heading appear first under `OPTIONS:`,
then each custom heading appears in first-declaration order.

## Display order

Lower numbers appear first. Applies to options, arguments, and subcommands.

```elixir
option :verbose, type: :boolean, display_order: 1
option :quiet,   type: :boolean, display_order: 2

command "deploy" do
  display_order 1
end
```

Within any section, items without a `:display_order` fall back to
declaration order. Stable sort, so mixing explicit and implicit ordering is
predictable.

## Hiding from help

```elixir
option :internal, type: :boolean, hide: true
command "debug" do
  hide true
end
```

Still accepted by the parser; absent from help output.

## Flag naming

Cheer converts atom option names to kebab-case in both the parser and help
output. `:base_port` becomes `--base-port` everywhere. You do not need to
match them by hand.

## See also

- [Options](options.md) and [Arguments](arguments.md) for the declarations
  these settings decorate.
- [Subcommands](subcommands.md) for aliasing and prefix inference, both of
  which show up in help output.

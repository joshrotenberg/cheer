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

Hide an individual option or argument with `hide: true`:

```elixir
option :internal, type: :boolean, hide: true
argument :legacy, type: :string, hide: true
```

Hide a whole subcommand with the command-level `hide` setting:

```elixir
command "debug" do
  about "Internal diagnostics"
  hide true
end
```

Hidden items are still accepted by the parser and a hidden subcommand is still
dispatchable; they are only omitted from help output, shell completion, and the
"Available commands" list shown on an unknown-command error.

## Did you mean?

On an unknown command or an unknown flag, Cheer suggests the closest declared
name (by Jaro distance) if one is near enough:

```
$ myapp --colr red
error: unknown option(s): --colr

  Did you mean '--color'?
```

Flag suggestions match against declared option names and their aliases. A known
option given a bad value is not treated as a typo, so it never suggests the flag
you already typed. Subcommand suggestions work the same way on an unknown
command.

## Deprecation

Mark an option, argument, or subcommand deprecated with `:deprecated` (options
and arguments) or the `deprecated` command setting (subcommands). Pass `true`
for a bare marker or a string for a reason:

```elixir
option :old_flag, type: :string, deprecated: "use --new-flag"

command "old-name" do
  deprecated "use `new-name` instead"
end
```

Deprecated items still work. Help shows a `(deprecated)` marker (with the reason,
if given), and using a deprecated option or subcommand prints a warning to
stderr:

```
warning: --old-flag is deprecated: use --new-flag
warning: command 'old-name' is deprecated: use `new-name` instead
```

## Line wrapping

When help is printed to an interactive terminal, long option and argument
descriptions wrap to the terminal width, with continuation lines hanging-indented
under the description column. When output is not a tty (piped, redirected, or
captured in tests), descriptions render on single lines unchanged, so scripts
and snapshots stay stable.

## Flag naming

Cheer converts atom option names to kebab-case in both the parser and help
output. `:base_port` becomes `--base-port` everywhere. You do not need to
match them by hand.

## Exit codes

`Cheer.run/3` returns the matched command's own `run/2` value on success. On a
usage failure (unknown option, missing required argument, bad choice, unknown
or ambiguous subcommand, missing required subcommand) it prints the error and
returns `{:error, :usage}`. `--help` and `--version` return `:ok`.

To map that to a process exit code, either branch on the return value:

```elixir
def main(argv) do
  case Cheer.run(MyApp.CLI, argv) do
    {:error, :usage} -> System.halt(2)
    _ -> :ok
  end
end
```

or let `Cheer.main/3` halt for you with conventional codes (`0` ok, `2` usage):

```elixir
def main(argv), do: Cheer.main(MyApp.CLI, argv, prog: "myapp")
```

## See also

- [Options](options.md) and [Arguments](arguments.md) for the declarations
  these settings decorate.
- [Subcommands](subcommands.md) for aliasing and prefix inference, both of
  which show up in help output.

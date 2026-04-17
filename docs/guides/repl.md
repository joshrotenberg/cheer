# REPL mode

Run your command tree as an interactive shell. Same parsing, same validation,
same handlers.

## Start it

```elixir
Cheer.Repl.start(MyApp.CLI.Root, prog: "my-app")
```

```
my-app> greet world --loud
HELLO, WORLD!
my-app> db migrate --target 20240101
Connecting to database...
Migrating to version 20240101...
my-app> help
...
my-app> exit
```

## Built-in commands

- `help` / `?` -- print help for the root command (or a sub, with
  `help <sub>`).
- `exit` / `quit` / `Ctrl+D` -- leave the REPL.

## Tokenization

The REPL tokenizes each input line like a shell: whitespace-separated,
single and double quotes supported, backslash escapes inside strings.

```
my-app> greet "Ada Lovelace" --loud
my-app> run 'some command with spaces'
```

## Exit codes

REPL mode doesn't exit the host process on errors -- a failed command
prints its error and returns control to the prompt. That makes it safe to
embed inside longer-running tools.

## When to use it

- Interactive admin tools for long-lived services.
- Demo and teaching contexts where typing one command at a time beats
  typing a full invocation each turn.
- Workflows where you want the parser's validation without wrapping every
  call in a subshell.

## See also

- [Testing](testing.md) -- `Cheer.Test.run/3` gives you the same
  in-process execution without the interactive loop.

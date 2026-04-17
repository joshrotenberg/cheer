# Shell completion

Cheer generates completion scripts for bash, zsh, fish, and PowerShell from
the same command tree.

## Generate

```elixir
Cheer.Completion.generate(MyApp.CLI.Root, :bash,       prog: "my-app")
Cheer.Completion.generate(MyApp.CLI.Root, :zsh,        prog: "my-app")
Cheer.Completion.generate(MyApp.CLI.Root, :fish,       prog: "my-app")
Cheer.Completion.generate(MyApp.CLI.Root, :powershell, prog: "my-app")
```

All four return a string. Typical pattern: expose a hidden `completion`
subcommand that prints the script, then instruct users to source it.

```elixir
defmodule MyApp.CLI.Completion do
  use Cheer.Command

  command "completion" do
    about "Print a shell completion script"
    argument :shell, type: :string, required: true, choices: ~w(bash zsh fish powershell)
  end

  @impl Cheer.Command
  def run(%{shell: shell}, _raw) do
    shell = String.to_existing_atom(shell)
    IO.puts(Cheer.Completion.generate(MyApp.CLI.Root, shell, prog: "my-app"))
  end
end
```

## Installation (per shell)

### bash

```sh
# One-shot for the current session:
source <(my-app completion bash)

# Permanent:
my-app completion bash > ~/.bash_completion.d/my-app
```

### zsh

```sh
# In a directory on your fpath (e.g. ~/.zsh/completions):
my-app completion zsh > ~/.zsh/completions/_my-app

# Then in .zshrc:
fpath=(~/.zsh/completions $fpath)
autoload -U compinit && compinit
```

### fish

```sh
my-app completion fish > ~/.config/fish/completions/my-app.fish
```

### PowerShell

```powershell
# One-shot for the current session:
my-app completion powershell | Out-String | Invoke-Expression

# Permanent: append to $PROFILE
my-app completion powershell >> $PROFILE
```

## What gets completed

- Declared subcommands at each level of the tree.
- Long-form options (`--port`, `--no-verbose`) and short aliases (`-p`).
- For boolean options, the `--no-<name>` negation is included.
- `--help` is always in the completion set.

Value completion for option arguments (e.g. suggesting from `:choices`) is a
future enhancement.

## See also

- [Subcommands](subcommands.md) -- the tree that drives what gets completed.
- [Options](options.md) -- flag names, short aliases, boolean negation.

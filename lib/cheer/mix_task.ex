defmodule Cheer.MixTask do
  @moduledoc """
  Build a Mix task from a Cheer command.

  `use Cheer.MixTask` combines `use Mix.Task` and `use Cheer.Command` and
  generates the Mix `run/1` entry point. That entry point dispatches argv through
  the command with `Cheer.run/3`, using `mix <task>` as the program name in help
  and usage output, and translates a usage failure into `exit({:shutdown, 2})`,
  the Mix idiom for a nonzero exit.

  Declare the command with the usual DSL and implement the leaf `run/2`:

      defmodule Mix.Tasks.Greet do
        use Cheer.MixTask

        command "greet" do
          about "Greet someone"
          argument :name, type: :string, required: true
          option :loud, type: :boolean, short: :l
        end

        @impl Cheer.Command
        def run(%{name: name} = args, _raw) do
          greeting = "Hello, \#{name}!"
          greeting = if args[:loud], do: String.upcase(greeting), else: greeting
          Mix.shell().info(greeting)
        end
      end

  Then `mix greet world --loud` parses, validates, and renders help exactly like
  a standalone CLI.

  `@shortdoc` defaults to the command's `about` text when it is not set
  explicitly, so the task lists itself in `mix help`. Override `run/1` if the
  task needs to do its own setup (such as `Mix.Task.run("app.start")`) before
  dispatching.

  Do not use `Cheer.main/3` in a Mix task: it calls `System.halt`, which
  hard-kills the VM and skips Mix's cleanup. This helper uses `Cheer.run/3` and
  the `exit` idiom instead.
  """

  defmacro __using__(_opts) do
    quote do
      use Mix.Task
      use Cheer.Command

      @before_compile Cheer.MixTask

      @impl Mix.Task
      def run(argv) do
        prog = "mix " <> Cheer.MixTask.__task_name__(__MODULE__)

        case Cheer.run(__MODULE__, argv, prog: prog) do
          {:error, :usage} -> exit({:shutdown, 2})
          other -> other
        end
      end

      defoverridable run: 1
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    about = Module.get_attribute(env.module, :cheer_about)
    shortdoc = Module.get_attribute(env.module, :shortdoc)

    # Surface the command's `about` as the Mix @shortdoc (used by `mix help`)
    # unless the task set one explicitly.
    if is_nil(shortdoc) and is_binary(about) and about != "" do
      Module.put_attribute(env.module, :shortdoc, about)
    end

    :ok
  end

  @doc false
  # Derive the `mix` task name from the module: Mix.Tasks.Db.Migrate -> "db.migrate".
  def __task_name__(module) do
    case Module.split(module) do
      ["Mix", "Tasks" | rest] -> Enum.map_join(rest, ".", &Macro.underscore/1)
      parts -> Enum.map_join(parts, ".", &Macro.underscore/1)
    end
  end
end

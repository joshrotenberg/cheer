defmodule Devtool.Db do
  use Cheer.Command

  command "db" do
    about "Database management"

    subcommand Devtool.Db.Migrate
    subcommand Devtool.Db.Seed
  end
end

defmodule Devtool.Db.Migrate do
  use Cheer.Command

  command "migrate" do
    about "Run database migrations"

    option :target, type: :string, short: :t, help: "Target migration version"
    option :dry_run, type: :boolean, help: "Show what would be run without applying"

    before_run fn args ->
      IO.puts("Connecting to database...")
      args
    end

    after_run fn result ->
      IO.puts("Done.")
      result
    end
  end

  @impl Cheer.Command
  def run(args, _raw) do
    prefix = if args[:dry_run], do: "[dry run] ", else: ""

    case args[:target] do
      nil -> IO.puts("#{prefix}Running all pending migrations...")
      target -> IO.puts("#{prefix}Migrating to version #{target}...")
    end

    :ok
  end
end

defmodule Devtool.Db.Seed do
  use Cheer.Command

  command "seed" do
    about "Seed the database"

    option :env, type: :string, default: "development",
      choices: ["development", "staging", "test"],
      help: "Target environment"

    option :clean, type: :boolean, help: "Truncate tables before seeding"

    validate fn args ->
      if args[:clean] && args[:env] == "staging" do
        {:error, "cannot use --clean with staging environment"}
      else
        :ok
      end
    end
  end

  @impl Cheer.Command
  def run(args, _raw) do
    if args[:clean], do: IO.puts("Truncating tables...")
    IO.puts("Seeding #{args[:env]} database...")
    :ok
  end
end

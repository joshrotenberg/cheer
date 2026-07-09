defmodule Devtool.Db do
  use Cheer.Command

  command "db" do
    about("Database management")

    subcommand(Devtool.Db.Migrate)
    subcommand(Devtool.Db.Seed)
  end
end

defmodule Devtool.Db.Migrate do
  use Cheer.Command

  command "migrate" do
    about("Run database migrations")

    option(:target, type: :string, short: :t, help: "Target migration version")
    option(:dry_run, type: :boolean, help: "Show what would be run without applying")

    # :parse transforms the raw value into a domain value (a positive integer).
    option(:steps,
      type: :string,
      parse: fn s ->
        case Integer.parse(s) do
          {n, ""} when n > 0 -> {:ok, n}
          _ -> {:error, "steps must be a positive integer"}
        end
      end,
      help: "Apply only this many pending migrations"
    )

    # :deprecated shows a marker in help and warns to stderr on use.
    option(:to,
      type: :string,
      deprecated: "use --target instead",
      help: "Deprecated alias for --target"
    )

    before_run(fn args ->
      IO.puts("Connecting to database...")
      args
    end)

    after_run(fn result ->
      IO.puts("Done.")
      result
    end)
  end

  @impl Cheer.Command
  def run(args, _raw) do
    prefix = if args[:dry_run], do: "[dry run] ", else: ""
    limit = if args[:steps], do: " (#{args[:steps]} step(s))", else: ""

    case args[:target] || args[:to] do
      nil -> IO.puts("#{prefix}Running all pending migrations#{limit}...")
      target -> IO.puts("#{prefix}Migrating to version #{target}#{limit}...")
    end

    :ok
  end
end

defmodule Devtool.Db.Seed do
  use Cheer.Command

  command "seed" do
    about("Seed the database")

    option(:env,
      type: :string,
      default: "development",
      choices: ["development", "staging", "test"],
      help: "Target environment"
    )

    option(:clean, type: :boolean, help: "Truncate tables before seeding")

    # :value_delimiter splits one value into a list: --tables a,b,c
    option(:tables,
      type: :string,
      value_delimiter: ",",
      help: "Only seed these tables (comma-separated)"
    )

    validate(fn args ->
      if args[:clean] && args[:env] == "staging" do
        {:error, "cannot use --clean with staging environment"}
      else
        :ok
      end
    end)
  end

  @impl Cheer.Command
  def run(args, _raw) do
    if args[:clean], do: IO.puts("Truncating tables...")

    case args[:tables] do
      nil -> IO.puts("Seeding #{args[:env]} database...")
      tables -> IO.puts("Seeding #{args[:env]} database (tables: #{Enum.join(tables, ", ")})...")
    end

    :ok
  end
end

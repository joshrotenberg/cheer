# Used by "mix format"

# The DSL, paren-free, for projects that add `import_deps: [:cheer]` to their own .formatter.exs.
# Zero-arity forms (hide, deprecated, parse_only) are left out: without parens they read as
# variables. test/formatter_test.exs checks this list covers every DSL macro.
dsl = [
  about: 1,
  after_help: 1,
  after_run: 1,
  aliases: 1,
  args_conflicts_with_subcommands: 1,
  argument: 1,
  argument: 2,
  before_help: 1,
  before_run: 1,
  command: 2,
  deprecated: 1,
  display_order: 1,
  external_subcommands: 1,
  group: 3,
  hide: 1,
  infer_subcommands: 1,
  long_about: 1,
  option: 1,
  option: 2,
  parse_only: 1,
  persistent_before_run: 1,
  propagate_version: 1,
  subcommand: 1,
  subcommand_required: 1,
  trailing_var_arg: 1,
  trailing_var_arg: 2,
  usage: 1,
  validate: 1,
  version: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [locals_without_parens: dsl]
]

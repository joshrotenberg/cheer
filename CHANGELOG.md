# Changelog

## [0.2.0](https://github.com/joshrotenberg/cheer/compare/v0.1.5...v0.2.0) (2026-07-09)


### Features

* :parse custom value parsers ([#98](https://github.com/joshrotenberg/cheer/issues/98)) ([bc71aa9](https://github.com/joshrotenberg/cheer/commit/bc71aa977f45fbe18326aada0a0f0e20b9038a00)), closes [#72](https://github.com/joshrotenberg/cheer/issues/72)
* allow_hyphen_values for options, plus negative numbers in num_args ([#95](https://github.com/joshrotenberg/cheer/issues/95)) ([44b3d5a](https://github.com/joshrotenberg/cheer/commit/44b3d5a484712db1f875742fce262df7b219b4df)), closes [#64](https://github.com/joshrotenberg/cheer/issues/64) [#73](https://github.com/joshrotenberg/cheer/issues/73)
* args_conflicts_with_subcommands for optional subcommands ([#54](https://github.com/joshrotenberg/cheer/issues/54)) ([bbbf42c](https://github.com/joshrotenberg/cheer/commit/bbbf42cb4815a3bcfa85dbf5ae8f27eafec30bc7)), closes [#47](https://github.com/joshrotenberg/cheer/issues/47)
* Cheer.MixTask helper for building Mix tasks from Cheer commands ([#99](https://github.com/joshrotenberg/cheer/issues/99)) ([9af3a36](https://github.com/joshrotenberg/cheer/commit/9af3a368bcbf8240732e9135a2a020b46660f33e))
* colored help and error output ([#124](https://github.com/joshrotenberg/cheer/issues/124)) ([ffecec1](https://github.com/joshrotenberg/cheer/commit/ffecec1681c55daf4084b7e3893a4a5f97831e87)), closes [#102](https://github.com/joshrotenberg/cheer/issues/102)
* default_missing_value for a flag present with no value ([#122](https://github.com/joshrotenberg/cheer/issues/122)) ([921e51c](https://github.com/joshrotenberg/cheer/commit/921e51c398af9332fb35c4a285f8fef2907d670e)), closes [#103](https://github.com/joshrotenberg/cheer/issues/103)
* deprecation markers for options, arguments, and subcommands ([#120](https://github.com/joshrotenberg/cheer/issues/120)) ([8678086](https://github.com/joshrotenberg/cheer/commit/867808623bd0abbbf16c6a3dc4495339173a4c3a)), closes [#106](https://github.com/joshrotenberg/cheer/issues/106)
* implement command-level hide (fixes documented-but-missing setting) ([#78](https://github.com/joshrotenberg/cheer/issues/78)) ([ddb095b](https://github.com/joshrotenberg/cheer/commit/ddb095be556b7dade5302c24cf5d03fed4cf29be)), closes [#60](https://github.com/joshrotenberg/cheer/issues/60)
* markdown reference generation (Cheer.Reference) ([#125](https://github.com/joshrotenberg/cheer/issues/125)) ([2246274](https://github.com/joshrotenberg/cheer/commit/2246274f2386d644fe3d883c2b82a1b473cbbf0c))
* num_args for multi-value options ([#52](https://github.com/joshrotenberg/cheer/issues/52)) ([b784079](https://github.com/joshrotenberg/cheer/commit/b784079a0e4779807e5f2db308a33cc34f742a65)), closes [#27](https://github.com/joshrotenberg/cheer/issues/27)
* positional variadic arguments (num_args on positionals) ([#121](https://github.com/joshrotenberg/cheer/issues/121)) ([0c23cdc](https://github.com/joshrotenberg/cheer/commit/0c23cdcd2be9536d3782a3cc5ce2cad9268795ff)), closes [#104](https://github.com/joshrotenberg/cheer/issues/104)
* required (one-of) param group constraint ([#118](https://github.com/joshrotenberg/cheer/issues/118)) ([c2c94be](https://github.com/joshrotenberg/cheer/commit/c2c94be479e43b053da061e7ba47dbd5adf41c47)), closes [#100](https://github.com/joshrotenberg/cheer/issues/100)
* required_if_all and required_unless_all conditional-required variants ([#119](https://github.com/joshrotenberg/cheer/issues/119)) ([c50d3e2](https://github.com/joshrotenberg/cheer/commit/c50d3e25cb65e1904eb04b8560abc84bdaacad9e))
* signal usage failures so callers can set an exit code ([#53](https://github.com/joshrotenberg/cheer/issues/53)) ([c439049](https://github.com/joshrotenberg/cheer/commit/c4390495d5a8baae8269089357aa358993522dcc)), closes [#49](https://github.com/joshrotenberg/cheer/issues/49)
* suggest closest option name for an unknown flag ([#96](https://github.com/joshrotenberg/cheer/issues/96)) ([61019c7](https://github.com/joshrotenberg/cheer/commit/61019c77394cc63e6730f4ab7515e05f8f233044)), closes [#71](https://github.com/joshrotenberg/cheer/issues/71)
* value_delimiter to split a single value into a list ([#97](https://github.com/joshrotenberg/cheer/issues/97)) ([3926b21](https://github.com/joshrotenberg/cheer/commit/3926b213bb057d2915532bf68f67965f8132f664)), closes [#70](https://github.com/joshrotenberg/cheer/issues/70)
* warn on deprecated argument use; test: close audit coverage gaps ([#127](https://github.com/joshrotenberg/cheer/issues/127)) ([d7b0e7b](https://github.com/joshrotenberg/cheer/commit/d7b0e7b6efe484852f4a3b5aa8ea88c4f8b6d4e5))
* wrap long help descriptions to terminal width ([#123](https://github.com/joshrotenberg/cheer/issues/123)) ([fb60dce](https://github.com/joshrotenberg/cheer/commit/fb60dce8d07de322d3e046376a27302855260475)), closes [#101](https://github.com/joshrotenberg/cheer/issues/101)


### Bug Fixes

* argument-level validate and choices were never run ([#91](https://github.com/joshrotenberg/cheer/issues/91)) ([f5628b4](https://github.com/joshrotenberg/cheer/commit/f5628b40ceef53ff48bda70806e9a053e1ca52f2))
* evaluate option/argument opt values instead of storing AST ([#50](https://github.com/joshrotenberg/cheer/issues/50)) ([86722a8](https://github.com/joshrotenberg/cheer/commit/86722a8fa3460fb9d486bf42c60d91fe3ab03081)), closes [#48](https://github.com/joshrotenberg/cheer/issues/48)
* kebab-case option flags in bash/zsh/fish completions ([#90](https://github.com/joshrotenberg/cheer/issues/90)) ([791fbba](https://github.com/joshrotenberg/cheer/commit/791fbbaa6938e01b1e9a0ff944c91feb95e6a33a)), closes [#65](https://github.com/joshrotenberg/cheer/issues/65)
* low-severity correctness nits from the audit ([#93](https://github.com/joshrotenberg/cheer/issues/93)) ([44f31f9](https://github.com/joshrotenberg/cheer/commit/44f31f92e90a981ccd541075071825b1fb1d312b)), closes [#68](https://github.com/joshrotenberg/cheer/issues/68)
* no spurious n-in-[] warning for single-sided validate/parse commands ([#114](https://github.com/joshrotenberg/cheer/issues/114)) ([fa3b7bc](https://github.com/joshrotenberg/cheer/commit/fa3b7bca0decd2f730928a19193d07c7fee2e897)), closes [#108](https://github.com/joshrotenberg/cheer/issues/108)
* option constraints misfire on defaulted options (track user-supplied provenance) ([#77](https://github.com/joshrotenberg/cheer/issues/77)) ([ed6ee59](https://github.com/joshrotenberg/cheer/commit/ed6ee590075b9822705e753c3ac1f5318bdbf3ec)), closes [#59](https://github.com/joshrotenberg/cheer/issues/59)
* repeated lifecycle hooks and validators silently drop all but the first ([#76](https://github.com/joshrotenberg/cheer/issues/76)) ([07dc4cb](https://github.com/joshrotenberg/cheer/commit/07dc4cb4b785a1106114299c81756e44f3ee8dd5)), closes [#58](https://github.com/joshrotenberg/cheer/issues/58)
* **router:** coerce :count env fallback and support num_args on external subcommands ([#92](https://github.com/joshrotenberg/cheer/issues/92)) ([3f45baf](https://github.com/joshrotenberg/cheer/commit/3f45baf8e8e198a20c35c9c94864cffda0f4a48c)), closes [#66](https://github.com/joshrotenberg/cheer/issues/66) [#67](https://github.com/joshrotenberg/cheer/issues/67)
* **router:** external-subcommand feature parity, positional error labels, and user-fn exceptions ([#116](https://github.com/joshrotenberg/cheer/issues/116)) ([b0ddda3](https://github.com/joshrotenberg/cheer/commit/b0ddda31b8e8685de4caf932f3444fab8f61cf0d)), closes [#109](https://github.com/joshrotenberg/cheer/issues/109) [#110](https://github.com/joshrotenberg/cheer/issues/110) [#111](https://github.com/joshrotenberg/cheer/issues/111)


### Miscellaneous Chores

* release 0.2.0 ([#129](https://github.com/joshrotenberg/cheer/issues/129)) ([ee7b138](https://github.com/joshrotenberg/cheer/commit/ee7b1386b32d9dcef9e57eb667babd16c168076f))

## [0.1.5](https://github.com/joshrotenberg/cheer/compare/v0.1.4...v0.1.5) (2026-04-17)


### Features

* external_subcommands (plugin-style dispatchers) ([#44](https://github.com/joshrotenberg/cheer/issues/44)) ([8c35224](https://github.com/joshrotenberg/cheer/commit/8c35224d9a947fd7b487926614ab4ac7f19a4cbc))
* PowerShell completion generation ([#43](https://github.com/joshrotenberg/cheer/issues/43)) ([5919b94](https://github.com/joshrotenberg/cheer/commit/5919b94e4d8f75dd093f80b3abd61fbd267f2d24))


### Bug Fixes

* include subcommand path in usage line, drop bogus [-- &lt;args&gt;...] ([#42](https://github.com/joshrotenberg/cheer/issues/42)) ([58017ea](https://github.com/joshrotenberg/cheer/commit/58017ea6ac1c648e1f056fc72f9ef6092d90a797))
* render option names as kebab-case + warn on empty version ([#40](https://github.com/joshrotenberg/cheer/issues/40)) ([91cde25](https://github.com/joshrotenberg/cheer/commit/91cde255d8d6528b0f31da3a2203d1f376db28c9))

## [0.1.4](https://github.com/joshrotenberg/cheer/compare/v0.1.3...v0.1.4) (2026-04-10)


### Features

* add display_order and help_heading ([#32](https://github.com/joshrotenberg/cheer/issues/32)) ([5ac1e82](https://github.com/joshrotenberg/cheer/commit/5ac1e825ed531e12d3ff1439dd14e3eb031de2b4))
* infer subcommands from unique prefixes ([#34](https://github.com/joshrotenberg/cheer/issues/34)) ([90d456f](https://github.com/joshrotenberg/cheer/commit/90d456fd2279c91c76a3c35a321064bd136d7013))
* per-option constraints and conditional required ([#35](https://github.com/joshrotenberg/cheer/issues/35)) ([c70fbb3](https://github.com/joshrotenberg/cheer/commit/c70fbb316d35a4f590e2a4c3e255e2dd25dd089e)), closes [#19](https://github.com/joshrotenberg/cheer/issues/19) [#18](https://github.com/joshrotenberg/cheer/issues/18)

## [0.1.3](https://github.com/joshrotenberg/cheer/compare/v0.1.2...v0.1.3) (2026-04-05)


### Features

* add 5 quick-win features from clap parity analysis ([#30](https://github.com/joshrotenberg/cheer/issues/30)) ([626bd7d](https://github.com/joshrotenberg/cheer/commit/626bd7d19a3fe951f0be826aa91720ac2da8e4b3))
* add clap parity batch 1 -- 6 new features ([#29](https://github.com/joshrotenberg/cheer/issues/29)) ([10aabb1](https://github.com/joshrotenberg/cheer/commit/10aabb1fe5b5910a4917860a0e0994005f009695))
* support `help` subcommand for displaying subcommand help ([#7](https://github.com/joshrotenberg/cheer/issues/7)) ([8431c54](https://github.com/joshrotenberg/cheer/commit/8431c549a74a46ae80739ceaef20115d0e28e19d))

## [0.1.2](https://github.com/joshrotenberg/cheer/compare/v0.1.1...v0.1.2) (2026-04-04)


### Features

* add OptionParser compatibility features ([#5](https://github.com/joshrotenberg/cheer/issues/5)) ([a2d1121](https://github.com/joshrotenberg/cheer/commit/a2d11218fb6d8beca178d92db8e179b77ca726e3))

## [0.1.1](https://github.com/joshrotenberg/cheer/compare/v0.1.0...v0.1.1) (2026-04-04)


### Features

* add docs for all public APIs and standalone examples ([#3](https://github.com/joshrotenberg/cheer/issues/3)) ([1dc77cc](https://github.com/joshrotenberg/cheer/commit/1dc77cc47bea492b909dfa9bc4f3818c0af42dec))
* add release-please and CI badges ([#1](https://github.com/joshrotenberg/cheer/issues/1)) ([b2e0a35](https://github.com/joshrotenberg/cheer/commit/b2e0a35b862dbcc0d1a62acfa02a215a807f590f))
* initial release of Cheer CLI framework ([be40176](https://github.com/joshrotenberg/cheer/commit/be401767e89f205c350d595f52774a1ac9c2c883))

# Releasing

A new tag deploys within five minutes, so releases stay manual. Work down this list for each one.

1. Run `mise run release --dry-run` for the version's name and the commit it will tag.
2. Move `[Unreleased]` in `CHANGELOG.md` under that version, dated by the UTC day, and add its compare link.
3. Push `main` and wait for CI to pass on that commit. `mise run release --dry-run` prints its CI state.
4. Run `mise run release`. It checks the changelog and CI, tags the newest non-empty commit and prints the push command.

In an emergency, `mise run release --skip-ci` tags without the CI check and says it skipped it.

A shipped migration never changes, and its spec rolls the database back past every later migration. One later
`down` that cannot run would break it. So `mise run release`, `--dry-run` too, refuses while a file under `spec/` names
a migration a tag already holds, and lists each one. Delete the spec, or take the migration out of it.

# Releasing

A new tag deploys within five minutes, so releases stay manual. Work down this list for each one.

1. Run `mise run release --dry-run` for the version's name, the commit it will tag and the new variables.
2. Do what the release needs on the Pi before you tag it. The dry run lists each variable `.env.example` gained
  since the last tag. Set each one you need in the shared `.env` and restart both units. A new
  `HONEYBADGER_CHECK_IN_*` is optional, so leave it unset unless you want Honeybadger to watch that job. Then read
  `git diff <last tag> -- docs/deploy.md` and do each new item, such as a package or a change to the deploy script.
  [Deploy](deploy.md) lists what the Pi needs.
3. Run `/changelog <version>` to move `[Unreleased]` under that version, dated by the UTC day, with its compare links.
4. Push `main` and wait for CI to pass on that commit. `mise run release --dry-run` prints its CI state.
5. Run `mise run release`. It checks the changelog and CI, tags the newest non-empty commit and prints the push command.

In an emergency, `mise run release --skip-ci` tags without the CI check and says it skipped it.

A shipped migration never changes, and its spec rolls the database back past every later migration. One later
`down` that cannot run would break it. So `mise run release`, `--dry-run` too, refuses while a file under `spec/` names
a migration a tag already holds, and lists each one. Delete the spec, or take the migration out of it.

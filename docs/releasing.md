# Releasing

A new tag deploys within five minutes, so releases stay manual. Work down this list for each one.

1. Run `mise run release --dry-run` for the version's name and the commit it will tag.
2. Move `[Unreleased]` in `CHANGELOG.md` under that version, dated by the UTC day, and add its compare link.
3. Run `mise run release`. It checks the changelog, tags the newest non-empty commit and prints the push command.
4. Delete the spec of each migration the tag shipped.

A shipped migration never changes, and its spec rolls the database back past every later migration. One later
`down` that cannot run would break it.

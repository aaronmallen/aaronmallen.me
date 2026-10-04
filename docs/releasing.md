# Releasing

A new tag deploys within five minutes, so releases stay manual. Work down this list for each one.

1. Run `mise run release:next` for the version's name.
2. Move `[Unreleased]` in `CHANGELOG.md` under that version, dated by the UTC day, and add its compare link.
3. Give the commit an annotated tag named for the version.
4. Delete the spec of each migration the tag shipped.

A shipped migration never changes, and its spec rolls the database back past every later migration. One later
`down` that cannot run would break it.

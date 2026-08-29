---
id: "0046"
title: Let the garbage collector take a superseded MaxMind reader
status: active
created: 2026-09-28
area: [analytics]
issue: AA-681
tags: [analytics, geolite2, maxmind, concurrency]
---

# ADR 0046: Let the garbage collector take a superseded MaxMind reader

![Active][status]

## Context

`Analytics::Countries` (`lib/analytics/countries.rb`) looks a visitor's country up in a GeoLite2 database at
`tmp/maxmind/GeoLite2-Country.mmdb`, the path `Analytics::Providers::GeoProvider::DATABASE_PATH` names.
`Analytics::Jobs::RefreshCountryDatabase` downloads a fresh copy at 03:00 each Wednesday (`config/sidekiq.yml.erb`),
and `Countries#replace` writes it beside the old file and renames it into place.

`Analytics::Providers::GeoProvider::Databases` (`lib/analytics/providers/geo_provider.rb`) holds the open reader for
a path against a stamp of that file's inode, mtime and size. When the stamp moves it opens a new reader and lets the
old one go without calling `close`. The `geo` provider's `stop` closes whatever it still holds
(`slices/analytics/config/providers/geo.rb`).

A rotation therefore looks like a leak. It is not, because of how the reader opens. `Countries#open_database` opens
every database with `MaxMind::DB::MODE_MEMORY`, which reads the file into one frozen Ruby string and answers every
lookup out of that string. In maxmind-db 1.5.0, `MemoryReader#close` is an empty method. There is no file handle,
no mapping and no finalizer, so the string goes when the last reference to the reader goes, which is what letting
it go does.

Closing on rotation is not free either. A lookup already running holds the reader it was handed, and the swap
happens under the `Databases` mutex while that lookup runs outside it. Closing there would be safe only with a
reference count, and the count would exist to call a method that does nothing.

## Decision

`Databases` lets a superseded reader go without closing it. No reference count, no finalizer. `Countries#replace`
drops the reader it opens to check a download the same way. The provider's `stop` still closes what it holds,
because there the process is going away and nothing is mid-lookup.

Every reader opens with `MODE_MEMORY`. The mode is part of this decision, not a detail of it.

## Alternatives

**Count references and close at zero.** Correct under any mode, and the only safe way to close a reader a lookup
may still hold. It buys nothing today: the close it would end up calling does nothing, and the count is state the
lookup path has to keep on every call.

**Close the old reader as soon as the stamp moves.** One line, and wrong. It is safe only because `close` does
nothing; the day a reader holds a real handle, this closes it under a running lookup.

## Consequences

A superseded database holds its memory until the garbage collector gets to it, so a rotation can briefly hold two
copies of the country database. It is a few megabytes, once a week.

Anyone who moves `Countries` off `MODE_MEMORY` takes on a real leak and a real race in the same change. The mode
lives in one place, `Countries#open_database`, and this record is the reason it is not a setting.

The file sits under `tmp/` and nothing fetches it at boot, so a fresh host looks up no country until the first
Wednesday run. Until then `Analytics::Queries::CountryDatabaseFailure` reports the database missing to the admin
once settings hold a MaxMind account ID and license key. AA-307 has to plan for that on the Pi.

[status]: https://img.shields.io/badge/Active-green?style=for-the-badge

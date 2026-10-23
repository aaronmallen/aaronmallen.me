# frozen_string_literal: true

shares = Shares::Slice
held = [
  shares["repos.share_queries"].totals[:count], shares["repos.share_group_queries"].count,
  shares["repos.short_link_queries"].totals[:count],
]
return if held.sum.positive?

share_mutations = shares["repos.share_mutations"]
share = lambda do |filename, content_type, byte_size, download_count = 0|
  share_mutations.create(key: ObjectStore::Key.generate, filename:, content_type:, byte_size:, download_count:)
end

share.call("resume.pdf", "application/pdf", 182_044, 12)
share.call("garden-plan.png", "image/png", 734_210, 3)
share.call("slides.key", "application/octet-stream", 5_402_118)
photos = [
  share.call("hallway-before.jpg", "image/jpeg", 2_301_554),
  share.call("hallway-after.jpg", "image/jpeg", 2_118_903),
]
group = Seeds.unwrap(shares["operations.group_shares"].call(photos))
Seeds.unwrap(shares["operations.name_share_group"].call(group.id, { name: "Hallway paint" }))

create_short_link = shares["operations.create_short_link"]
[
  ["https://example.org/hanami", "Hanami", nil],
  ["https://example.org/postgres/domains", "Postgres domains", "pgdomains"],
  ["https://example.com/talks/admin-is-a-second-app", "Your admin is a second app", "talk"],
].each { |destination, title, code| Seeds.unwrap(create_short_link.call({ destination:, title:, code: })) }

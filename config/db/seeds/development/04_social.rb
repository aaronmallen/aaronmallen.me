# frozen_string_literal: true

return if Social::Slice["repos.person_queries"].all.any?

save_person = Social::Operations::SavePerson.new(networks: Seeds.networks)
[
  { key: "ada", name: "Ada Example", bluesky_handle: "ada.example.com", mastodon_handle: "@ada@social.example.com" },
  { key: "grace", name: "Grace Example", bluesky_handle: "grace.example.org", mastodon_handle: nil },
  { key: "linus", name: "Linus Example", bluesky_handle: nil, mastodon_handle: "@linus@toot.example.net" },
].each { Seeds.unwrap(save_person.call(it)) }

save_social_post = Social::Slice["operations.save_social_post"]
both = %w[bluesky mastodon]

draft = Seeds.unwrap(
  save_social_post.call(
    parts: ["Pairing with @{ada} on the seeds this week. Teh diff is huge."], targets: both, status: "draft",
  ),
)

Seeds.unwrap(
  save_social_post.call(
    parts: [
      "A short thread on what I learned moving this blog to Hanami.",
      "Slices kept each feature apart, so I could move one at a time.",
      "Phlex let me write views as Ruby, which @{grace} talked me into.",
    ],
    targets: both, status: "scheduled", posted_at: Time.now + (2 * 24 * Seeds::HOUR),
  ),
)

thread = Seeds.unwrap(
  save_social_post.call(
    parts: ["Postgres domains are underrated.", "Name a rule once and every table checks it the same way."],
    targets: both, status: "scheduled", posted_at: Seeds.ago(5, hour: 11),
  ),
)

article = Posts::Slice["repos.post_queries"].published_by_slug("moving-the-blog-to-hanami-3")
announcement = Seeds.unwrap(
  save_social_post.call(
    parts: [Posts::Slice["operations.compose_announcement"].call(article)], post_id: article.id, targets: both,
    status: "scheduled", posted_at: article.published_at,
  ),
)

add_connection = Services::Slice["repos.connection_mutations"]
bluesky = add_connection.add(
  provider: "bluesky", account_id: "did:plc:ada", label: "@ada.example.com",
  credentials: { app_password: "seed", handle: "ada.example.com" },
)
mastodon = add_connection.add(
  provider: "mastodon", host: "social.example.com", account_id: "1", label: "@ada@social.example.com",
  credentials: { access_token: "seed" }, scopes: %w[write:statuses read:accounts read:search read:statuses],
)

deliver = Social::Operations::DeliverSocialPost.new(networks: Seeds.networks)
[bluesky, mastodon].each { Seeds.unwrap(deliver.call(thread.id, it.id)) }
Seeds.unwrap(deliver.call(announcement.id, mastodon.id))
Seeds.unwrap(deliver.give_up(announcement.id, bluesky.id))
social_posts = Social::Slice["relations.social_posts"]
social_posts.by_pk(thread.id).command(:update).call(posted_at: Seeds.ago(5, hour: 11))
social_posts.by_pk(announcement.id).command(:update).call(posted_at: article.published_at)

Seeds.unwrap(
  Suggestions::Slice["operations.replace_social_post_edits"].call(
    draft.id, edits: [{ original: "Teh", replacement: "The", reason: "Spelling.", part: 1 }],
  ),
)

postgres = Posts::Slice["repos.post_queries"].published_by_slug("domains-in-postgres")
visitor_hashes = Analytics::Slice["operations.hash_visitor"].throttle_hashes("192.0.2.10")
target = ->(post) { Hanami.app.settings.site_url("#{Blog::Constants::WRITING_PATH}/#{post.slug}") }
page = lambda do |mention|
  link = %(<a class="#{mention[:kind]}" href="#{target.call(mention[:post])}">#{mention[:author]}</a>)

  <<~HTML
    <div class="h-entry">
      <a class="p-author h-card" href="#{URI(mention[:source]).origin}/">#{mention[:author]}</a>
      #{link}
      <div class="e-content">#{mention[:content]}</div>
    </div>
  HTML
end

mentions = [
  { post: article, source: "https://alice.example.com/notes/1", status: "approved", author: "Alice Example",
    kind: "u-in-reply-to", content: "Great write-up. I made the same move last year." },
  { post: article, source: "https://bob.example.org/likes/7", status: "approved", author: "Bob Example",
    kind: "u-like-of", content: "" },
  { post: article, source: "https://carol.example.net/reposts/3", status: "pending", author: "Carol Example",
    kind: "u-repost-of", content: "" },
  { post: postgres, source: "https://dave.example.com/links", status: "ignored", author: "Dave Example",
    kind: "", content: "Links I liked this week." },
  { post: postgres, source: "https://erin.example.org/replies/2", status: "pending", author: "Erin Example",
    kind: "u-in-reply-to", content: "Do domains slow down inserts?" },
  { post: postgres, source: "https://cheap-pills.example.net/p/1", status: "spam", author: "Cheap Pills",
    kind: "", content: "Buy now.", reason: "Sells pills in every post." },
]

receive = Social::Slice["operations.receive_webmention"]
verify = Social::Operations::VerifyWebmention.new(
  client: Seeds::SourcePages.new(mentions.to_h { [it[:source], page.call(it)] }),
)
moderate = Social::Slice["operations.moderate_webmention"]

mentions.each do |mention|
  source = mention[:source]
  url = target.call(mention[:post])
  Seeds.unwrap(receive.call(source:, target: url, visitor_hashes:))
  stored = Seeds.unwrap(verify.call(source:, target: url, post_id: mention[:post].id))
  next if mention[:status] == "pending"

  Seeds.unwrap(moderate.call(stored[:id], mention[:status], reason: mention[:reason]))
end

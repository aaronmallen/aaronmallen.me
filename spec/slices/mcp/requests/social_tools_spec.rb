# frozen_string_literal: true

RSpec.describe "MCP social tools", type: :request do
  def filed(status, field) = Social::Slice["relations.webmentions"].with_status(status).pluck(field)

  def mcp_scopes = %w[read write publish delete]

  def social_post_mutations = Social::Slice["repos.social_post_mutations"]
  def social_post_queries = Social::Slice["repos.social_post_queries"]

  def stored(id) = social_post_queries.by_id(id)

  def targeted(id) = Social::Slice["operations.list_target_accounts"].call(stored(id)).map(&:id)

  def webmention_mutations = Social::Slice["repos.webmention_mutations"]
  def webmention_queries = Social::Slice["repos.webmention_queries"]

  before { connect_social_networks }

  describe "list_social_posts" do
    def delivered(network, **)
      social_post = create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 5)))
      create(:social_post_delivery, network, social_post_id: social_post.id, **)
      mcp_call("list_social_posts", **range)
    end

    def delivery(network) = listed.first.fetch("deliveries").find { it.fetch("network") == network }

    def listed = mcp_content.fetch("social_posts")

    def listed_ids(**)
      mcp_call("list_social_posts", **)
      listed.map { it.fetch("id") }
    end

    def range = { from: "2026-03-01", to: "2026-03-31" }

    it "lists sent and unsent posts in the range, newest first" do
      sent = create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 2)))
      queued = create(:social_post, :scheduled, posted_at: at(Date.new(2026, 3, 20)))
      draft = create(:social_post, :draft, created_at: at(Date.new(2026, 3, 10)))
      mcp_call("list_social_posts", **range)

      expect(listed.map { it.fetch("id") }).to eq([queued.id, draft.id, sent.id])
    end

    it "leaves out posts outside the range" do
      create(:social_post, :posted, posted_at: at(Date.new(2026, 4, 1)))
      create(:social_post, :draft, created_at: at(Date.new(2026, 2, 28)))
      mcp_call("list_social_posts", **range)

      expect(listed).to be_empty
    end

    it "counts both days at the ends as inside the range" do
      first = create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 1), 0))
      last = create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 31), 23))
      mcp_call("list_social_posts", **range)

      expect(listed.map { it.fetch("id") }).to contain_exactly(first.id, last.id)
    end

    it "gives the parts in order" do
      social_post = social_post_mutations.create_with_parts(
        parts: %w[one two], status: "posted", posted_at: at(Date.new(2026, 3, 5)), targets: %w[mastodon],
      )
      mcp_call("list_social_posts", **range)

      expect(listed.first).to include("id" => social_post.id, "status" => "posted", "parts" => %w[one two])
    end

    it "gives a delivery that went out as sent, with its link and engagement" do
      delivered(:mastodon, remote_ids: ["1"], remote_url: "https://ruby.social/@ada/1", like_count: 4)

      expect(delivery("mastodon"))
        .to include("state" => "sent", "url" => "https://ruby.social/@ada/1", "likes" => 4)
    end

    it "gives a delivery that gave up as failed, with its error" do
      delivered(:bluesky, failed: true, error: "rate limited")

      error = marked("rate limited")

      expect(delivery("bluesky")).to include("state" => "failed", "error" => error)
    end

    it "gives each part's length and limit on each network it targets" do
      draft = create(:social_post, :draft, targets: %w[bluesky], created_at: at(Date.new(2026, 3, 5)))
      mcp_call("list_social_posts", **range)
      count = stored(draft.id).parts.first.body.length

      expect(listed.first.fetch("lengths")).to eq([{ "bluesky" => { "count" => count, "limit" => 300 } }])
    end

    it "calls a network with no delivery yet waiting" do
      create(:social_post, :scheduled, posted_at: at(Date.new(2026, 3, 5)), targets: %w[mastodon])
      mcp_call("list_social_posts", **range)

      expect(listed.first.fetch("deliveries")).to match([include("network" => "mastodon", "state" => "waiting")])
    end

    it "calls a delivery with an error but no give up retrying" do
      social_post = create(:social_post, :scheduled, posted_at: at(Date.new(2026, 3, 5)), targets: %w[mastodon])
      create(:social_post_delivery, :mastodon, social_post_id: social_post.id, error: "rate limited")
      mcp_call("list_social_posts", **range)

      expect(listed.first.fetch("deliveries").first.fetch("state")).to eq("retrying")
    end

    it "keeps only the queue asked for" do
      create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 2)))
      queued = create(:social_post, :scheduled, posted_at: at(Date.new(2026, 3, 20)))
      create(:social_post, :draft, created_at: at(Date.new(2026, 3, 10)))

      expect(listed_ids(**range, queue: "queued")).to eq([queued.id])
    end

    it "keeps the drafts and the posted ones apart" do
      sent = create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 2)))
      draft = create(:social_post, :draft, created_at: at(Date.new(2026, 3, 10)))

      expect([listed_ids(**range, queue: "drafts"), listed_ids(**range, queue: "posted")])
        .to eq([[draft.id], [sent.id]])
    end

    it "lists every social post, newest first, when given no range" do
      older = create(:social_post, :posted, posted_at: at(Date.new(2020, 3, 2)))
      newer = create(:social_post, :scheduled, posted_at: at(Date.new(2030, 3, 2)))
      mcp_call("list_social_posts")

      expect([listed.map { it.fetch("id") }, mcp_content.values_at("from", "to")])
        .to eq([[newer.id, older.id], [nil, nil]])
    end

    it "pages through every post in one queue when given no range" do
      kept = 1.upto(3).map { create(:social_post, :posted, posted_at: at(Date.new(2020, 1, it))) }.reverse
      create(:social_post, :draft)
      lower_page_size(:mcp, to: 2)

      expect([1, 2].flat_map { listed_ids(queue: "posted", page: it) }).to eq(kept.map(&:id))
    end

    it "lists every social post from a day on when given only from" do
      create(:social_post, :posted, posted_at: at(Date.new(2026, 2, 28)))
      kept = create(:social_post, :scheduled, posted_at: at(Date.new(2030, 3, 2)))

      expect(listed_ids(from: "2026-03-01")).to eq([kept.id])
    end

    it "lists every social post up to a day when given only to" do
      kept = create(:social_post, :posted, posted_at: at(Date.new(2020, 3, 2)))
      create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 2)))

      expect(listed_ids(to: "2026-03-01")).to eq([kept.id])
    end

    it "counts the posts in the range by queue, whatever the queue asked for" do
      2.upto(3) { create(:social_post, :posted, posted_at: at(Date.new(2026, 3, it))) }
      create(:social_post, :draft, created_at: at(Date.new(2026, 3, 10)))
      create(:social_post, :scheduled, posted_at: at(Date.new(2026, 4, 2)))
      mcp_call("list_social_posts", **range, queue: "drafts")

      expect(mcp_content.fetch("counts")).to eq("queued" => 0, "posted" => 2, "drafts" => 1)
    end

    it "counts every social post when given no range" do
      create(:social_post, :posted, posted_at: at(Date.new(2020, 3, 2)))
      create(:social_post, :scheduled, posted_at: at(Date.new(2030, 3, 2)))
      mcp_call("list_social_posts")

      expect(mcp_content.fetch("counts")).to eq("queued" => 1, "posted" => 1, "drafts" => 0)
    end

    it "refuses a queue the admin does not have" do
      mcp_call("list_social_posts", queue: "archived")

      expect(mcp_message).to include("/queue")
    end

    it "refuses a day it cannot read" do
      mcp_call("list_social_posts", from: "March", to: "2026-03-31")

      expect(mcp_message).to eq("give from and to as days, such as 2026-01-01")
    end

    it "refuses a range that runs backwards" do
      mcp_call("list_social_posts", from: "2026-03-31", to: "2026-03-01")

      expect(mcp_message).to eq("from comes after to")
    end
  end

  describe "create_social_post" do
    it "saves a draft" do
      mcp_call("create_social_post", parts: %w[hello there], targets: %w[mastodon])

      expect(stored(mcp_content.fetch("id"))).to have_attributes(status: "draft", targets: %w[mastodon])
    end

    it "keeps the parts in order" do
      mcp_call("create_social_post", parts: %w[hello there], targets: %w[mastodon])

      expect(stored(mcp_content.fetch("id")).parts.map(&:body)).to eq(%w[hello there])
    end

    it "answers with the post it saved" do
      mcp_call("create_social_post", parts: %w[hello], targets: %w[mastodon])

      expect(mcp_content).to include("status" => "draft", "parts" => %w[hello], "posted_at" => nil)
    end

    it "gives each part's length and limit on each network it targets" do
      mcp_call("create_social_post", parts: ["a" * 400, "hi"], targets: %w[mastodon bluesky])

      long = { "mastodon" => { "count" => 400, "limit" => 500 }, "bluesky" => { "count" => 400, "limit" => 300 } }
      short = { "mastodon" => { "count" => 2, "limit" => 500 }, "bluesky" => { "count" => 2, "limit" => 300 } }

      expect(mcp_content.fetch("lengths")).to eq([long, short])
    end

    it "refuses a post with no text, as the admin does" do
      mcp_call("create_social_post", parts: ["  "], targets: %w[mastodon])

      expect(mcp_message).to eq("parts is empty")
    end

    it "refuses a part made only of Unicode spaces" do
      mcp_call("create_social_post", parts: ["\u2003"], targets: %w[mastodon])

      expect(mcp_message).to eq("parts is empty")
    end

    it "refuses a later part made only of Unicode spaces" do
      mcp_call("create_social_post", parts: ["Hello", "\u2003\u3000"], targets: %w[mastodon])

      expect(mcp_message).to eq("parts is empty")
    end

    it "keeps a part with Unicode spaces around real words as typed" do
      mcp_call("create_social_post", parts: ["\u2003Pick a queue\u00a0"], targets: %w[mastodon])
      mcp_call("read_social_post", id: mcp_content.fetch("id"))

      expect(mcp_content.fetch("parts")).to eq(["\u2003Pick a queue\u00a0"])
    end

    it "refuses a post with no network" do
      mcp_call("create_social_post", parts: %w[hello], targets: [])

      expect(mcp_message).to eq("targets is empty")
    end

    it "refuses a network with no credentials" do
      connect_social_networks(bluesky: {})
      mcp_call("create_social_post", parts: %w[hello], targets: %w[bluesky])

      expect(mcp_message).to eq("targets names a network that has no credentials")
    end

    it "refuses a part holding a control character" do
      mcp_call("create_social_post", parts: ["hel\u0000lo"], targets: %w[mastodon])

      expect(mcp_message).to eq("parts holds a control character")
    end

    it "refuses a mention of nobody in the directory, as the admin does" do
      mcp_call("create_social_post", parts: ["hi @{nobody}"], targets: %w[mastodon])

      expect(mcp_message).to eq("parts mentions someone who is not in the directory")
    end

    it "saves a mention of someone in the directory" do
      create(:person, key: "ada-lovelace")
      mcp_call("create_social_post", parts: ["hi @{ada-lovelace}"], targets: %w[mastodon])

      expect(stored(mcp_content.fetch("id")).parts.map(&:body)).to eq(["hi @{ada-lovelace}"])
    end

    it "saves nothing when it refuses" do
      mcp_call("create_social_post", parts: ["  "], targets: %w[mastodon])

      expect(social_posts_in("drafts")).to be_empty
    end
  end

  describe "update_social_post" do
    def draft
      @draft ||= social_post_mutations.create_with_parts(parts: %w[old], status: "draft", targets: %w[mastodon])
    end

    it "replaces the parts" do
      mcp_call("update_social_post", id: draft.id, parts: %w[new words])

      expect(stored(draft.id).parts.map(&:body)).to eq(%w[new words])
    end

    it "keeps the networks it was not given" do
      mcp_call("update_social_post", id: draft.id, parts: %w[new])

      expect(stored(draft.id).targets).to eq(%w[mastodon])
    end

    it "keeps the parts it was not given" do
      mcp_call("update_social_post", id: draft.id, targets: %w[mastodon bluesky])

      expect(stored(draft.id)).to have_attributes(targets: %w[mastodon bluesky], parts: [have_attributes(body: "old")])
    end

    it "sends to every account on a network it adds to a post that picked accounts" do
      other = connect_another_mastodon
      social_post_mutations.update(draft.id, connection_ids: [other.id])
      mcp_call("update_social_post", id: draft.id, targets: %w[mastodon bluesky])

      expect(targeted(draft.id)).to eq([other.id, social_account("bluesky").id])
    end

    it "gives the lengths of the parts it saved" do
      mcp_call("update_social_post", id: draft.id, parts: %w[new])

      expect(mcp_content.fetch("lengths")).to eq([{ "mastodon" => { "count" => 3, "limit" => 500 } }])
    end

    it "leaves a queued post a draft, as saving a draft in the admin does" do
      queued = create(:social_post, :scheduled)
      mcp_call("update_social_post", id: queued.id, parts: %w[new])

      expect(stored(queued.id)).to have_attributes(status: "draft", posted_at: nil)
    end

    it "refuses a post that has gone out" do
      sent = create(:social_post, :posted)
      mcp_call("update_social_post", id: sent.id, parts: %w[new])

      expect(mcp_message).to eq("social post #{sent.id} has gone out, so nothing was saved")
    end

    it "refuses an unknown ID" do
      mcp_call("update_social_post", id: 999_999, parts: %w[new])

      expect(mcp_message).to eq("no social post has the ID 999999")
    end

    it "refuses empty text and keeps what was there" do
      mcp_call("update_social_post", id: draft.id, parts: [""])

      expect([mcp_message, stored(draft.id).parts.map(&:body)]).to eq(["parts is empty", %w[old]])
    end
  end

  describe "send_social_post" do
    def draft
      @draft ||= social_post_mutations.create_with_parts(parts: %w[hi], status: "draft", targets: %w[mastodon])
    end

    def over(detail) = "parts has a part over the limit for a network you picked: #{detail}"

    def send_both(*parts)
      long = social_post_mutations.create_with_parts(parts:, status: "draft", targets: %w[mastodon bluesky])
      mcp_call("send_social_post", id: long.id)
    end

    it "queues the post to go out now" do
      mcp_call("send_social_post", id: draft.id)

      expect(stored(draft.id)).to have_attributes(status: "scheduled", posted_at: be_within(60).of(Time.now))
    end

    it "queues the post for the time it was given" do
      mcp_call("send_social_post", id: draft.id, schedule_at: "2030-01-02T09:30")

      expect(stored(draft.id).posted_at).to eq(Blog::TimeZone.local_time(2030, 1, 2, 9, 30))
    end

    it "answers with the queued post" do
      mcp_call("send_social_post", id: draft.id)

      expect(mcp_content).to include("id" => draft.id, "status" => "scheduled")
    end

    it "refuses a part over a network's limit, as the admin does" do
      long = social_post_mutations.create_with_parts(parts: ["a" * 501], status: "draft", targets: %w[mastodon])
      mcp_call("send_social_post", id: long.id)

      expect(mcp_message).to eq(over("part 1 runs 501 of 500 on mastodon"))
    end

    it "names only the network a part runs over when it fits the other" do
      send_both("hi", "a" * 400)

      expect(mcp_message).to eq(over("part 2 runs 400 of 300 on bluesky"))
    end

    it "says a part has too many bytes when it fits the count but not the bytes" do
      send_both("\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466}" * 121)

      expect(mcp_message).to eq(over("part 1 has too many bytes for bluesky"))
    end

    it "names each part and network over its limit" do
      send_both("a" * 501, "b" * 301)

      runs = ["part 1 runs 501 of 500 on mastodon", "part 1 runs 501 of 300 on bluesky",
              "part 2 runs 301 of 300 on bluesky"]

      expect(mcp_message).to eq(over(runs.join(", ")))
    end

    it "leaves an over limit post a draft" do
      long = social_post_mutations.create_with_parts(parts: ["a" * 501], status: "draft", targets: %w[mastodon])
      mcp_call("send_social_post", id: long.id)

      expect(stored(long.id).status).to eq("draft")
    end

    it "refuses a time it cannot read" do
      mcp_call("send_social_post", id: draft.id, schedule_at: "tomorrow")

      expect(mcp_message).to eq("schedule_at needs a date and time, as 2026-10-01T09:30")
    end

    it "refuses a time the clocks skip" do
      mcp_call("send_social_post", id: draft.id, schedule_at: "2030-03-10T02:30")

      expect(mcp_message).to eq("schedule_at falls in the hour the clocks skip in America/Chicago")
    end

    it "refuses a post that has gone out" do
      sent = create(:social_post, :posted)
      mcp_call("send_social_post", id: sent.id)

      expect(mcp_message).to eq("social post #{sent.id} has gone out, so nothing was saved")
    end

    it "refuses an unknown ID" do
      mcp_call("send_social_post", id: 999_999)

      expect(mcp_message).to eq("no social post has the ID 999999")
    end
  end

  describe "delete_social_post" do
    def taken
      @taken ||= create(:social_post, :scheduled).tap do |social_post|
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id)
      end
    end

    it "deletes a post that has not gone out" do
      draft = create(:social_post, :draft)
      mcp_call("delete_social_post", id: draft.id)

      expect(stored(draft.id)).to be_nil
    end

    it "answers with the ID it deleted" do
      draft = create(:social_post, :draft)
      mcp_call("delete_social_post", id: draft.id)

      expect(mcp_content).to eq("id" => draft.id, "deleted" => true)
    end

    it "keeps a post a network has taken" do
      mcp_call("delete_social_post", id: taken.id)

      expect(stored(taken.id)).not_to be_nil
    end

    it "says why it kept a post a network has taken" do
      mcp_call("delete_social_post", id: taken.id)

      expect(mcp_message).to eq("social post #{taken.id} has gone out, so nothing was removed")
    end

    it "refuses an unknown ID" do
      mcp_call("delete_social_post", id: 999_999)

      expect(mcp_message).to eq("no social post has the ID 999999")
    end
  end

  describe "moderate_webmention" do
    def mention = @mention ||= create(:webmention)

    it "stores the reason given with spam", :aggregate_failures do
      mcp_call("moderate_webmention", id: mention.id, verdict: "spam", reason: "link farm")

      expect(mcp_content).to eq("id" => mention.id, "status" => "spam")
      expect(filed("spam", :spam_reason)).to eq(["link farm"])
    end

    it "trusts the author of a webmention it approves" do
      mcp_call("moderate_webmention", id: mention.id, verdict: "approved")

      expect(webmention_queries.trusted_author?(mention.author_url)).to be(true)
    end

    it "trusts the author of a webmention approve_webmentions approves" do
      mcp_call("approve_webmentions", ids: [mention.id])

      expect(webmention_queries.trusted_author?(mention.author_url)).to be(true)
    end

    it "refuses a verdict it does not know" do
      mcp_call("moderate_webmention", id: mention.id, verdict: "pending")

      expect(filed("pending", :id)).to eq([mention.id])
    end

    it "refuses an unknown ID" do
      mcp_call("moderate_webmention", id: 999_999, verdict: "spam")

      expect(mcp_message).to eq("no webmention has the ID 999999")
    end
  end

  describe "read_webmention_settings" do
    let(:settings) do
      {
        "accept_bridgy" => true, "auto_approve_known_authors" => true, "auto_approve_likes" => true,
        "auto_approve_reposts" => true, "enable_on_new_posts" => true, "receive" => true, "send_on_publish" => true,
        "single_author_hosts" => [],
      }
    end

    it "reads every setting" do
      mcp_call("read_webmention_settings")

      expect(mcp_content).to eq(settings)
    end
  end

  describe "update_webmention_settings" do
    it "changes the settings it was given" do
      mcp_call("update_webmention_settings", receive: false)

      expect(webmention_queries.settings.receive).to be(false)
    end

    it "keeps the settings it was not given" do
      mcp_call("update_webmention_settings", receive: false)

      expect(webmention_queries.settings.send_on_publish).to be(true)
    end

    it "answers with every setting" do
      mcp_call("update_webmention_settings", accept_bridgy: false)

      expect(mcp_content).to include("accept_bridgy" => false, "receive" => true)
    end

    it "saves the like and repost toggles" do
      mcp_call("update_webmention_settings", auto_approve_likes: false, auto_approve_reposts: false)

      expect(webmention_queries.settings).to have_attributes(auto_approve_likes: false, auto_approve_reposts: false)
    end

    it "saves the hosts it was given, cleaned up and in order" do
      mcp_call("update_webmention_settings", single_author_hosts: ["grace.example", "https://Ada.Example/", "a b"])

      expect(mcp_content).to include("single_author_hosts" => %w[ada.example grace.example])
    end

    it "says it saved nothing when the hosts match the stored ones" do
      webmention_mutations.update_settings(single_author_hosts: ["ada.example"])
      mcp_call("update_webmention_settings", single_author_hosts: ["ada.example"])

      expect(mcp_refused?).to be(true)
    end

    it "says it saved nothing when nothing changed, as the admin does" do
      mcp_call("update_webmention_settings", receive: true)

      expect([mcp_refused?, mcp_message]).to eq([true, "nothing saved, since no setting changed"])
    end
  end

  describe "trusted authors" do
    let(:ada) { "https://ada.example/" }

    before { webmention_mutations.trust(ada, approve_pending: false) }

    it "lists each author with the URL marked untrusted" do
      mcp_call("list_trusted_authors")

      expect(mcp_content.fetch("trusted_authors").first.fetch("author_url")).to eq(marked(ada))
    end

    it "lists the newest author first" do
      Social::Slice["relations.trusted_authors"].by_pk(ada).update(created_at: Time.now - 60)
      webmention_mutations.trust("https://grace.example/", approve_pending: false)
      mcp_call("list_trusted_authors")

      expect(mcp_content.fetch("trusted_authors").map { it.dig("author_url", "text") })
        .to eq(["https://grace.example/", ada])
    end

    it "removes an author" do
      mcp_call("remove_trusted_author", author_url: ada)

      expect(webmention_queries.trusted_author?(ada)).to be(false)
    end

    it "keeps the author's approved webmentions approved" do
      mention = create(:webmention, :approved, author_url: ada)
      mcp_call("remove_trusted_author", author_url: ada)

      expect(filed("approved", :id)).to eq([mention.id])
    end

    it "refuses an author not on the list" do
      mcp_call("remove_trusted_author", author_url: "https://grace.example/")

      expect(mcp_message).to eq("no trusted author has the URL https://grace.example/")
    end
  end
end

# frozen_string_literal: true

RSpec.describe "MCP social tools", type: :request do
  def access_token
    @access_token ||= mcp_connect(
      Spec::DB::Factories[:mcp].create(:oauth_client), verifier: MCP::OAuth::Secret.generate, scope: "read write",
    ).fetch("access_token")
  end

  def at(day, hour = 12) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, 0)

  def call_tool(name, **arguments)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
    params = { name:, arguments: }
    post "/mcp", JSON.generate({ jsonrpc: "2.0", id: 1, method: "tools/call", params: }), headers
  end

  def content = JSON.parse(message)

  def message = result.fetch("content").first.fetch("text")

  def refused? = result.fetch("isError", false)

  def result = JSON.parse(last_response.body).fetch("result")

  def social_post_repo = Social::Slice["repos.social_post_repo"]

  def stored(id) = social_post_repo.by_id(id)

  def webmention_repo = Social::Slice["repos.webmention_repo"]

  before { connect_social_networks }

  describe "list_social_posts" do
    def delivered(network, **)
      social_post = create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 5)))
      create(:social_post_delivery, network, social_post_id: social_post.id, **)
      call_tool("list_social_posts", **range)
    end

    def delivery(network) = listed.first.fetch("deliveries").find { it.fetch("network") == network }

    def listed = content.fetch("social_posts")

    def range = { from: "2026-03-01", to: "2026-03-31" }

    it "lists sent and unsent posts in the range, newest first" do
      sent = create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 2)))
      queued = create(:social_post, :scheduled, posted_at: at(Date.new(2026, 3, 20)))
      draft = create(:social_post, :draft, created_at: at(Date.new(2026, 3, 10)))
      call_tool("list_social_posts", **range)

      expect(listed.map { it.fetch("id") }).to eq([queued.id, draft.id, sent.id])
    end

    it "leaves out posts outside the range" do
      create(:social_post, :posted, posted_at: at(Date.new(2026, 4, 1)))
      create(:social_post, :draft, created_at: at(Date.new(2026, 2, 28)))
      call_tool("list_social_posts", **range)

      expect(listed).to be_empty
    end

    it "counts both days at the ends as inside the range" do
      first = create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 1), 0))
      last = create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 31), 23))
      call_tool("list_social_posts", **range)

      expect(listed.map { it.fetch("id") }).to contain_exactly(first.id, last.id)
    end

    it "gives the parts in order" do
      social_post = social_post_repo.create_with_parts(
        parts: %w[one two], status: "posted", posted_at: at(Date.new(2026, 3, 5)), targets: %w[mastodon],
      )
      call_tool("list_social_posts", **range)

      expect(listed.first).to include("id" => social_post.id, "status" => "posted", "parts" => %w[one two])
    end

    it "gives a delivery that went out as sent, with its link and engagement" do
      delivered(:mastodon, remote_ids: ["1"], remote_url: "https://ruby.social/@ada/1", like_count: 4)

      expect(delivery("mastodon"))
        .to include("state" => "sent", "url" => "https://ruby.social/@ada/1", "likes" => 4)
    end

    it "gives a delivery that gave up as failed, with its error" do
      delivered(:bluesky, failed: true, error: "rate limited")

      expect(delivery("bluesky")).to include("state" => "failed", "error" => "rate limited")
    end

    it "calls a network with no delivery yet waiting" do
      create(:social_post, :scheduled, posted_at: at(Date.new(2026, 3, 5)), targets: %w[mastodon])
      call_tool("list_social_posts", **range)

      expect(listed.first.fetch("deliveries")).to eq([{ "network" => "mastodon", "state" => "waiting" }])
    end

    it "calls a delivery with an error but no give up retrying" do
      social_post = create(:social_post, :scheduled, posted_at: at(Date.new(2026, 3, 5)), targets: %w[mastodon])
      create(:social_post_delivery, :mastodon, social_post_id: social_post.id, error: "rate limited")
      call_tool("list_social_posts", **range)

      expect(listed.first.fetch("deliveries").first.fetch("state")).to eq("retrying")
    end

    it "refuses a day it cannot read" do
      call_tool("list_social_posts", from: "March", to: "2026-03-31")

      expect(message).to eq("give from and to as days, such as 2026-01-01")
    end

    it "refuses a range that runs backwards" do
      call_tool("list_social_posts", from: "2026-03-31", to: "2026-03-01")

      expect(message).to eq("from comes after to")
    end
  end

  describe "create_social_post" do
    it "saves a draft" do
      call_tool("create_social_post", parts: %w[hello there], targets: %w[mastodon])

      expect(stored(content.fetch("id"))).to have_attributes(status: "draft", targets: %w[mastodon])
    end

    it "keeps the parts in order" do
      call_tool("create_social_post", parts: %w[hello there], targets: %w[mastodon])

      expect(stored(content.fetch("id")).parts.map(&:body)).to eq(%w[hello there])
    end

    it "answers with the post it saved" do
      call_tool("create_social_post", parts: %w[hello], targets: %w[mastodon])

      expect(content).to include("status" => "draft", "parts" => %w[hello], "posted_at" => nil)
    end

    it "refuses a post with no text, as the admin does" do
      call_tool("create_social_post", parts: ["  "], targets: %w[mastodon])

      expect(message).to eq("parts is empty")
    end

    it "refuses a part made only of Unicode spaces" do
      call_tool("create_social_post", parts: ["\u2003"], targets: %w[mastodon])

      expect(message).to eq("parts is empty")
    end

    it "refuses a post with no network" do
      call_tool("create_social_post", parts: %w[hello], targets: [])

      expect(message).to eq("targets is empty")
    end

    it "refuses a network with no credentials" do
      connect_social_networks(bluesky: {})
      call_tool("create_social_post", parts: %w[hello], targets: %w[bluesky])

      expect(message).to eq("targets names a network that has no credentials")
    end

    it "refuses a part holding a control character" do
      call_tool("create_social_post", parts: ["hel\u0000lo"], targets: %w[mastodon])

      expect(message).to eq("parts holds a control character")
    end

    it "refuses a mention of nobody in the directory, as the admin does" do
      call_tool("create_social_post", parts: ["hi @{nobody}"], targets: %w[mastodon])

      expect(message).to eq("parts mentions someone who is not in the directory")
    end

    it "saves a mention of someone in the directory" do
      create(:person, key: "ada-lovelace")
      call_tool("create_social_post", parts: ["hi @{ada-lovelace}"], targets: %w[mastodon])

      expect(stored(content.fetch("id")).parts.map(&:body)).to eq(["hi @{ada-lovelace}"])
    end

    it "saves nothing when it refuses" do
      call_tool("create_social_post", parts: ["  "], targets: %w[mastodon])

      expect(social_post_repo.drafts).to be_empty
    end
  end

  describe "update_social_post" do
    def draft = @draft ||= social_post_repo.create_with_parts(parts: %w[old], status: "draft", targets: %w[mastodon])

    it "replaces the parts" do
      call_tool("update_social_post", id: draft.id, parts: %w[new words])

      expect(stored(draft.id).parts.map(&:body)).to eq(%w[new words])
    end

    it "keeps the networks it was not given" do
      call_tool("update_social_post", id: draft.id, parts: %w[new])

      expect(stored(draft.id).targets).to eq(%w[mastodon])
    end

    it "keeps the parts it was not given" do
      call_tool("update_social_post", id: draft.id, targets: %w[mastodon bluesky])

      expect(stored(draft.id)).to have_attributes(targets: %w[mastodon bluesky], parts: [have_attributes(body: "old")])
    end

    it "leaves a queued post a draft, as saving a draft in the admin does" do
      queued = create(:social_post, :scheduled)
      call_tool("update_social_post", id: queued.id, parts: %w[new])

      expect(stored(queued.id)).to have_attributes(status: "draft", posted_at: nil)
    end

    it "refuses a post that has gone out" do
      sent = create(:social_post, :posted)
      call_tool("update_social_post", id: sent.id, parts: %w[new])

      expect(message).to eq("social post #{sent.id} has gone out, so nothing was saved")
    end

    it "refuses an unknown ID" do
      call_tool("update_social_post", id: 404, parts: %w[new])

      expect(message).to eq("no social post has the ID 404")
    end

    it "refuses empty text and keeps what was there" do
      call_tool("update_social_post", id: draft.id, parts: [""])

      expect([message, stored(draft.id).parts.map(&:body)]).to eq(["parts is empty", %w[old]])
    end
  end

  describe "send_social_post" do
    def draft = @draft ||= social_post_repo.create_with_parts(parts: %w[hi], status: "draft", targets: %w[mastodon])

    it "queues the post to go out now" do
      call_tool("send_social_post", id: draft.id)

      expect(stored(draft.id)).to have_attributes(status: "scheduled", posted_at: be_within(60).of(Time.now))
    end

    it "queues the post for the time it was given" do
      call_tool("send_social_post", id: draft.id, schedule_at: "2030-01-02T09:30")

      expect(stored(draft.id).posted_at).to eq(Blog::TimeZone.local_time(2030, 1, 2, 9, 30))
    end

    it "answers with the queued post" do
      call_tool("send_social_post", id: draft.id)

      expect(content).to include("id" => draft.id, "status" => "scheduled")
    end

    it "refuses a part over a network's limit, as the admin does" do
      long = social_post_repo.create_with_parts(parts: ["a" * 501], status: "draft", targets: %w[mastodon])
      call_tool("send_social_post", id: long.id)

      expect(message).to eq("parts has a part over the limit for a network you picked")
    end

    it "leaves an over limit post a draft" do
      long = social_post_repo.create_with_parts(parts: ["a" * 501], status: "draft", targets: %w[mastodon])
      call_tool("send_social_post", id: long.id)

      expect(stored(long.id).status).to eq("draft")
    end

    it "refuses a time it cannot read" do
      call_tool("send_social_post", id: draft.id, schedule_at: "tomorrow")

      expect(message).to eq("schedule_at needs a date and time, as 2026-10-01T09:30")
    end

    it "refuses a time the clocks skip" do
      call_tool("send_social_post", id: draft.id, schedule_at: "2030-03-10T02:30")

      expect(message).to eq("schedule_at falls in the hour the clocks skip in America/Chicago")
    end

    it "refuses a post that has gone out" do
      sent = create(:social_post, :posted)
      call_tool("send_social_post", id: sent.id)

      expect(message).to eq("social post #{sent.id} has gone out, so nothing was saved")
    end

    it "refuses an unknown ID" do
      call_tool("send_social_post", id: 404)

      expect(message).to eq("no social post has the ID 404")
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
      call_tool("delete_social_post", id: draft.id)

      expect(stored(draft.id)).to be_nil
    end

    it "answers with the ID it deleted" do
      draft = create(:social_post, :draft)
      call_tool("delete_social_post", id: draft.id)

      expect(content).to eq("id" => draft.id, "deleted" => true)
    end

    it "keeps a post a network has taken" do
      call_tool("delete_social_post", id: taken.id)

      expect(stored(taken.id)).not_to be_nil
    end

    it "says why it kept a post a network has taken" do
      call_tool("delete_social_post", id: taken.id)

      expect(message).to eq("social post #{taken.id} has gone out, so nothing was removed")
    end

    it "refuses an unknown ID" do
      call_tool("delete_social_post", id: 404)

      expect(message).to eq("no social post has the ID 404")
    end
  end

  describe "list_webmentions" do
    def listed = content.fetch("webmentions")

    def range = { from: "2026-03-01", to: "2026-03-31" }

    def shown = %i[post_id type status source_url author_name author_url excerpt]

    it "lists the webmentions received in the range, newest first" do
      older = create(:webmention, received_at: at(Date.new(2026, 3, 2)))
      newer = create(:webmention, :approved, received_at: at(Date.new(2026, 3, 20)))
      create(:webmention, received_at: at(Date.new(2026, 4, 1)))
      call_tool("list_webmentions", **range)

      expect(listed.map { it.fetch("id") }).to eq([newer.id, older.id])
    end

    it "narrows to one status" do
      create(:webmention, received_at: at(Date.new(2026, 3, 2)))
      spam = create(:webmention, :spam, received_at: at(Date.new(2026, 3, 3)))
      call_tool("list_webmentions", **range, status: "spam")

      expect(listed.map { it.fetch("id") }).to eq([spam.id])
    end

    it "narrows to the ignored ones" do
      create(:webmention, :spam, received_at: at(Date.new(2026, 3, 2)))
      ignored = create(:webmention, :ignored, received_at: at(Date.new(2026, 3, 3)))
      call_tool("list_webmentions", **range, status: "ignored")

      expect(listed.map { it.fetch("id") }).to eq([ignored.id])
    end

    it "gives what each one says and where it came from" do
      mention = create(:webmention, :reply, received_at: at(Date.new(2026, 3, 2)), excerpt: "Nice post")
      call_tool("list_webmentions", **range)

      expect(listed.first).to include(mention.to_h.slice(*shown).transform_keys(&:to_s))
    end

    it "gives the reason a spam mention was marked" do
      create(:webmention, :spam, spam_reason: "link farm", received_at: at(Date.new(2026, 3, 2)))
      call_tool("list_webmentions", **range)

      expect(listed.first).to include("spam_reason" => "link farm")
    end

    it "leaves spam_reason out when there is none" do
      create(:webmention, :spam, received_at: at(Date.new(2026, 3, 2)))
      call_tool("list_webmentions", **range)

      expect(listed.first).not_to have_key("spam_reason")
    end

    it "names the time zone its days run on" do
      call_tool("list_webmentions", **range)

      expect(content.fetch("time_zone")).to eq("America/Chicago")
    end

    it "gives received_at in Chicago time with its offset, on the day it lists it under" do
      create(:webmention, received_at: Blog::TimeZone.local_time(2026, 3, 31, 23, 30))
      call_tool("list_webmentions", **range)

      expect(listed.map { it.fetch("received_at") }).to eq(["2026-03-31T23:30:00-05:00"])
    end

    it "refuses a range that runs backwards" do
      call_tool("list_webmentions", from: "2026-03-31", to: "2026-03-01")

      expect(message).to eq("from comes after to")
    end
  end

  describe "moderate_webmention" do
    def mention = @mention ||= create(:webmention)

    it "approves one" do
      call_tool("moderate_webmention", id: mention.id, verdict: "approved")

      expect(content).to eq("id" => mention.id, "status" => "approved")
    end

    it "marks one as spam" do
      call_tool("moderate_webmention", id: mention.id, verdict: "spam")

      expect(webmention_repo.by_status("spam").map(&:id)).to eq([mention.id])
    end

    it "stores the reason given with spam" do
      call_tool("moderate_webmention", id: mention.id, verdict: "spam", reason: "link farm")

      expect(webmention_repo.by_status("spam").map(&:spam_reason)).to eq(["link farm"])
    end

    it "clears the reason when approving a spam mention" do
      spam = create(:webmention, :spam, spam_reason: "link farm")
      call_tool("moderate_webmention", id: spam.id, verdict: "approved")

      expect(webmention_repo.by_status("approved").map(&:spam_reason)).to eq([nil])
    end

    it "marks one as ignored" do
      call_tool("moderate_webmention", id: mention.id, verdict: "ignored")

      expect(webmention_repo.by_status("ignored").map(&:id)).to eq([mention.id])
    end

    it "refuses a verdict it does not know" do
      call_tool("moderate_webmention", id: mention.id, verdict: "pending")

      expect(webmention_repo.by_status("pending").map(&:id)).to eq([mention.id])
    end

    it "refuses an unknown ID" do
      call_tool("moderate_webmention", id: 404, verdict: "spam")

      expect(message).to eq("no webmention has the ID 404")
    end
  end

  describe "read_webmention_settings" do
    it "reads every setting" do
      call_tool("read_webmention_settings")

      expect(content).to eq(
        "accept_bridgy" => true, "auto_approve_known_authors" => true, "enable_on_new_posts" => true,
        "receive" => true, "send_on_publish" => true, "single_author_hosts" => [],
      )
    end
  end

  describe "update_webmention_settings" do
    it "changes the settings it was given" do
      call_tool("update_webmention_settings", receive: false)

      expect(webmention_repo.settings.receive).to be(false)
    end

    it "keeps the settings it was not given" do
      call_tool("update_webmention_settings", receive: false)

      expect(webmention_repo.settings.send_on_publish).to be(true)
    end

    it "answers with every setting" do
      call_tool("update_webmention_settings", accept_bridgy: false)

      expect(content).to include("accept_bridgy" => false, "receive" => true)
    end

    it "saves the hosts it was given, cleaned up and in order" do
      call_tool("update_webmention_settings", single_author_hosts: ["grace.example", "https://Ada.Example/", "a b"])

      expect(content).to include("single_author_hosts" => %w[ada.example grace.example])
    end

    it "says it saved nothing when the hosts match the stored ones" do
      webmention_repo.update_settings(single_author_hosts: ["ada.example"])
      call_tool("update_webmention_settings", single_author_hosts: ["ada.example"])

      expect(refused?).to be(true)
    end

    it "says it saved nothing when nothing changed, as the admin does" do
      call_tool("update_webmention_settings", receive: true)

      expect([refused?, message]).to eq([true, "nothing saved, since no setting changed"])
    end
  end
end

# frozen_string_literal: true

RSpec.describe "API reading a social post", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def compose(body)
    Social::Slice["repos.social_post_mutations"]
      .create_with_parts(parts: [body], posted_at: nil, status: "draft", targets: %w[mastodon])
  end

  def connect_two_mastodons
    connect_social_networks
    connect_another_mastodon
    Services::Slice["repos.connection_queries"].for("mastodon")
  end

  def deliver(social_post, network, **)
    create(:social_post_delivery, social_post_id: social_post.id, network:, **)
  end

  def delivered(id) = read(id).fetch("deliveries").map { [it.values_at("network", "account"), it.fetch("state")] }

  def hachyderm = %w[mastodon @ada@hachyderm.io]

  def lengths(social_post)
    social_post.parts.map do |part|
      { "mastodon" => { "count" => part.body.length, "limit" => 500 },
        "bluesky" => { "count" => part.body.length, "limit" => 300 } }
    end
  end

  def link(id, other_kind, other_id)
    Links::Slice["operations.link_records"].call("social_post", id, { other_kind:, other_id: }).value!
  end

  def mention_zeppelin(social_post) = create(:social_post_part, social_post_id: social_post.id, body: "Saw a zeppelin")

  def open_edit(edit)
    {
      "id" => edit.id, "part" => 1, "original" => edit.original, "replacement" => edit.replacement,
      "reason" => "typo", "status" => "pending",
    }
  end

  def read(id)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/social_posts/#{id}", nil, headers
    JSON.parse(last_response.body)
  end

  def ruby_social = %w[mastodon @aaronmallen@ruby.social]

  def sent_counts
    {
      remote_ids: Sequel.pg_array(%w[1]), remote_url: "https://ruby.social/@me/1", like_count: 4, repost_count: 2,
      reply_count: 1,
    }
  end

  def sent_delivery
    {
      "network" => "mastodon", "account" => nil, "state" => "sent", "url" => "https://ruby.social/@me/1",
      "error" => nil, "likes" => 4, "reposts" => 2, "replies" => 1,
    }
  end

  def shown(social_post)
    {
      "id" => social_post.id, "status" => "posted", "post_id" => nil, "targets" => %w[mastodon bluesky],
      "posted_at" => social_post.posted_at.utc.iso8601, "created_at" => social_post.created_at.utc.iso8601,
      "updated_at" => social_post.updated_at.utc.iso8601, "parts" => [social_post.parts.first.body],
      "deliveries" => [sent_delivery, waiting_delivery], "suggestion_id" => nil, "suggestion_edits" => [],
      "lengths" => lengths(social_post), "record_links" => {},
    }
  end

  def status = last_response.status

  def stored(id) = Social::Slice["repos.social_post_queries"].by_id(id)

  def suggest(social_post, *edits)
    Suggestions::Slice["repos.suggestion_mutations"].replace_for_social_post(social_post.id, edits)
  end

  def typo(original, replacement) = { original:, replacement:, reason: "typo", part: 1 }

  def waiting_delivery
    {
      "network" => "bluesky", "account" => nil, "state" => "waiting", "url" => nil, "error" => nil, "likes" => 0,
      "reposts" => 0, "replies" => 0,
    }
  end

  describe "GET /api/v1/social_posts/:id" do
    it "answers a sent social post with its targets, stamps and each network's delivery" do
      social_post = create(:social_post, :posted)
      deliver(social_post, "mastodon", **sent_counts)

      expect([read(social_post.id), status]).to eq([shown(stored(social_post.id)), 200])
    end

    it "reads a draft and a scheduled social post" do
      draft = create(:social_post, :draft)
      scheduled = create(:social_post, :scheduled)

      expect([draft, scheduled].map { read(it.id).fetch("status") }).to eq(%w[draft scheduled])
    end

    it "names the post the social post announces" do
      article = create(:post, :published)
      social_post = create(:social_post, :posted, post_id: article.id)

      expect(read(social_post.id).fetch("post_id")).to eq(article.id)
    end

    it "tells a failed delivery from one still retrying" do
      social_post = create(:social_post, :posted)
      deliver(social_post, "mastodon", error: "timed out")
      deliver(social_post, "bluesky", error: "refused", failed: true)

      expect(read(social_post.id).fetch("deliveries").map { it.values_at("state", "error") })
        .to eq([["retrying", "timed out"], %w[failed refused]])
    end

    it "marks a delivery with parts still to send and no error as sending" do
      social_post = create(:social_post, :posted)
      deliver(social_post, "mastodon")

      expect(read(social_post.id).fetch("deliveries").map { it.values_at("network", "state") })
        .to include(%w[mastodon sending])
    end

    it "names each account a post went to on one network" do
      social_post = create(:social_post, :posted, targets: %w[mastodon])
      first, second = connect_two_mastodons
      deliver(social_post, "mastodon", connection_id: first.id, **sent_counts)
      deliver(social_post, "mastodon", connection_id: second.id, error: "refused", failed: true)

      expect(delivered(social_post.id)).to eq([[ruby_social, "sent"], [hachyderm, "failed"]])
    end

    it "lists each picked account as waiting before the post goes out" do
      social_post = create(:social_post, :scheduled, targets: %w[mastodon bluesky])
      connect_two_mastodons

      expect(delivered(social_post.id))
        .to eq([[ruby_social, "waiting"], [hachyderm, "waiting"], [%w[bluesky @ada.example], "waiting"]])
    end

    it "keeps the network of a delivery sent before accounts" do
      connect_social_networks
      social_post = create(:social_post, :posted, targets: %w[mastodon])
      deliver(social_post, "mastodon", **sent_counts)

      expect(read(social_post.id).fetch("deliveries")).to eq([sent_delivery])
    end

    it "gives the suggested edits still open, and leaves out the settled ones" do
      social_post = compose("a cat and a dog")
      suggestion = suggest(social_post, typo("cat", "black cat"), typo("dog", "dogs"))
      Suggestions::Slice["repos.suggestion_mutations"].reject([suggestion.edits.last.id])

      expect(read(social_post.id).fetch("suggestion_edits")).to eq([open_edit(suggestion.edits.first)])
    end

    it "names the suggestion that holds the open edits" do
      social_post = compose("a cat")
      suggestion = suggest(social_post, typo("cat", "dog"))

      expect(read(social_post.id).fetch("suggestion_id")).to eq(suggestion.id)
    end

    it "gives a null suggestion_id once every edit is settled" do
      social_post = compose("a cat")
      suggestion = suggest(social_post, typo("cat", "dog"))
      Suggestions::Slice["repos.suggestion_mutations"].reject(suggestion.edits.map(&:id))

      expect(read(social_post.id).fetch("suggestion_id")).to be_nil
    end

    it "answers the records linked to the social post, grouped by kind" do
      social_post = create(:social_post, :posted)
      task = create(:task, title: "Announce the move")
      link(social_post.id, "task", task.id)

      expect(read(social_post.id).fetch("record_links"))
        .to match("task" => [include("kind" => "task", "id" => task.id, "title" => "Announce the move")])
    end

    it "answers an unknown ID with a 404" do
      expect([read(999_999), status])
        .to eq([{ "error" => "not_found", "message" => "no social post has the ID 999999" }, 404])
    end

    it "refuses an ID that is not a number with a 422" do
      expect([read("abc").fetch("errors").keys, status]).to eq([%w[id], 422])
    end
  end

  describe "the MCP tool" do
    it "answers as GET /api/v1/social_posts/:id does" do
      social_post = compose("teh cat sat")
      deliver(social_post, "mastodon", error: "slow")
      suggest(social_post, typo("teh", "the"))

      expect(mcp_answer("read_social_post", id: social_post.id)).to eq(read(social_post.id))
    end

    it "names each account as GET /api/v1/social_posts/:id does" do
      social_post = create(:social_post, :posted, targets: %w[mastodon])
      connect_two_mastodons.each { deliver(social_post, "mastodon", connection_id: it.id, **sent_counts) }

      expect(mcp_answer("read_social_post", id: social_post.id)).to eq(read(social_post.id))
    end

    it "reads a social hit from search whatever its status" do
      %i[draft scheduled posted].each { mention_zeppelin(create(:social_post, it)) }
      hits = mcp_answer("search", query: "zeppelin").fetch("results").select { it.fetch("kind") == "social" }

      expect(hits.map { mcp_answer("read_social_post", id: it.fetch("id")).fetch("status") })
        .to match_array(%w[draft scheduled posted])
    end

    it "refuses an unknown ID with the message the endpoint gives" do
      expect(mcp_text("read_social_post", id: 999_999)).to eq(read(999_999).fetch("message"))
    end
  end
end

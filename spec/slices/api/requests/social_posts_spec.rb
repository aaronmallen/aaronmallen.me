# frozen_string_literal: true

RSpec.describe "API social posts", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def at(day, hour = 12) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, 0)

  def call_api(verb, path, body = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/social_posts#{path}", body, headers)
    JSON.parse(last_response.body)
  end

  def compose(*parts, status: "draft", targets: %w[mastodon], **)
    Social::Slice["repos.social_post_mutations"].create_with_parts(parts:, status:, targets:, **)
  end

  def create_social_post(fields) = call_api(:post, "", JSON.generate(fields))

  def delete_social_post(id) = call_api(:delete, "/#{id}")

  def list(**query) = call_api(:get, "", query)

  def send_social_post(id, fields = {}) = call_api(:post, "/#{id}/send", JSON.generate(fields))

  def status = last_response.status

  def status_of
    yield
    status
  end

  def stored(id) = Social::Slice["repos.social_post_queries"].by_id(id)

  def taken
    @taken ||= create(:social_post, :scheduled).tap do |social_post|
      create(:social_post_delivery, :mastodon, social_post_id: social_post.id)
    end
  end

  def targeted(id) = Social::Slice["operations.list_target_accounts"].call(stored(id)).map(&:id)

  def update_social_post(id, fields) = call_api(:patch, "/#{id}", JSON.generate(fields))

  before { connect_social_networks }

  describe "GET /api/v1/social_posts" do
    def march = { from: "2026-03-01", to: "2026-03-31" }

    it "lists the range's posts, newest first, with the counts per queue" do
      sent = create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 2)))
      queued = create(:social_post, :scheduled, posted_at: at(Date.new(2026, 3, 20)))
      listed = list(**march)

      expect([listed.fetch("social_posts").map { it.fetch("id") }, listed.fetch("counts"), status])
        .to eq([[queued.id, sent.id], { "queued" => 1, "posted" => 1, "drafts" => 0 }, 200])
    end

    it "keeps only the queue asked for" do
      create(:social_post, :posted, posted_at: at(Date.new(2026, 3, 2)))
      draft = create(:social_post, :draft, created_at: at(Date.new(2026, 3, 10)))

      expect(list(**march, queue: "drafts").fetch("social_posts").map { it.fetch("id") }).to eq([draft.id])
    end

    it "gives each post's lengths" do
      compose("hi", "there")

      expect(list.fetch("social_posts").first.fetch("lengths"))
        .to eq([{ "mastodon" => { "count" => 2, "limit" => 500 } }, { "mastodon" => { "count" => 5, "limit" => 500 } }])
    end

    it "pages through the posts" do
      kept = 1.upto(3).map { create(:social_post, :posted, posted_at: at(Date.new(2020, 1, it))) }.reverse
      lower_page_size(:mcp, to: 2)
      first = list(page: 1)

      expect([first.values_at("partial", "next_page"), list(page: 2).fetch("social_posts").map { it.fetch("id") }])
        .to eq([[true, 2], [kept.last.id]])
    end

    it "refuses a day it cannot read with a 422" do
      expect([list(from: "March").fetch("message"),
              status]).to eq(["give from and to as days, such as 2026-01-01", 422])
    end

    it "answers as list_social_posts does" do
      compose("hi")

      expect(mcp_answer("list_social_posts", queue: "drafts")).to eq(list(queue: "drafts"))
    end
  end

  describe "POST /api/v1/social_posts" do
    it "saves a draft and answers with it" do
      answer = create_social_post(parts: %w[hello there], targets: %w[mastodon])

      expect([stored(answer.fetch("id")).status, answer.fetch("parts"), status]).to eq(["draft", %w[hello there], 201])
    end

    it "refuses empty text with a 422" do
      expect([create_social_post(parts: [" "], targets: %w[mastodon]).fetch("message"), status])
        .to eq(["parts is empty", 422])
    end

    it "answers as create_social_post does, save the ID" do
      answer = mcp_answer("create_social_post", parts: %w[hi], targets: %w[mastodon])

      expect(answer.except("id", "created_at", "updated_at"))
        .to eq(create_social_post(parts: %w[hi], targets: %w[mastodon]).except("id", "created_at", "updated_at"))
    end
  end

  describe "PATCH /api/v1/social_posts/:id" do
    it "replaces the parts and keeps the networks" do
      draft = compose("old")
      update_social_post(draft.id, parts: %w[new])

      expect(stored(draft.id)).to have_attributes(targets: %w[mastodon], parts: [have_attributes(body: "new")])
    end

    it "changes the networks and keeps the parts" do
      draft = compose("old")
      answer = update_social_post(draft.id, targets: %w[mastodon bluesky])

      expect([answer.fetch("targets"), answer.fetch("parts")]).to eq([%w[mastodon bluesky], %w[old]])
    end

    it "sends to every account on a network it adds to a post that picked accounts" do
      other = connect_another_mastodon
      bluesky = connect_another_bluesky
      draft = compose("old", connection_ids: [other.id])
      update_social_post(draft.id, targets: %w[mastodon bluesky])

      expect(targeted(draft.id)).to eq([other.id, social_account("bluesky").id, bluesky.id])
    end

    it "refuses a post that has gone out with a 422" do
      sent = create(:social_post, :posted)

      expect([update_social_post(sent.id, parts: %w[new]).fetch("message"), status])
        .to eq(["social post #{sent.id} has gone out, so nothing was saved", 422])
    end

    it "answers an unknown ID with a 404" do
      expect([update_social_post(999_999, parts: %w[new]).fetch("message"), status])
        .to eq(["no social post has the ID 999999", 404])
    end
  end

  describe "POST /api/v1/social_posts/:id/send" do
    it "queues the post to go out now" do
      draft = compose("hi")

      expect([send_social_post(draft.id).fetch("status"), stored(draft.id).posted_at])
        .to match(["scheduled", be_within(60).of(Time.now)])
    end

    it "queues the post for schedule_at" do
      draft = compose("hi")
      send_social_post(draft.id, schedule_at: "2030-01-02T09:30")

      expect(stored(draft.id).posted_at).to eq(Blog::TimeZone.local_time(2030, 1, 2, 9, 30))
    end

    it "names each part and network over its limit with a 422" do
      long = compose("a" * 501, "b" * 301, targets: %w[mastodon bluesky])
      runs = "part 1 runs 501 of 500 on mastodon, part 1 runs 501 of 300 on bluesky, part 2 runs 301 of 300 on bluesky"

      expect([send_social_post(long.id).fetch("message"), status])
        .to eq(["parts has a part over the limit for a network you picked: #{runs}", 422])
    end

    it "refuses a post that has gone out with a 422" do
      sent = create(:social_post, :posted)

      expect(status_of { send_social_post(sent.id) }).to eq(422)
    end

    it "answers an unknown ID with a 404" do
      expect(status_of { send_social_post(999_999) }).to eq(404)
    end

    it "refuses as send_social_post does" do
      long = compose("a" * 501)

      expect(mcp_text("send_social_post", id: long.id)).to eq(send_social_post(long.id).fetch("message"))
    end
  end

  describe "DELETE /api/v1/social_posts/:id" do
    it "deletes a post that has not gone out" do
      draft = compose("hi")

      expect([delete_social_post(draft.id), stored(draft.id)]).to eq([{ "id" => draft.id, "deleted" => true }, nil])
    end

    it "keeps a post a network has taken and answers 422" do
      answer = delete_social_post(taken.id)

      expect([answer.fetch("message"), status, stored(taken.id)])
        .to match(["social post #{taken.id} has gone out, so nothing was removed", 422, be_truthy])
    end

    it "answers an unknown ID with a 404" do
      expect(status_of { delete_social_post(999_999) }).to eq(404)
    end

    it "deletes as delete_social_post does" do
      draft = compose("hi")

      expect(mcp_answer("delete_social_post", id: draft.id)).to eq("id" => draft.id, "deleted" => true)
    end
  end
end

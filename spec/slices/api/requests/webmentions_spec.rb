# frozen_string_literal: true

RSpec.describe "API reading webmentions", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def at(day) = Blog::TimeZone.local_time(day.year, day.month, day.day, 12, 0)

  def counts(pending: 0, approved: 0, ignored: 0, spam: 0)
    { "pending" => pending, "approved" => approved, "ignored" => ignored, "spam" => spam }
  end

  def fields(mention)
    {
      "id" => mention.id,
      "post_id" => mention.post_id,
      "type" => mention.type,
      "status" => mention.status,
      "source_url" => mention.source_url,
      "author_name" => mention.author_name,
      "author_url" => mention.author_url,
      "excerpt" => mention.excerpt,
      "spam_reason" => mention.spam_reason,
      "received_at" => mention.received_at.utc.iso8601,
    }
  end

  def get_json(path, params = nil)
    get path, params, { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    JSON.parse(last_response.body)
  end

  def ids(answer) = answer.fetch("webmentions").map { it.fetch("id") }

  def list(**params) = get_json("/api/v1/webmentions", { **range, **params })

  def range = { from: "2026-03-01", to: "2026-03-31" }

  def read(id) = get_json("/api/v1/webmentions/#{id}")

  def status = last_response.status

  describe "GET /api/v1/webmentions" do
    it "lists the webmentions received in the range, newest first" do
      older = create(:webmention, received_at: at(Date.new(2026, 3, 2)))
      newer = create(:webmention, received_at: at(Date.new(2026, 3, 20)))
      create(:webmention, received_at: at(Date.new(2026, 4, 1)))

      expect([ids(list), status]).to eq([[newer.id, older.id], 200])
    end

    it "gives each webmention's fields, the window and its time zone" do
      mention = create(:webmention, :spam, spam_reason: "link farm", received_at: at(Date.new(2026, 3, 2)))

      expect(list).to eq(
        "from" => "2026-03-01", "to" => "2026-03-31", "time_zone" => "America/Chicago",
        "counts" => counts(spam: 1), "webmentions" => [fields(mention)], "partial" => false,
      )
    end

    it "lists every webmention, newest first, when given no range" do
      older = create(:webmention, received_at: at(Date.new(2024, 3, 2)))
      newer = create(:webmention, received_at: at(Date.new(2026, 3, 20)))

      answer = get_json("/api/v1/webmentions")

      expect([ids(answer), answer.values_at("from", "to"), status]).to eq([[newer.id, older.id], [nil, nil], 200])
    end

    it "pages through every webmention in one status when given no range" do
      kept = 1.upto(3).map { create(:webmention, received_at: at(Date.new(2020, 1, it))) }.reverse
      create(:webmention, :spam)
      lower_page_size(:mcp, to: 2)

      pages = [1, 2].flat_map { ids(get_json("/api/v1/webmentions", { status: "pending", page: it })) }

      expect(pages).to eq(kept.map(&:id))
    end

    it "lists every webmention from a day on when given only from" do
      create(:webmention, received_at: at(Date.new(2026, 2, 28)))
      kept = create(:webmention, received_at: at(Date.new(2026, 5, 1)))

      expect(ids(get_json("/api/v1/webmentions", { from: "2026-03-01" }))).to eq([kept.id])
    end

    it "counts the webmentions in the range by status, whatever the status asked for" do
      create(:webmention, received_at: at(Date.new(2026, 3, 2)))
      create(:webmention, :spam, received_at: at(Date.new(2026, 3, 3)))
      create(:webmention, :spam, received_at: at(Date.new(2026, 3, 4)))
      create(:webmention, :approved, received_at: at(Date.new(2026, 4, 1)))

      expect(list(status: "pending").fetch("counts")).to eq(counts(pending: 1, spam: 2))
    end

    it "counts every webmention one post got when given no range" do
      mention = create(:webmention, :ignored, received_at: at(Date.new(2020, 3, 2)))
      create(:webmention, post_id: mention.post_id)
      create(:webmention)

      expect(get_json("/api/v1/webmentions", { post_id: mention.post_id }).fetch("counts"))
        .to eq(counts(pending: 1, ignored: 1))
    end

    it "narrows to the webmentions one post got" do
      create(:webmention, received_at: at(Date.new(2026, 3, 2)))
      mention = create(:webmention, received_at: at(Date.new(2026, 3, 3)))

      expect(ids(list(post_id: mention.post_id))).to eq([mention.id])
    end

    it "narrows to one post and one status together" do
      mention = create(:webmention, :approved, received_at: at(Date.new(2026, 3, 2)))
      create(:webmention, post_id: mention.post_id, received_at: at(Date.new(2026, 3, 3)))

      expect(ids(list(post_id: mention.post_id, status: "approved"))).to eq([mention.id])
    end

    it "lists nothing for a post with no webmentions" do
      create(:webmention, received_at: at(Date.new(2026, 3, 2)))

      expect(ids(list(post_id: create(:post).id))).to eq([])
    end

    it "refuses a post_id that is not a number with a 422" do
      expect([list(post_id: "abc").fetch("errors").keys, status]).to eq([%w[post_id], 422])
    end

    it "refuses a range that runs backwards with a 422" do
      expect([list(from: "2026-03-31", to: "2026-03-01").fetch("message"), status])
        .to eq(["from comes after to", 422])
    end
  end

  describe "GET /api/v1/webmentions/:id" do
    it "answers the webmention's fields with its post's title and slug" do
      article = create(:post, :published, title: "Hello there", slug: "hello-there")
      mention = create(:webmention, :reply, post_id: article.id)

      expect([read(mention.id), status])
        .to eq([fields(mention).merge("post_title" => "Hello there", "post_slug" => "hello-there"), 200])
    end

    it "answers an unknown ID with a 404" do
      expect([read(999_999), status])
        .to eq([{ "error" => "not_found", "message" => "no webmention has the ID 999999" }, 404])
    end

    it "refuses an ID that is not a number with a 422" do
      expect([read("abc").fetch("errors").keys, status]).to eq([%w[id], 422])
    end
  end

  describe "the MCP tools" do
    it "answers list_webmentions as GET /api/v1/webmentions does" do
      mention = create(:webmention, received_at: at(Date.new(2026, 3, 2)))
      create(:webmention, received_at: at(Date.new(2026, 3, 3)))

      expect(trusted(mcp_answer("list_webmentions", **range, post_id: mention.post_id)))
        .to eq(list(post_id: mention.post_id))
    end

    it "answers list_webmentions with no range as GET /api/v1/webmentions does" do
      create(:webmention, received_at: at(Date.new(2020, 3, 2)))
      create(:webmention, :spam)

      expect(trusted(mcp_answer("list_webmentions", status: "pending")))
        .to eq(get_json("/api/v1/webmentions", { status: "pending" }))
    end

    it "answers read_webmention as GET /api/v1/webmentions/:id does" do
      mention = create(:webmention, :reply)

      expect(trusted(mcp_answer("read_webmention", id: mention.id))).to eq(read(mention.id))
    end

    it "reads a webmention hit from search" do
      create(:webmention, excerpt: "a zeppelin flew past")
      hit = mcp_answer("search", query: "zeppelin").fetch("results").find { it.fetch("kind") == "webmention" }

      expect(trusted(mcp_answer("read_webmention", id: hit.fetch("id")))).to eq(read(hit.fetch("id")))
    end

    it "refuses an unknown ID with the message the endpoint gives" do
      expect(mcp_text("read_webmention", id: 999_999)).to eq(read(999_999).fetch("message"))
    end
  end
end

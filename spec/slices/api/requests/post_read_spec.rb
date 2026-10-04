# frozen_string_literal: true

RSpec.describe "API reading a post", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def open_edit(edit)
    {
      "id" => edit.id, "part" => nil, "original" => edit.original, "replacement" => edit.replacement,
      "reason" => "typo", "status" => "pending",
    }
  end

  def read(id)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/posts/#{id}", nil, headers
    JSON.parse(last_response.body)
  end

  def repo = Posts::Slice["repos.post_repo"]

  def shown(stored)
    {
      "id" => stored.id, "status" => "scheduled", "tags" => %w[ruby], "word_count" => 3, "read_time" => 1,
      "published_at" => stored.published_at.utc.iso8601, "created_at" => stored.created_at.utc.iso8601,
      "updated_at" => stored.updated_at.utc.iso8601, "webmentions_received" => 0, "edit_notes" => [],
      "suggestion_edits" => [], "record_links" => {}, **written.transform_keys(&:to_s),
    }
  end

  def status = last_response.status

  def suggest(article, *edits) = Suggestions::Slice["repos.suggestion_repo"].replace_for_post(article.id, edits)

  def typo(original, replacement) = { original:, replacement:, reason: "typo" }

  def written
    {
      title: "Hello", slug: "hello", summary: "A short hello", body: "one two three", og_title: "On the card",
      og_image_url: "https://example.com/card.png", canonical_url: "https://elsewhere.example/hello",
      syndication_enabled: true, syndication_body: "Out now", syndication_targets: %w[bluesky],
      webmentions_enabled: true,
    }
  end

  describe "GET /api/v1/posts/:id" do
    it "answers every field the admin editor shows" do
      article = create(:post, :scheduled, **written)
      repo.replace_tags(article.id, %w[ruby])

      expect([read(article.id), status]).to match([include(shown(repo.by_id(article.id))), 200])
    end

    it "gives empty text and null card fields for a post that leaves them blank" do
      expect(read(create(:post, :draft).id)).to include(
        "summary" => "", "og_title" => nil, "og_image_url" => nil, "canonical_url" => nil, "published_at" => nil,
      )
    end

    it "counts the webmentions the post has received" do
      article = create(:post, :published)
      2.times { create(:webmention, post_id: article.id) }

      expect(read(article.id).fetch("webmentions_received")).to eq(2)
    end

    it "gives the edit notes newest first" do
      article = create(:post, :published)
      older = create(:post_edit, post_id: article.id, note: "fixed a typo", created_at: Time.now - 3600)
      newer = create(:post_edit, post_id: article.id, note: "added a link")

      expect(read(article.id).fetch("edit_notes").map { it.slice("id", "note") })
        .to eq([{ "id" => newer.id, "note" => "added a link" }, { "id" => older.id, "note" => "fixed a typo" }])
    end

    it "gives the suggested edits still open, and leaves out the settled ones" do
      article = create(:post, :draft, body: "a cat and a dog")
      suggestion = suggest(article, typo("cat", "black cat"), typo("dog", "dogs"))
      Suggestions::Slice["repos.suggestion_repo"].reject([suggestion.edits.last.id])

      expect(read(suggestion.post_id).fetch("suggestion_edits")).to eq([open_edit(suggestion.edits.first)])
    end

    it "gives the records linked to the post, grouped by kind" do
      article = create(:post, :draft)
      commit = create(:commit, message: "Move the server")
      Links::Slice["operations.link_records"].call("post", article.id, { other_kind: "commit", other_id: commit.id })

      expect(read(article.id).fetch("record_links"))
        .to match("commit" => [include("kind" => "commit", "id" => commit.id, "title" => "Move the server")])
    end

    it "answers 404 for a post that isn't there" do
      expect([read(999_999), status])
        .to eq([{ "error" => "not_found", "message" => "no blog post has the ID 999999" }, 404])
    end
  end

  describe "the MCP tool" do
    it "answers as GET /api/v1/posts/:id does" do
      article = create(:post, :published, **written)
      repo.replace_tags(article.id, %w[ruby])
      create(:post_edit, post_id: article.id)

      expect(mcp_answer("read_post", id: article.id)).to eq(read(article.id))
    end

    it "refuses an unknown ID with the message the endpoint gives" do
      expect(mcp_text("read_post", id: 999_999)).to eq(read(999_999).fetch("message"))
    end
  end
end

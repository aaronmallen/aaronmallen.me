# frozen_string_literal: true

RSpec.describe "API bulk post actions", type: :request do
  def act(name, ids, **fields) = call_api(name, JSON.generate(ids:, **fields))

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(name, body)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    post "/api/v1/posts/bulk/#{name}", body, headers
    JSON.parse(last_response.body)
  end

  def deleted(article) = { "id" => article.id, "title" => article.title, "deleted" => true }

  def drafts(count) = Array.new(count) { create(:post, :draft) }

  def fail_with(failure)
    replace_component("posts.operations.act_on_posts", instance_double(Posts::Operations::ActOnPosts, call: failure))
  end

  def gone_id = create(:post).id.tap { repo.delete(it) }

  def ids(posts) = posts.map(&:id)

  def kept?(article) = !repo.by_id(article.id).nil?

  def missing(id) = "no blog post has the ID #{id}"

  def refusal(message) = { "error" => "invalid", "message" => message, "errors" => { "ids" => [message] } }

  def repo = Posts::Slice["repos.post_repo"]

  def status = last_response.status

  def tag_names(article) = repo.by_id(article.id).tags.map(&:name).sort

  def tagged(*names, **attributes) = create(:post, **attributes).tap { repo.replace_tags(it.id, names) }

  describe "POST /api/v1/posts/bulk/delete" do
    let!(:picked) { [create(:post, :draft, title: "One"), create(:post, :draft, title: "Two")] }
    let!(:left) { create(:post, :draft) }

    it "deletes the drafts it names and answers them" do
      answer = act("delete", ids(picked))

      expect([answer, status, picked.map { kept?(it) }])
        .to eq([{ "posts" => picked.map { deleted(it) } }, 200, [false, false]])
    end

    it "leaves the rest alone" do
      act("delete", ids(picked))

      expect(kept?(left)).to be(true)
    end

    it "deletes none when one ID is gone and names it" do
      gone = gone_id

      expect([act("delete", [*ids(picked), gone]), status, picked.map { kept?(it) }])
        .to eq([refusal(missing(gone)), 422, [true, true]])
    end

    it "deletes none when one post is not a draft and names it" do
      published = create(:post, :published)
      answer = act("delete", [*ids(picked), published.id])

      expect([answer.fetch("errors"), status, [*picked, published].map { kept?(it) }])
        .to eq([{ "ids" => ["blog post #{published.id} is not a draft"] }, 422, [true, true, true]])
    end
  end

  describe "POST /api/v1/posts/bulk/tag" do
    let!(:picked) { [tagged("ruby"), tagged(status: "published", published_at: Time.now)] }

    it "adds the tag to each post, in any status, and keeps the ones it had" do
      answer = act("tag", ids(picked), tag: "Release")

      expect([answer.fetch("posts").map { it.values_at("id", "tags") }, status])
        .to eq([[[picked.first.id, %w[release ruby]], [picked.last.id, %w[release]]], 200])
    end

    it "answers each post as it stands" do
      article = picked.first
      shown = { "id" => article.id, "title" => article.title, "slug" => article.slug, "status" => "draft" }

      expect(act("tag", [article.id], tag: "release").fetch("posts").first.except("tags", "updated_at"))
        .to eq(shown.merge("published_at" => nil))
    end

    it "tags none when one ID is gone and names it" do
      gone = gone_id

      expect([act("tag", [*ids(picked), gone], tag: "release"), status, picked.map { tag_names(it) }])
        .to eq([refusal(missing(gone)), 422, [%w[ruby], []]])
    end

    it "refuses a tag that is not lowercase words" do
      answer = act("tag", ids(picked), tag: "two words")

      expect([answer.fetch("errors"), status]).to eq([{ "tag" => ["a tag is lowercase words"] }, 422])
    end

    it "refuses a blank tag" do
      expect(act("tag", ids(picked), tag: " ").fetch("message")).to eq("tag: name the tag first")
    end

    it "refuses a request with no tag" do
      expect(act("tag", ids(picked)).fetch("errors")).to eq("tag" => ["tag is missing"])
    end
  end

  describe "the list of IDs" do
    it "acts on a repeated ID once" do
      article = create(:post)

      expect(act("tag", [article.id, article.id], tag: "ruby").fetch("posts").map { it.fetch("id") })
        .to eq([article.id])
    end

    it "refuses an empty list" do
      expect([act("delete", []).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses more than 100 IDs" do
      expect([act("delete", (1..101).to_a).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses an ID that is not a number" do
      expect([act("delete", ["one"]).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses a request with no IDs" do
      expect(call_api("delete", "{}").fetch("errors")).to eq("ids" => ["ids is missing"])
    end
  end

  it "answers a failure it did not expect with a 500 that names the post" do
    article = create(:post)
    fail_with(Dry::Monads::Failure[:record, article.id, :unexpected])

    expect([act("delete", [article.id]), status])
      .to eq([{ "error" => "failed", "message" => "could not change blog post #{article.id}" }, 500])
  end

  describe "the MCP tools" do
    it "tag as tag_posts does" do
      first = tagged("rails", title: "same", slug: "same-one")
      last = tagged("rails", title: "same", slug: "same-two")
      shape = ->(answer) { answer.fetch("posts").map { it.except("id", "slug", "updated_at") } }

      expect(shape.call(mcp_answer("tag_posts", ids: [last.id], tag: "ruby")))
        .to eq(shape.call(act("tag", [first.id], tag: "ruby")))
    end

    it "delete as delete_posts does" do
      first = create(:post, :draft, title: "same")
      last = create(:post, :draft, title: "same")
      answer = act("delete", [first.id])

      expect(mcp_answer("delete_posts", ids: [last.id]))
        .to eq("posts" => answer.fetch("posts").map { it.merge("id" => last.id) })
    end

    it "refuse a post that is not a draft with the message the endpoint gives" do
      published = create(:post, :published)
      refused = act("delete", [published.id])

      expect(mcp_text("delete_posts", ids: [published.id])).to eq(refused.fetch("message"))
    end
  end
end

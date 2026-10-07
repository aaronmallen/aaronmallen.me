# frozen_string_literal: true

RSpec.describe "API publishing a post", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def overlong = { syndication_enabled: true, syndication_body: "a" * 301, syndication_targets: %w[bluesky] }

  def post_queries = Posts::Slice["repos.post_queries"]

  def publish(id, body = "{}")
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    post "/api/v1/posts/#{id}/publish", body, headers
    JSON.parse(last_response.body)
  end

  def status = last_response.status

  def stored(article) = post_queries.by_id(article.id)

  describe "POST /api/v1/posts/:id/publish" do
    it "publishes a draft now and answers it", :aggregate_failures do
      draft = create(:post, :draft, slug: "hello")
      answered = include("id" => draft.id, "slug" => "hello", "status" => "published", "outcome" => "published")

      expect([publish(draft.id), status]).to match([answered, 200])
      expect(stored(draft).published_at).to be_within(60).of(Time.now)
    end

    it "schedules a draft whose publish time is still to come" do
      draft = create(:post, :draft, published_at: Time.now + (3 * 24 * 60 * 60))

      expect(publish(draft.id)).to include("status" => "scheduled", "outcome" => "scheduled")
    end

    it "publishes a scheduled post now", :aggregate_failures do
      scheduled = create(:post, :scheduled)

      expect(publish(scheduled.id)).to include("status" => "published", "outcome" => "published")
      expect(stored(scheduled).published_at).to be_within(60).of(Time.now)
    end

    it "refuses a post already published and leaves it as it was", :aggregate_failures do
      published = create(:post, :published)
      message = "blog post #{published.id} is already published"

      expect([publish(published.id), status])
        .to eq([{ "error" => "invalid", "message" => message, "errors" => { "id" => [message] } }, 422])
      expect(stored(published).published_at).to be_within(1).of(published.published_at)
    end

    it "sends no second webmention pass for a post already published", :commits do
      publish(create(:post, :published).id)

      expect(Social::Jobs::SendWebmentions.jobs).to be_empty
    end

    it "refuses a post that fails the editor's checks and leaves it a draft", :aggregate_failures do
      draft = create(:post, :draft, **overlong)
      message = "syndication_body runs over a network's limit"

      expect([publish(draft.id), status])
        .to eq([{ "error" => "invalid", "message" => message, "errors" => { "syndication_body" => [message] } }, 422])
      expect(stored(draft).status).to eq("draft")
    end

    it "answers 404 for a post that isn't there" do
      expect([publish(999_999), status])
        .to eq([{ "error" => "not_found", "message" => "no blog post has the ID 999999" }, 404])
    end

    it "answers 500 when the publish fails some other way" do
      failing = instance_double(Posts::Operations::PublishDraft, call: Dry::Monads::Failure(:not_due))
      replace_component("posts.operations.publish_draft", failing)

      expect([publish(create(:post, :draft).id), status])
        .to eq([{ "error" => "failed", "message" => "could not save the change" }, 500])
    end
  end

  describe "the MCP tool" do
    it "publishes as publish_post does" do
      shape = ->(answer) { answer.except("id", "slug", "published_at", "updated_at") }
      first = create(:post, :draft, title: "same")
      last = create(:post, :draft, title: "same")

      expect(shape.call(mcp_answer("publish_post", id: last.id))).to eq(shape.call(publish(first.id)))
    end

    it "refuses a published post with the message the endpoint gives" do
      published = create(:post, :published)

      expect(mcp_text("publish_post", id: published.id)).to eq(publish(published.id).fetch("message"))
    end
  end
end

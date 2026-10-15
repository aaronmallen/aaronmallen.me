# frozen_string_literal: true

RSpec.describe "API blog posts", type: :request do
  def post_queries = Posts::Slice["repos.post_queries"]

  def status = last_response.status

  describe "GET /api/v1/posts" do
    it "lists the blog posts with their figures and the unsent social posts" do
      post = create(:post, :draft, body: "one two three")

      expect([call_api(:get, "/posts").fetch("posts").map { it.values_at("id", "draft", "word_count") }, status])
        .to eq([[[post.id, true, 3]], 200])
    end

    it "keeps only the blog posts in the status asked for" do
      create(:post, :draft)

      expect(call_api(:get, "/posts", { status: "published" }).fetch("posts")).to be_empty
    end

    it "answers the same JSON as list_posts" do
      create(:post, :published)

      expect(call_api(:get, "/posts")).to eq(mcp_answer("list_posts"))
    end

    it "refuses a day it cannot read with a 422" do
      call_api(:get, "/posts", { from: "soon" })

      expect(status).to eq(422)
    end
  end

  describe "POST /api/v1/posts" do
    it "writes a draft with a 201" do
      found = call_api(:post, "/posts", JSON.generate(title: "Hello", body: "hi", tags: %w[ruby]))

      expect([found.values_at("title", "status", "tags", "outcome"), status])
        .to eq([["Hello", "draft", %w[ruby], "drafted"], 201])
    end

    it "refuses a slug it cannot take with a 422" do
      found = call_api(:post, "/posts", JSON.generate(title: "Hello", slug: "Not A Slug"))

      expect([found.fetch("errors").keys, status]).to eq([%w[slug], 422])
    end
  end

  describe "PATCH /api/v1/posts/:id" do
    it "changes the fields it was given and keeps the rest" do
      post = create(:post, :draft, title: "Hello", body: "hi")
      call_api(:patch, "/posts/#{post.id}", JSON.generate(body: "hello there"))

      expect(post_queries.by_id(post.id).then { [it.title, it.body] }).to eq(["Hello", "hello there"])
    end

    it "refuses a past publish time on a scheduled post with a 422" do
      post = create(:post, :scheduled)
      call_api(:patch, "/posts/#{post.id}", JSON.generate(publish_at: "2020-01-01T09:00"))

      expect([JSON.parse(last_response.body).fetch("errors").keys, status]).to eq([%w[publish_at], 422])
    end

    it "answers an unknown ID with a 404" do
      call_api(:patch, "/posts/999999", JSON.generate(title: "Ghost"))

      expect(status).to eq(404)
    end
  end

  describe "DELETE /api/v1/posts/:id" do
    it "deletes the post for good", :aggregate_failures do
      post = create(:post, :published)

      expect([call_api(:delete, "/posts/#{post.id}"), status]).to eq([{ "id" => post.id, "deleted" => true }, 200])
      expect(post_queries.by_id(post.id)).to be_nil
    end

    it "answers an unknown ID with a 404" do
      expect([call_api(:delete, "/posts/999999").fetch("message"),
              status]).to eq(["no blog post has the ID 999999", 404])
    end
  end

  describe "PATCH /api/v1/posts/:id/seo" do
    it "sets the social card fields and answers what the post carries" do
      post = create(:post, :draft)

      expect(call_api(:patch, "/posts/#{post.id}/seo", JSON.generate(og_title: "On the card")))
        .to eq("id" => post.id, "canonical_url" => nil, "og_image_url" => nil, "og_title" => "On the card")
    end

    it "refuses an image link that is not a URL with a 422" do
      post = create(:post, :draft)
      call_api(:patch, "/posts/#{post.id}/seo", JSON.generate(og_image_url: "card.png"))

      expect(status).to eq(422)
    end
  end

  describe "GET /api/v1/posts/:id/announcement" do
    it "composes the announcement without sending it" do
      post = create(:post, :draft, syndication_body: "out now")

      announcement = mcp_answer("compose_announcement", id: post.id).fetch("announcement")

      expect([call_api(:get, "/posts/#{post.id}/announcement"), status])
        .to eq([{ "id" => post.id, "announcement" => announcement }, 200])
    end

    it "answers an unknown ID with a 404" do
      call_api(:get, "/posts/999999/announcement")

      expect(status).to eq(404)
    end
  end
end

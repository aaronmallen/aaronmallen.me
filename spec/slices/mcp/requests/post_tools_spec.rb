# frozen_string_literal: true

RSpec.describe "MCP post tools", type: :request do
  let(:post_repo) { Posts::Slice["repos.post_repo"] }

  def access_token
    @access_token ||= mcp_connect(
      Spec::DB::Factories[:mcp].create(:oauth_client), verifier: MCP::OAuth::Secret.generate, scope: "read write",
    ).fetch("access_token")
  end

  def admin_error(field, code) = Admin::Slice["i18n"].t(code, scope: ["ui.components.posts.field_error", field])

  def admin_save(path = "/admin/posts", intent: "draft", **fields)
    post path, _csrf_token: admin_csrf_token, intent:, post: fields
    Capybara.string(last_response.body).find(".field-error").text
  end

  def admin_save_published(post, **fields)
    admin_save("/admin/posts/#{post.id}", intent: "save", title: post.title, slug: post.slug, body: post.body, **fields)
  end

  def announced = { syndication_body: "In my own words", syndication_enabled: true, syndication_targets: %w[mastodon] }

  def call_tool(name, **arguments)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
    params = { name:, arguments: }
    post "/mcp", JSON.generate({ jsonrpc: "2.0", id: 1, method: "tools/call", params: }), headers
  end

  def content = JSON.parse(message)

  def future(days = 3) = Blog::TimeZone.input_value(Time.now + (days * 24 * 60 * 60))

  def message = result.fetch("content").first.fetch("text")

  def refused? = result.fetch("isError", false)

  def result = JSON.parse(last_response.body).fetch("result")

  def stored(id) = post_repo.by_id(id)

  describe "create_post" do
    it "writes a draft" do
      call_tool("create_post", title: "Hello", body: "one two")

      expect(post_repo.all).to contain_exactly(have_attributes(title: "Hello", body: "one two", status: "draft"))
    end

    it "answers with the post it wrote" do
      call_tool("create_post", title: "Hello")

      expect(content).to eq(
        "id" => post_repo.all.last.id, "status" => "draft", "title" => "Hello", "slug" => "hello",
        "published_at" => nil, "outcome" => "drafted",
      )
    end

    it "takes the slug from the title when it names none" do
      call_tool("create_post", title: "Hello, World")

      expect(post_repo.all.last.slug).to eq("hello-world")
    end

    it "takes the summary, tags and social card" do
      call_tool("create_post", title: "Hello", summary: "In short", tags: %w[Ruby hanami], og_title: "On the card")

      expect(post_repo.all.last)
        .to have_attributes(written_summary: "In short", tags: [have_attributes(name: "hanami"),
                                                                have_attributes(name: "ruby")], og_title: "On the card")
    end

    it "takes the announcement" do
      call_tool("create_post", title: "Hello", **announced)

      expect(post_repo.all.last).to have_attributes(**announced)
    end

    it "leaves the announcement off when it is not asked for" do
      call_tool("create_post", title: "Hello")

      expect(post_repo.all.last.syndication_enabled).to be(false)
    end

    it "keeps a draft with a publish time still to come a draft" do
      call_tool("create_post", title: "Hello", publish_at: future)

      expect(post_repo.all.last.status).to eq("draft")
    end

    it "refuses a post with no title" do
      call_tool("create_post", title: "  ")

      expect(message).to eq("title is empty")
    end

    it "refuses a slug another post holds, as the admin does", :aggregate_failures do
      create(:post, slug: "hello")
      call_tool("create_post", title: "Hello")

      expect(message).to eq("slug belongs to another post")
      expect(admin_save(title: "Hello")).to eq(admin_error(:slug, "taken"))
    end

    it "refuses a slug a site page holds, as the admin does", :aggregate_failures do
      call_tool("create_post", title: "Hello", slug: "tags")

      expect(message).to eq("slug belongs to a page on the site")
      expect(admin_save(title: "Hello", slug: "tags")).to eq(admin_error(:slug, "reserved"))
    end

    it "refuses a title with no letter or number to make a slug from, as the admin does", :aggregate_failures do
      call_tool("create_post", title: "!!!")

      expect(message).to eq("slug needs a letter or number, from itself or from the title")
      expect(admin_save(title: "!!!")).to eq(admin_error(:slug, "blank"))
    end

    it "refuses a publish time it cannot read, as the admin does", :aggregate_failures do
      call_tool("create_post", title: "Hello", publish_at: "next friday")

      expect(message).to eq("publish_at needs a time as YYYY-MM-DDTHH:MM, in Chicago time")
      expect(admin_save(title: "Hello", publish_at: "next friday")).to eq(admin_error(:publish_at, "format"))
    end

    it "refuses a tag that is not a slug, as the admin does", :aggregate_failures do
      call_tool("create_post", title: "Hello", tags: ["two words"])

      expect(message).to eq("tags each take lowercase letters, numbers and single dashes")
      expect(admin_save(title: "Hello", tags: "two words")).to eq(admin_error(:tags, "format"))
    end

    it "refuses a body holding a NUL" do
      call_tool("create_post", title: "Hello", body: "a\u0000b")

      expect(message).to eq("body holds a control character")
    end

    it "names every field at fault" do
      call_tool("create_post", title: "Hello", og_image_url: "card.png", publish_at: "soon")

      expect(message).to eq(
        "og_image_url needs a URL starting with http:// or https://; " \
        "publish_at needs a time as YYYY-MM-DDTHH:MM, in Chicago time",
      )
    end

    it "saves nothing when it refuses" do
      call_tool("create_post", title: "Hello", publish_at: "soon")

      expect(post_repo.all).to be_empty
    end

    it "says it saved nothing when the save fails for a reason it does not know" do
      failing = instance_double(Posts::Operations::SavePost, call: Dry::Monads::Failure(:unexpected))
      replace_component("posts.operations.save_post", failing)
      call_tool("create_post", title: "Hello")

      expect(message).to eq("could not save the blog post")
    end

    it "refuses a call with no title" do
      call_tool("create_post", body: "one two")

      expect(refused?).to be(true)
    end
  end

  describe "update_post" do
    def draft = @draft ||= create(:post, :draft, title: "Hello", slug: "hello", body: "one", **announced)

    it "changes the body" do
      call_tool("update_post", id: draft.id, body: "two")

      expect(stored(draft.id).body).to eq("two")
    end

    it "keeps every field the call leaves out" do
      before_update = stored(draft.id).to_h
      call_tool("update_post", id: draft.id, body: "two")

      changed = %i[body search_vector updated_at]

      expect(stored(draft.id).to_h.except(*changed)).to eq(before_update.except(*changed))
    end

    it "keeps the tags a post carries" do
      call_tool("update_post", id: draft.id, tags: %w[ruby])
      call_tool("update_post", id: draft.id, body: "two")

      expect(stored(draft.id).tags.map(&:name)).to eq(%w[ruby])
    end

    it "changes the other fields it is given" do
      call_tool("update_post", id: draft.id, title: "Goodbye", slug: "goodbye", webmentions_enabled: false)

      expect(stored(draft.id)).to have_attributes(title: "Goodbye", slug: "goodbye", webmentions_enabled: false)
    end

    it "clears a field an empty string names" do
      call_tool("update_post", id: draft.id, summary: "")

      expect(stored(draft.id).written_summary).to be_nil
    end

    it "keeps a draft a draft" do
      call_tool("update_post", id: draft.id, body: "two")

      expect(content).to include("status" => "draft", "outcome" => "drafted")
    end

    it "keeps a scheduled post scheduled, at the minute it was set for", :aggregate_failures do
      scheduled = create(:post, :scheduled)
      call_tool("update_post", id: scheduled.id, body: "two")

      expect(stored(scheduled.id).status).to eq("scheduled")
      expect(Blog::TimeZone.input_value(stored(scheduled.id).published_at))
        .to eq(Blog::TimeZone.input_value(scheduled.published_at))
    end

    it "moves a scheduled post to a new publish time" do
      scheduled = create(:post, :scheduled)
      call_tool("update_post", id: scheduled.id, publish_at: future(5))

      expect(Blog::TimeZone.input_value(stored(scheduled.id).published_at)).to eq(future(5))
    end

    it "refuses an empty publish time on a scheduled post and keeps its status and time", :aggregate_failures do
      scheduled = create(:post, :scheduled)
      call_tool("update_post", id: scheduled.id, publish_at: "", body: "two")

      expect(refused?).to be(true)
      expect(stored(scheduled.id)).to have_attributes(status: "scheduled", body: scheduled.body)
      expect(stored(scheduled.id).published_at).to be_within(1).of(scheduled.published_at)
    end

    it "refuses a past publish time on a scheduled post and points to publish_post", :aggregate_failures do
      scheduled = create(:post, :scheduled)
      call_tool("update_post", id: scheduled.id, publish_at: future(-1))

      expect(message).to include("publish_post")
      expect(stored(scheduled.id).status).to eq("scheduled")
      expect(stored(scheduled.id).published_at).to be_within(1).of(scheduled.published_at)
    end

    it "sends no announcement when it refuses a past publish time", :commits do
      scheduled = create(:post, :scheduled, **announced)
      call_tool("update_post", id: scheduled.id, publish_at: future(-1))

      expect(Social::Jobs::SyndicatePost.jobs).to be_empty
    end

    it "still clears the publish time of a draft" do
      call_tool("update_post", id: draft.id, publish_at: "")

      expect(stored(draft.id).published_at).to be_nil
    end

    it "edits a published post with an edit note and keeps it published", :aggregate_failures do
      published = create(:post, :published)
      call_tool("update_post", id: published.id, body: "fixed", edit_note: "fixed the numbers")

      expect(stored(published.id)).to have_attributes(body: "fixed", status: "published")
      expect(Posts::Slice["repos.post_edit_repo"].for_post(published.id).map(&:note)).to eq(["fixed the numbers"])
    end

    it "refuses a body change on a published post without an edit note, as the admin does", :aggregate_failures do
      published = create(:post, :published, title: "Hello", slug: "hello", body: "one")
      call_tool("update_post", id: published.id, body: "two")

      expect(message).to eq("edit_note is needed when the body of a published post changes: say what changed and why")
      expect(stored(published.id).body).to eq("one")
      expect(admin_save_published(published, body: "two")).to eq(admin_error(:edit_note, "blank"))
    end

    it "refuses an edit note over 500 characters" do
      published = create(:post, :published)
      call_tool("update_post", id: published.id, body: "fixed", edit_note: "a" * 501)

      expect(message).to eq("edit_note runs over 500 characters")
    end

    it "changes the tags of a published post with no edit note" do
      published = create(:post, :published)
      call_tool("update_post", id: published.id, tags: %w[ruby])

      expect(stored(published.id).tags.map(&:name)).to eq(%w[ruby])
    end

    it "keeps a published post's time" do
      published = create(:post, :published)
      call_tool("update_post", id: published.id, publish_at: future)

      expect(stored(published.id).published_at).to eq(published.published_at)
    end

    it "refuses a new slug on a published post, as the admin does", :aggregate_failures do
      published = create(:post, :published, title: "Hello", slug: "hello")
      call_tool("update_post", id: published.id, slug: "goodbye")

      expect(message).to eq("slug cannot change once the post is published")
      expect(admin_save_published(published, slug: "goodbye")).to eq(admin_error(:slug, "locked"))
    end

    it "leaves the post as it stands when it refuses" do
      call_tool("update_post", id: draft.id, body: "two", og_image_url: "card.png")

      expect(stored(draft.id).body).to eq("one")
    end

    it "calls an unknown ID an error" do
      call_tool("update_post", id: 404, body: "two")

      expect(message).to eq("no blog post has the ID 404")
    end
  end

  describe "publish_post" do
    def admin_publish(draft)
      fields = { title: "Hello", slug: "hello", **overlong, syndication_enabled: "1" }
      admin_save("/admin/posts/#{draft.id}", intent: "publish", **fields)
    end

    def overlong = { syndication_enabled: true, syndication_body: "a" * 301, syndication_targets: %w[bluesky] }

    it "publishes a draft now" do
      draft = create(:post, :draft)
      call_tool("publish_post", id: draft.id)

      expect(stored(draft.id).published_at).to be_within(60).of(Time.now)
    end

    it "answers with the post it published" do
      draft = create(:post, :draft)
      call_tool("publish_post", id: draft.id)

      expect(content).to include("id" => draft.id, "status" => "published", "outcome" => "published")
    end

    it "schedules a draft whose publish time is still to come" do
      draft = create(:post, :draft, published_at: Time.now + (3 * 24 * 60 * 60))
      call_tool("publish_post", id: draft.id)

      expect(content).to include("status" => "scheduled", "outcome" => "scheduled")
    end

    it "sends the announcement once it goes out", :commits do
      draft = create(:post, :draft, syndication_enabled: true, syndication_targets: %w[mastodon])
      call_tool("publish_post", id: draft.id)

      expect(Social::Jobs::SyndicatePost.jobs).to have(1).item
    end

    it "refuses an announcement over a network's limit, as the admin does", :aggregate_failures do
      draft = create(:post, :draft, title: "Hello", slug: "hello", **overlong)
      call_tool("publish_post", id: draft.id)

      expect(message).to eq("syndication_body runs over a network's limit")
      expect(admin_publish(draft)).to eq(admin_error(:syndication_body, "too_long"))
    end

    it "leaves a refused post a draft" do
      draft = create(:post, :draft, **overlong)
      call_tool("publish_post", id: draft.id)

      expect(stored(draft.id).status).to eq("draft")
    end

    it "refuses a post already published" do
      published = create(:post, :published)
      call_tool("publish_post", id: published.id)

      expect(message).to eq("blog post #{published.id} is already published")
    end

    it "calls an unknown ID an error" do
      call_tool("publish_post", id: 404)

      expect(message).to eq("no blog post has the ID 404")
    end
  end

  describe "delete_post" do
    it "deletes the post" do
      doomed = create(:post, :published)
      call_tool("delete_post", id: doomed.id)

      expect(stored(doomed.id)).to be_nil
    end

    it "answers with the ID it deleted" do
      doomed = create(:post, :draft)
      call_tool("delete_post", id: doomed.id)

      expect(content).to eq("id" => doomed.id, "deleted" => true)
    end

    it "calls an unknown ID an error" do
      call_tool("delete_post", id: 404)

      expect(message).to eq("no blog post has the ID 404")
    end
  end

  describe "compose_announcement" do
    it "gives the announcement text the post carries" do
      article = create(:post, :draft, syndication_body: "In my own words")
      call_tool("compose_announcement", id: article.id)

      expect(content).to eq("id" => article.id, "announcement" => "In my own words")
    end

    it "gives the title and link when the post carries no text, as the admin does" do
      article = create(:post, :draft, title: "Hello", slug: "hello", syndication_body: "")
      call_tool("compose_announcement", id: article.id)

      expect(content.fetch("announcement"))
        .to eq(Posts::Slice["operations.compose_announcement"].default(title: "Hello", slug: "hello"))
    end

    it "puts the title before the link" do
      article = create(:post, :draft, title: "Hello", slug: "hello", syndication_body: "")
      call_tool("compose_announcement", id: article.id)

      expect(content.fetch("announcement")).to match(%r{\AHello\n\nhttps?://\S+/hello\z})
    end

    it "changes nothing" do
      article = create(:post, :draft, syndication_body: "")
      call_tool("compose_announcement", id: article.id)

      expect(stored(article.id).syndication_body).to eq("")
    end

    it "calls an unknown ID an error" do
      call_tool("compose_announcement", id: 404)

      expect(message).to eq("no blog post has the ID 404")
    end
  end
end

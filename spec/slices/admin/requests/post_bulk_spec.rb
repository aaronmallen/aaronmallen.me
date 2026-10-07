# frozen_string_literal: true

RSpec.describe "Admin bulk post actions", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:post_mutations) { Posts::Slice["repos.post_mutations"] }
  let(:post_queries) { Posts::Slice["repos.post_queries"] }

  def act(name, posts, **params)
    ids = posts.map { it.is_a?(Integer) ? it : it.id }
    post "/admin/posts/bulk", { _csrf_token: admin_csrf_token, act: name, ids:, status: "all", **params }
  end

  def drafts(count) = Array.new(count) { create(:post, :draft) }

  def gone_id = create(:post).id.tap { post_mutations.delete(it) }

  def kept?(article) = !post_queries.by_id(article.id).nil?

  def tag_names(article) = post_queries.by_id(article.id).tags.map(&:name).sort

  def tagged(*names, **attributes) = create(:post, **attributes).tap { post_mutations.replace_tags(it.id, names) }

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the list" do
      before { drafts(2) }

      it "draws one bar that posts to the bulk route", :aggregate_failures do
        get "/admin/posts"

        expect(page).to have_css("form#post-bulk[action='/admin/posts/bulk'][method='post']", count: 1)
        expect(page.all("form#post-bulk button[name='act']").map(&:value)).to eq(%w[tag delete])
      end

      it "puts a hidden tag button first, so Enter in the tag field tags" do
        get "/admin/posts"

        first = page.first("form#post-bulk button[name='act']", visible: :all)

        expect(first).to match_css("[value='tag'][hidden]", visible: :all)
      end

      it "gives each row a box that joins the bar" do
        get "/admin/posts"

        expect(page.all(".li input[type='checkbox'][name='ids[]'][form='post-bulk']").size).to eq(2)
      end

      it "names the post on each box" do
        article = create(:post, title: "Notes on Phlex")
        get "/admin/posts"

        expect(page).to have_css("input[value='#{article.id}'][aria-label='Select Notes on Phlex']")
      end

      it "shows the actions in the markup, so they work with scripts off" do
        get "/admin/posts"

        expect(page).to have_css("[data-bulk-acts]:not([hidden])")
      end

      it "leaves select all for the script to draw" do
        get "/admin/posts"

        expect(page).to have_css("[data-bulk-all][hidden]", visible: :all)
      end

      it "draws a labelled tag field in the bar" do
        get "/admin/posts"

        expect(page).to have_css("form#post-bulk input[name='tag'][aria-label='Tag name']")
      end

      it "asks before deleting" do
        get "/admin/posts"

        expect(page).to have_css("button[value='delete'][data-confirm]")
      end

      it "keeps the filter and the page in the bar", :aggregate_failures do
        lower_page_size(:admin, to: 1)
        get "/admin/posts", status: "draft", page: 2

        expect(page).to have_css("form#post-bulk input[name='status'][value='draft']", visible: :all)
        expect(page).to have_css("form#post-bulk input[name='page'][value='2']", visible: :all)
      end
    end

    describe "an empty list" do
      it "draws no bar" do
        get "/admin/posts", status: "scheduled"

        expect(page).to have_no_css("form#post-bulk")
      end
    end

    describe "delete on the ticked drafts" do
      let!(:ticked) { drafts(2) }
      let!(:left) { create(:post, :draft) }

      before { act("delete", ticked) }

      it "takes them away" do
        expect(ticked.map { kept?(it) }).to eq([false, false])
      end

      it "leaves the rest alone" do
        expect(kept?(left)).to be(true)
      end

      it "says how many went" do
        follow_redirect!

        expect(toast).to eq("Deleted 2 drafts")
      end
    end

    describe "delete with a published post ticked" do
      let!(:ticked) { drafts(2) }
      let!(:published) { create(:post, :published, title: "Out in the world") }

      before { act("delete", [*ticked, published]) }

      it "changes nothing", :aggregate_failures do
        expect(ticked.map { kept?(it) }).to eq([true, true])
        expect(kept?(published)).to be(true)
      end

      it "names the post" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · Out in the world is not a draft")
      end
    end

    describe "delete with a scheduled post ticked" do
      let!(:draft) { create(:post, :draft) }

      before { act("delete", [draft, create(:post, :scheduled, title: "Coming soon")]) }

      it "changes nothing" do
        expect(kept?(draft)).to be(true)
      end

      it "names the post" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · Coming soon is not a draft")
      end
    end

    describe "delete with a post that is gone" do
      let!(:ticked) { drafts(2) }
      let(:missing) { gone_id }

      before { act("delete", [*ticked, missing]) }

      it "changes nothing" do
        expect(ticked.map { kept?(it) }).to eq([true, true])
      end

      it "names the post" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · ##{missing} is gone")
      end
    end

    describe "a batch refused for a reason the bar does not name" do
      let(:draft) { create(:post, :draft, title: "Held") }

      before do
        replace_component(
          "posts.operations.act_on_posts",
          ->(_params) { Dry::Monads::Result::Failure.new([:record, draft.id, :locked]) },
        )
        act("delete", [draft])
      end

      it "names the post in the toast" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · Held would not change")
      end
    end

    describe "a delete that rolls back", :commits do
      let(:photo) { create(:photo) }
      let(:claims) { Media::Slice["relations.photo_claims"] }

      before do
        connect_media_store
        stub_request(:delete, media_store_url(photo.key))
      end

      it "keeps the draft's photos claimed and in the store", :aggregate_failures do
        draft = create(:post, :draft, body: "![A photo](/media/#{photo.key})")
        Media::Slice["repos.photo_mutations"].claim("post", draft.id, [photo.key])
        act("delete", [draft, create(:post, :published)])

        expect(claims.where(owner: "post").to_a.map { [it[:owner_id], it[:photo_id]] }).to eq([[draft.id, photo.id]])
        expect(a_request(:delete, media_store_url(photo.key))).not_to have_been_made
      end
    end

    describe "tag on the ticked posts" do
      let!(:ticked) { [tagged("ruby"), tagged(status: "published", published_at: Time.now - 60)] }
      let!(:left) { tagged("ruby") }

      before { act("tag", ticked, tag: " Hanami ") }

      it "adds the tag and keeps the others" do
        expect(ticked.map { tag_names(it) }).to eq([%w[hanami ruby], %w[hanami]])
      end

      it "leaves the rest alone" do
        expect(tag_names(left)).to eq(%w[ruby])
      end

      it "says how many it tagged" do
        follow_redirect!

        expect(toast).to eq("Tagged 2 posts hanami")
      end
    end

    describe "tag on a published post" do
      it "marks it updated, as a tag change in the editor does" do
        article = tagged(status: "published", published_at: Time.now - 120, updated_at: Time.now - 60)
        act("tag", [article], tag: "hanami")

        expect(post_queries.by_id(article.id).updated_at).to be > article.updated_at
      end
    end

    describe "tag on a post that has it already" do
      let!(:article) { tagged("ruby", updated_at: Time.now - 60) }

      before { act("tag", [article], tag: "ruby") }

      it "keeps one" do
        expect(tag_names(article)).to eq(%w[ruby])
      end

      it "leaves it as it was" do
        expect(post_queries.by_id(article.id).updated_at).to eq(article.updated_at)
      end
    end

    describe "tag with a post that is gone" do
      let!(:article) { tagged("ruby") }
      let(:missing) { gone_id }

      before { act("tag", [article, missing], tag: "hanami") }

      it "changes nothing" do
        expect(tag_names(article)).to eq(%w[ruby])
      end

      it "names the post" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · ##{missing} is gone")
      end
    end

    describe "where it lands" do
      it "goes back to the filter it came from" do
        act("tag", [create(:post)], tag: "ruby", status: "draft")

        expect(last_response.headers["location"]).to eq("/admin/posts?status=draft")
      end

      it "keeps the page while it still has rows" do
        lower_page_size(:admin, to: 1)
        drafts(3)
        act("delete", [post_queries.by_status("draft").last], page: 2)

        expect(last_response.headers["location"]).to eq("/admin/posts?status=all&page=2")
      end

      it "steps back a page when the batch emptied the last one" do
        lower_page_size(:admin, to: 1)
        drafts(2)
        act("delete", [post_queries.by_status("draft").last], page: 2)

        expect(last_response.headers["location"]).to eq("/admin/posts?status=all")
      end

      it "goes back the same way after a failure" do
        act("delete", [gone_id], status: "published")

        expect(last_response.headers["location"]).to eq("/admin/posts?status=published")
      end
    end

    describe "a refused batch" do
      it "asks for a tick when none came" do
        post "/admin/posts/bulk", { _csrf_token: admin_csrf_token, act: "delete" }
        follow_redirect!

        expect(toast).to eq("Tick a post first")
      end

      it "refuses more than 100 posts before it changes any", :aggregate_failures do
        posts = drafts(101)
        act("delete", posts)
        follow_redirect!

        expect(toast).to eq("Tick 100 posts or fewer")
        expect(post_queries.by_status("draft").size).to eq(101)
      end

      it "asks for a tag before a tag change" do
        act("tag", [create(:post)], tag: " ")
        follow_redirect!

        expect(toast).to eq("Type a tag first")
      end

      it "refuses a tag that is not a slug", :aggregate_failures do
        article = create(:post)
        act("tag", [article], tag: "not a tag!")
        follow_redirect!

        expect(toast).to eq("Nothing changed · a tag takes lowercase letters, numbers and dashes")
        expect(tag_names(article)).to be_empty
      end

      it "ignores the tag field on delete" do
        article = create(:post)
        act("delete", [article], tag: "not a tag!")

        expect(kept?(article)).to be(false)
      end

      it "refuses an action off the bar", :aggregate_failures do
        article = create(:post)
        act("publish", [article])
        follow_redirect!

        expect(toast).to eq("Nothing changed · pick an action from the bar")
        expect(post_queries.by_id(article.id).status).to eq("draft")
      end
    end
  end

  describe "signed out" do
    it "changes nothing" do
      article = create(:post)
      post "/admin/posts/bulk", { act: "delete", ids: [article.id] }

      expect(post_queries.by_id(article.id)).not_to be_nil
    end
  end
end

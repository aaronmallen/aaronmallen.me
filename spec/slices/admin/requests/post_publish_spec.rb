# frozen_string_literal: true

RSpec.describe "Admin publishing a post from the list", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Posts::Slice["repos.post_repo"] }

  def publish(id, **params) = post("/admin/posts/#{id}/publish", { _csrf_token: admin_csrf_token, **params })

  def publish_buttons = page.all("form[action$='/publish'] button[data-key='p']")

  def status(article) = repo.by_id(article.id).status

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the list" do
      let!(:draft) { create(:post, :draft, title: "Half done") }

      before do
        create(:post, :scheduled)
        create(:post, :published)
        get "/admin/posts"
      end

      it "draws a publish button on the draft alone" do
        expect(publish_buttons.size).to eq(1)
      end

      it "posts the draft to its publish route" do
        expect(page).to have_css("form[action='/admin/posts/#{draft.id}/publish'][method='post']")
      end

      it "names the draft on the button" do
        expect(page).to have_css("button[aria-label='Publish Half done'][aria-keyshortcuts='p']")
      end

      it "labels the key for the help overlay" do
        expect(page).to have_css("button[data-key='p'][data-key-label='Publish the highlighted draft']")
      end

      it "carries the token and the open filter", :aggregate_failures do
        expect(page).to have_css("form[action$='/publish'] input[name='_csrf_token']", visible: :all)
        expect(page).to have_css("form[action$='/publish'] input[name='status'][value='all']", visible: :all)
      end
    end

    it "carries the page past the first" do
      lower_page_size(:admin, to: 1)
      2.times { create(:post, :draft) }
      get "/admin/posts", status: "draft", page: 2

      expect(page).to have_css("form[action$='/publish'] input[name='page'][value='2']", visible: :all)
    end

    describe "a draft" do
      let!(:draft) { create(:post, :draft, title: "Half done", slug: "half-done") }

      before { publish(draft.id, status: "draft") }

      it "publishes it" do
        expect(status(draft)).to eq("published")
      end

      it "goes back to the list that was open" do
        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/posts?status=draft"))
      end

      it "says it went out" do
        follow_redirect!

        expect(toast).to eq("Published")
      end
    end

    it "queues the announcement as the editor does", :commits do
      connect_social_networks
      draft = create(:post, :draft, slug: "hello", syndication_enabled: true, syndication_targets: %w[mastodon bluesky])
      publish(draft.id)

      Social::Jobs::SyndicatePost.drain

      expect(Social::Slice["repos.social_post_repo"].queued).to contain_exactly(have_attributes(post_id: draft.id))
    end

    describe "a draft with a publish time still to come" do
      let!(:draft) { create(:post, :draft, published_at: Time.now + (24 * 60 * 60)) }

      before { publish(draft.id) }

      it "schedules it" do
        expect(status(draft)).to eq("scheduled")
      end

      it "says when it goes out" do
        follow_redirect!

        expect(toast).to start_with("Scheduled for ")
      end
    end

    describe "a scheduled post" do
      let!(:scheduled) { create(:post, :scheduled) }

      before { publish(scheduled.id) }

      it "publishes it now", :aggregate_failures do
        expect(status(scheduled)).to eq("published")
        expect(repo.by_id(scheduled.id).published_at).to be_within(60).of(Time.now)
      end

      it "says it went out" do
        follow_redirect!

        expect(toast).to eq("Published")
      end
    end

    describe "a published post" do
      let!(:published) { create(:post, :published, title: "Out in the world") }

      before { publish(published.id) }

      it "leaves it as it was" do
        expect(repo.by_id(published.id).published_at).to be_within(1).of(published.published_at)
      end

      it "names the post" do
        follow_redirect!

        expect(toast).to eq("Nothing published · Out in the world is not a draft")
      end
    end

    describe "a draft that fails the editor's checks" do
      let!(:draft) do
        create(:post, :draft, title: "Too loud", syndication_enabled: true, syndication_targets: %w[bluesky],
                              syndication_body: "a" * 301)
      end

      before { publish(draft.id) }

      it "leaves it a draft" do
        expect(status(draft)).to eq("draft")
      end

      it "says to fix it in the editor" do
        follow_redirect!

        expect(toast).to eq("Not published · open Too loud to fix it")
      end
    end

    it "falls back a page when the draft was the last on its page" do
      lower_page_size(:admin, to: 1)
      create(:post, :draft)
      last = create(:post, :draft)
      publish(last.id, status: "draft", page: 2)

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/posts?status=draft"))
    end

    it "answers 404 for a post that isn't there" do
      publish(0)

      expect(last_response.status).to eq(404)
    end

    it "refuses a forged CSRF token", :aggregate_failures do
      draft = create(:post, :draft)
      post "/admin/posts/#{draft.id}/publish", _csrf_token: "forged"

      expect(last_response.status).to eq(403)
      expect(status(draft)).to eq("draft")
    end
  end

  describe "signed out" do
    it "publishes nothing" do
      draft = create(:post, :draft)
      post "/admin/posts/#{draft.id}/publish"

      expect(status(draft)).to eq("draft")
    end
  end
end

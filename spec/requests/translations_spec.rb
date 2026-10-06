# frozen_string_literal: true

RSpec.describe "Translations", type: :request do
  it "renders two of each approved webmention type on an article" do
    target = create(:post, :published, slug: "hello")
    %i[reply mention like repost].each { |type| 2.times { create(:webmention, :approved, type, post: target) } }
    get "/writing/hello"

    expect(last_response).to be_ok
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "renders a post with one view and one visitor in /admin/posts" do
      read_once = { path: "/writing/hello", views: 1, visitors: 1, bounces: 1 }
      create(:post, :published, slug: "hello")
      create(:analytics_rollup_path, **read_once, day: create(:analytics_rollup, day: Blog::TimeZone.today).day)
      get "/admin/posts"

      expect(last_response).to be_ok
    end

    it "renders the private tags tab with no tags" do
      create(:post, :published, tags: %w[ruby])
      get "/admin/tags", scope: "private"

      expect(last_response).to be_ok
    end

    it "renders the project editor's error for a repo that is not one" do
      post "/admin/projects", _csrf_token: admin_csrf_token,
                              project: { name: "sai", repo: "Not a repo", url: "https://example.com/sai" }

      expect(last_response.status).to eq(422)
    end

    it "renders the empty /admin/webmentions for approved" do
      get "/admin/webmentions", status: "approved"

      expect(last_response).to be_ok
    end

    it "renders /admin/analytics with one pending webmention" do
      create(:webmention, :reply, post: create(:post, :published))
      get "/admin/analytics"

      expect(last_response).to be_ok
    end

    it "renders the toast when planning a sprint on a date it cannot read" do
      post "/admin/tasks/sprints", _csrf_token: admin_csrf_token, sprint_on: "soon"
      follow_redirect!

      expect(last_response.body).to include("data-toast")
    end
  end

  describe "the social queue" do
    before do
      connect_social_networks
      sign_in_to_admin
    end

    it "renders the empty /admin/social for posted" do
      get "/admin/social", filter: "posted"

      expect(last_response).to be_ok
    end

    it "renders /admin/social for queued with a post a day out" do
      create(:social_post, :scheduled, posted_at: Time.now + (26 * 60 * 60))
      get "/admin/social", filter: "queued"

      expect(last_response).to be_ok
    end
  end
end

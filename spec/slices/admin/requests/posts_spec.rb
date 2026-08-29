# frozen_string_literal: true

RSpec.describe "Admin posts", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def titles = page.all(".li-title").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the list" do
      before do
        create(:post, :draft, title: "Draft")
        create(:post, :scheduled, title: "Scheduled")
        create(:post, :published, title: "Published")
      end

      it "shows every post" do
        get "/admin/posts"

        expect(titles).to contain_exactly("Draft", "Scheduled", "Published")
      end

      it "shows every post with the all filter" do
        get "/admin/posts", status: "all"

        expect(titles).to contain_exactly("Draft", "Scheduled", "Published")
      end

      { "published" => "Published", "draft" => "Draft", "scheduled" => "Scheduled" }.each do |status, title|
        it "shows only #{status} posts with the #{status} filter" do
          get "/admin/posts", status: status

          expect(titles).to eq([title])
        end

        it "checks the #{status} filter" do
          get "/admin/posts", status: status

          expect(page).to have_css(".seg input[name='status'][value='#{status}'][checked]")
        end
      end

      it "shows every post for a filter it doesn't know" do
        get "/admin/posts", status: "archived"

        expect(titles).to contain_exactly("Draft", "Scheduled", "Published")
      end

      it "checks all without a filter" do
        get "/admin/posts"

        expect(page).to have_css(".seg input[value='all'][checked]")
      end

      it "labels the filters" do
        get "/admin/posts"

        expect(page.all(".seg-option").map(&:text)).to eq(%w[all published drafts scheduled])
      end

      it "submits the filter to the list" do
        get "/admin/posts"

        expect(page).to have_css("form[method='get'][action='/admin/posts'][data-autosubmit] .seg")
      end

      it "links New post to the editor" do
        get "/admin/posts"

        expect(page).to have_css(".page-head-actions a.btn.pri[href='/admin/posts/new']", text: "New post")
      end

      it "links each row to its editor" do
        post = create(:post, title: "Linked")
        get "/admin/posts"

        expect(page).to have_link("Linked", href: "/admin/posts/#{post.id}/edit", class: "li-title")
      end
    end

    it "counts the posts in each status in the sub-line" do
      2.times { create(:post, :published) }
      create(:post, :draft)
      3.times { create(:post, :scheduled) }
      get "/admin/posts"

      expect(page).to have_css(".page-head-sub", exact_text: "2 published · 1 draft · 3 scheduled")
    end

    it "counts the sub-line from every post while filtered" do
      create(:post, :published)
      2.times { create(:post, :draft) }
      get "/admin/posts", status: "published"

      expect(page).to have_css(".page-head-sub", exact_text: "1 published · 2 drafts · 0 scheduled")
    end

    it "shows the path, publish date, word count and views under the title" do
      create(:post, :published, slug: "hello", body: "one two three", published_at: Time.utc(2026, 9, 7, 12))
      get "/admin/posts"

      expect(page).to have_css(".li-sub", exact_text: "/writing/hello · Sep 7, 2026 · 3 words · 0 views")
    end

    describe "with rolled up views" do
      let(:today) { Blog::TimeZone.today }

      before do
        create(:post, :published, slug: "hello", body: "one two three", published_at: Time.utc(2026, 9, 7, 12))
        create(:post, :draft, slug: "unseen", body: "one", updated_at: Time.utc(2026, 9, 1, 12))
        create(:analytics_rollup, day: today)
        create(:analytics_rollup, day: today - 400)
        create(:analytics_rollup_path, day: today, path: "/writing/hello", views: 8, visitors: 5, bounces: 2)
        create(:analytics_rollup_path, day: today - 400, path: "/writing/hello", views: 4, visitors: 3, bounces: 1)
        create(:analytics_rollup_path, day: today, path: "/writing/other", views: 9, visitors: 6, bounces: 2)
        get "/admin/posts"
      end

      it "adds up the rolled up days inside the window, leaving out the day before it" do
        expect(page).to have_css(".li-sub", exact_text: "/writing/hello · Sep 7, 2026 · 3 words · 8 views")
      end

      it "counts no views for a path nothing was rolled up under" do
        expect(page).to have_css(".li-sub", exact_text: "/writing/unseen · Sep 1, 2026 · 1 word · 0 views")
      end
    end

    it "dates a post by its Chicago day" do
      create(:post, :published, slug: "hello", body: "one two three", published_at: Time.utc(2026, 9, 8, 3))
      get "/admin/posts"

      expect(page).to have_css(".li-sub", exact_text: "/writing/hello · Sep 7, 2026 · 3 words · 0 views")
    end

    it "dates a draft by its last edit" do
      create(:post, :draft, slug: "hello", body: "one", updated_at: Time.utc(2026, 9, 1, 12))
      get "/admin/posts"

      expect(page).to have_css(".li-sub", exact_text: "/writing/hello · Sep 1, 2026 · 1 word · 0 views")
    end

    it "shows the tags as pills, each in the colour its tag carries" do
      create(:tag, name: "ruby", color: "mk-green")
      create(:tag, name: "hanami", color: "mk-sand")
      create(:post, tags: %w[ruby hanami])
      get "/admin/posts"

      expect(page.all(".li-side .pill.sand, .li-side .pill.green").map(&:text)).to eq(%w[hanami ruby])
    end

    it "counts the mentions a post received in a pill" do
      post = create(:post)
      create(:webmention, post: post)
      create(:webmention, :spam, post: post)
      get "/admin/posts"

      expect(page).to have_css(".li-side .pill.pink span[aria-hidden='true']", exact_text: "@2")
    end

    it "names the mention count for a screen reader" do
      post = create(:post)
      create(:webmention, post: post)
      get "/admin/posts"

      expect(page).to have_css(".li-side .pill.pink .sr-only", exact_text: "1 webmention")
    end

    it "shows no mention pill on a post without mentions" do
      create(:post)
      get "/admin/posts"

      expect(page).to have_no_css(".pill.pink")
    end

    { draft: "orange", scheduled: "blue", published: "green" }.each do |status, color|
      it "shows the #{status} status pill" do
        create(:post, status)
        get "/admin/posts"

        expect(page).to have_css(".li-side .pill.#{color}:last-child", text: status.to_s)
      end
    end

    it "shows an empty state without posts" do
      get "/admin/posts"

      expect(page).to have_css(".empty", text: "No posts")
    end

    it "says posts is where you are" do
      get "/admin/posts"

      expect(page).to have_css(".ctx-where", text: %r{Publish\s+/\s+posts})
    end
  end

  it "redirects to sign-in when signed out" do
    get "/admin/posts"

    expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
  end
end

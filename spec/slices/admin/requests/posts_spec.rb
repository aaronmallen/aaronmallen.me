# frozen_string_literal: true

RSpec.describe "Admin posts", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }

  def dated(day) = day.strftime("%b %-d, %Y")

  def sub_line(head, views: 0, visitors: 0, readers: "0 unique readers", read_throughs: 0)
    [head, "#{views} views", "#{visitors} visitors", readers, "#{read_throughs} read-throughs"].join(" · ")
  end

  def titles = page.all(".li-title").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "paging" do
      before do
        lower_page_size(:admin, to: 2)
        %w[First Second Third].each_with_index do |title, index|
          create(:post, :published, title:, slug: title.downcase, published_at: Time.utc(2026, 9, 1 + index, 12))
        end
        create(:post, :draft, title: "Draft")
      end

      it "shows the newest page and links to older posts", :aggregate_failures do
        get "/admin/posts", status: "published"

        expect(titles).to eq(%w[Third Second])
        expect(page).to have_css("nav.pager a[rel='next'][href='/admin/posts?status=published&page=2']", text: "Older")
        expect(page).to have_no_css("nav.pager a[rel='prev']")
      end

      it "keeps the filter on a later page", :aggregate_failures do
        get "/admin/posts", status: "published", page: "2"

        expect(titles).to eq(%w[First])
        expect(page).to have_css("nav.pager a[rel='prev'][href='/admin/posts?status=published']", text: "Newer")
        expect(page).to have_css(".seg input[value='published'][checked]")
      end

      it "counts the sub-line from every post, not the page" do
        get "/admin/posts", status: "published"

        expect(page).to have_css(".page-head-sub", exact_text: "3 published · 1 draft · 0 scheduled")
      end

      it "counts the views, visitors and words of a post on a later page" do
        day = Blog::TimeZone.today
        create(:analytics_rollup, day:)
        create(:analytics_rollup_path, day:, path: "/writing/first", views: 4, visitors: 3, bounces: 1)
        get "/admin/posts", status: "published", page: "2"

        expect(page).to have_css(".li-sub", text: /· 4 views · 3 visitors · 0 unique readers · 0 read-throughs\z/)
      end

      it "draws no pager when one page holds every post" do
        get "/admin/posts", status: "draft"

        expect(page).to have_no_css("nav.pager")
      end

      it "returns 404 for a page past the end" do
        get "/admin/posts", status: "published", page: "3"

        expect(last_response).to be_not_found
      end

      it "returns 404 for a page that is no page" do
        get "/admin/posts", page: "two"

        expect(last_response).to be_not_found
      end
    end

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

    it "shows the path, publish date, word count, views and visitors under the title" do
      create(:post, :published, slug: "hello", body: "one two three", published_at: days_ago(27))
      get "/admin/posts"

      expect(page).to have_css(".li-sub", exact_text: sub_line("/writing/hello · #{dated(today - 27)} · 3 words"))
    end

    describe "with rolled up views" do
      let(:head) { "/writing/hello · #{dated(today - 27)} · 3 words" }

      before do
        create(:post, :published, slug: "hello", body: "one two three", published_at: days_ago(27))
        create(:post, :draft, slug: "unseen", body: "one", updated_at: Time.utc(2026, 9, 1, 12))
        create(:analytics_rollup, day: today)
        create(:analytics_rollup, day: today - 400)
        create(
          :analytics_rollup_path, day: today, path: "/writing/hello", views: 8, visitors: 5, bounces: 2,
                                  read_throughs: 4,
        )
        create(
          :analytics_rollup_path,
          day: today - 400, path: "/writing/hello", views: 4, visitors: 3, bounces: 1, read_throughs: 2,
        )
        create(:analytics_rollup_path, day: today, path: "/writing/other", views: 9, visitors: 6, bounces: 2)
        get "/admin/posts"
      end

      it "adds up the daily visitors on each day inside the window" do
        create(:analytics_rollup, day: today - 89)
        create(:analytics_rollup_path, day: today - 89, path: "/writing/hello", views: 3, visitors: 2, bounces: 0)
        get "/admin/posts"

        sub = sub_line(head, views: 11, visitors: 7, read_throughs: 4)
        expect(page).to have_css(".li-sub", exact_text: sub)
      end

      it "adds up the rolled up days inside the window, leaving out the day before it" do
        sub = sub_line(head, views: 8, visitors: 5, read_throughs: 4)
        expect(page).to have_css(".li-sub", exact_text: sub)
      end

      it "counts no views or visitors for a path nothing was rolled up under" do
        expect(page).to have_css(".li-sub", exact_text: sub_line("/writing/unseen · Sep 1, 2026 · 1 word"))
      end
    end

    describe "with today's views not rolled up yet" do
      let!(:post) do
        create(:post, :published, slug: "hello", published_at: Blog::TimeZone.day_start(today - 1) + 43_200)
      end

      def figures = page.find(".li-sub", text: "/writing/hello ").text.split(" · ").values_at(3, 4, 6)

      def read(reader, at: Time.now)
        create(
          :analytics_event,
          path: "/writing/hello", visitor_hash: Digest::SHA256.hexdigest(reader), scroll_depth: 75, read_seconds: 30,
          occurred_at: at,
        )
      end

      def roll_up_yesterday
        create(:analytics_rollup, day: today - 1)
        create(
          :analytics_rollup_path,
          day: today - 1, path: "/writing/hello", views: 4, visitors: 3, bounces: 1, read_throughs: 1,
        )
      end

      before do
        roll_up_yesterday
        %w[one one two].each { read(it) }
      end

      it "adds today's views, visitors and read-throughs to the rolled up days" do
        get "/admin/posts"

        expect(figures).to eq(["7 views", "5 visitors", "3 read-throughs"])
      end

      it "counts a rolled up day once, leaving out its raw events" do
        read("three", at: Blog::TimeZone.day_start(today - 1) + 60)
        get "/admin/posts"

        expect(figures).to eq(["7 views", "5 visitors", "3 read-throughs"])
      end

      it "agrees with the activity list" do
        get "/admin/activity"

        expect(page).to have_css(".activity-event-sub", exact_text: "/writing/hello · published · 7 views")
      end

      it "agrees with the post's analytics page" do
        get "/admin/posts/#{post.id}/analytics", range: "7"

        expect(page.find(".stat", text: "Page views")).to have_css(".stat-value", exact_text: "7")
      end
    end

    describe "unique readers" do
      def post(slug, published_at) = create(:post, :published, slug:, body: "one", published_at:)

      def readership(slug) = page.find(".li-sub", text: "/writing/#{slug} ").text.split(" · ")[5]

      it "counts the readers of a post in its first 12 months" do
        post("hello", days_ago(27))
        2.times { create(:post_reader_hash, path: "/writing/hello") }
        get "/admin/posts"

        expect(readership("hello")).to eq("2 unique readers")
      end

      it "marks a saved count as final" do
        post("old", days_ago(400))
        create(:post_reader_count, path: "/writing/old", readers: 1)
        get "/admin/posts"

        expect(readership("old")).to eq("1 unique reader, final")
      end

      it "says a post older than 12 months with no saved count has none" do
        post("old", days_ago(400))
        get "/admin/posts"

        expect(readership("old")).to eq("no unique reader count")
      end
    end

    it "links each post to its analytics page" do
      post = create(:post, :published, title: "Hello")
      get "/admin/posts"

      expect(page).to have_css("a[href='/admin/posts/#{post.id}/analytics'][aria-label='Analytics for Hello']")
    end

    it "dates a post by its Chicago day" do
      late = Blog::TimeZone.day_start(today - 27) + (22 * 3_600)
      create(:post, :published, slug: "hello", body: "one two three", published_at: late)
      get "/admin/posts"

      expect(page).to have_css(".li-sub", exact_text: sub_line("/writing/hello · #{dated(today - 27)} · 3 words"))
    end

    it "dates a draft by its last edit" do
      create(:post, :draft, slug: "hello", body: "one", updated_at: Time.utc(2026, 9, 1, 12))
      get "/admin/posts"

      expect(page).to have_css(".li-sub", exact_text: sub_line("/writing/hello · Sep 1, 2026 · 1 word"))
    end

    describe "tags" do
      before do
        create(:tag, name: "ruby", color: "mk-green")
        create(:tag, name: "hanami", color: "mk-sand")
        create(:post, tags: %w[ruby hanami])
        get "/admin/posts"
      end

      it "shows each tag in the colour it carries" do
        expect(page.all(".li-side .post-tag.sand, .li-side .post-tag.green").map(&:text)).to eq(%w[hanami ruby])
      end

      it "links each tag to its public page" do
        expect(page.all(".li-side a.post-tag").map { it[:href] }).to eq(%w[/writing/tags/hanami /writing/tags/ruby])
      end

      it "draws no tag as a pill" do
        expect(page).to have_no_css(".li-side .pill.green, .li-side .pill.sand")
      end
    end

    it "counts the mentions a post received in a pill" do
      post = create(:post)
      create(:webmention, post: post)
      create(:webmention, :spam, post: post)
      get "/admin/posts"

      expect(page).to have_css(".li-side .pill.pink span[aria-hidden='true']", exact_text: "@2")
    end

    it "counts an ignored mention as received" do
      post = create(:post)
      create(:webmention, :approved, post: post)
      create(:webmention, :ignored, post: post)
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

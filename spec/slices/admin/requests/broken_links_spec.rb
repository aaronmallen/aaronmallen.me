# frozen_string_literal: true

RSpec.describe "Admin broken links", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def at = Time.utc(2026, 10, 12, 8, 12)

  def checks = Posts::Slice["relations.post_link_checks"]

  def dead = "https://bob.example/gone"

  def fail_nights(post, url, nights)
    nights.times { checks.record(post_id: post.id, url:, reason: "404 Not Found", at: at + (it * 86_400)) }
  end

  def fail_short(link, nights, reason = "503 Service Unavailable")
    nights.times do |night|
      short_checks.record(short_link_id: link.id, url: link.destination, reason:, at: at + (night * 86_400))
    end
  end

  def finish_run(checked:, due:, finished_at: at + 86_400)
    runs.insert(started_at: finished_at - 600, finished_at:, links_checked: checked, links_due: due)
  end

  def live = "https://ada.example/notes/1"

  def post_row(title) = page.find(".post-list .li", text: title)

  def post_with(*urls, status: :published, title: "Linked")
    create(:post, status, title:, body: ["intro", *urls.map { "See [note #{it}](#{it})." }].join("\n\n"))
  end

  def queue_down = Admin::Slice["i18n"].t("queue_unavailable")

  def runs = Posts::Slice["relations.link_check_runs"]

  def short_checks = Shares::Slice["relations.short_link_checks"]

  def short_link(destination) = Shares::Slice["operations.create_short_link"].call(destination:).value!

  def slow = "https://cy.example/slow"

  def toast_after_redirect
    follow_redirect!
    page.find("[data-toast] .toast", visible: :all).text(:all)
  end

  before { sign_in_to_admin }

  describe "the filter" do
    it "counts broken links in posts and short links" do
      fail_nights(post_with(dead, slow), dead, 1)
      fail_short(short_link(slow), 1)
      get "/admin/posts"

      expect(page).to have_css(".seg-option", exact_text: "broken · 2")
    end

    it "lists only published posts with a failing link", :aggregate_failures do
      fail_nights(post_with(dead, title: "Broken"), dead, 1)
      checks.record(post_id: post_with(live, title: "Fine").id, url: live, reason: nil, at:)
      get "/admin/posts", status: "broken"

      expect(page).to have_css(".post-list .li-title", text: "Broken")
      expect(page).to have_no_css(".post-list .li-title", text: "Fine")
    end

    it "checks the broken links filter" do
      get "/admin/posts", status: "broken"

      expect(page).to have_css(".seg input[name='status'][value='broken'][checked]")
    end
  end

  describe "the header line" do
    context "with broken links" do
      before do
        fail_nights(post_with(dead, slow), dead, 1)
        fail_nights(post_with(slow, title: "Other"), slow, 2)
        fail_short(short_link(slow), 1)
        finish_run(checked: 3, due: 3)
        get "/admin/posts", status: "broken"
      end

      it "counts the links, the posts and the short links" do
        expect(page).to have_css(".page-head-sub", text: "3 broken links: 2 in 2 posts and 1 short link.")
      end

      it "says when the last check finished" do
        expect(page).to have_css(".page-head-sub", text: "The last check finished Oct 13 · 03:12")
      end
    end

    it "takes the finish time from the latest run, not the latest check" do
      fail_nights(post_with(dead), dead, 3)
      finish_run(checked: 1, due: 1, finished_at: at)
      get "/admin/posts", status: "broken"

      expect(page).to have_css(".page-head-sub", text: "The last check finished Oct 12 · 03:12")
    end

    it "leaves the finish time out while the latest run is still going" do
      fail_nights(post_with(dead), dead, 1)
      finish_run(checked: 1, due: 1, finished_at: at)
      runs.insert(started_at: at + 60, links_due: 1)
      get "/admin/posts", status: "broken"

      expect(page).to have_no_css(".page-head-sub", text: "finished")
    end

    it "says nothing is broken" do
      checks.record(post_id: post_with(live).id, url: live, reason: nil, at:)
      get "/admin/posts", status: "broken"

      expect(page).to have_css(".page-head-sub", text: "Every link answered the last check")
    end

    it "keeps the drafts line on the other filters" do
      fail_nights(post_with(dead), dead, 1)
      get "/admin/posts"

      expect(page).to have_css(".page-head-sub", text: "0 drafts in progress.")
    end
  end

  describe "a post's failing links" do
    let(:post) { post_with(live, dead, slow) }
    let(:rows) { page.all(".post-broken-links .li") }

    before do
      fail_nights(post, slow, 1)
      fail_nights(post, dead, 3)
      checks.record(post_id: post.id, url: live, reason: nil, at:)
      get "/admin/posts", status: "broken"
    end

    it "lists the failing links, longest failing first" do
      expect(rows.map { it.first(".li-sub").text }).to eq([dead, slow])
    end

    it "gives each link its reason, last checked and first failed", :aggregate_failures do
      expect(rows.first).to have_css(".pill.pink", text: "failing 3 nights")
      expect(rows.first).to have_css(".post-link-reason", text: "404 Not Found")
      expect(rows.first).to have_text("first failed Oct 12, 2026")
      expect(rows.first).to have_css("time")
    end

    it "offers Check again, Fix in post and Open link", :aggregate_failures do
      expect(rows.first).to have_css(
        "button[form='broken-links-check'][formaction='/admin/posts/#{post.id}/links/check'][value='#{dead}']",
      )
      expect(rows.first).to have_css("a[href='/admin/posts/#{post.id}/edit?links=1'][title='Fix in post: #{dead}']")
      expect(rows.first).to have_css("a[href='#{dead}'][target='_blank']")
    end

    it "sends Check again back to the list" do
      expect(page).to have_css(
        "form#broken-links-check input[name='return_to'][value='/admin/posts?status=broken']", visible: :all,
      )
    end

    it "reloads when a check lands" do
      tables = "[data-live-tables~='post_link_checks'][data-live-tables~='short_link_checks']"

      expect(page).to have_css(tables, visible: :all)
    end
  end

  describe "the failing tag" do
    it "tags a post failing one night in orange" do
      fail_nights(post_with(dead, title: "Once"), dead, 1)
      get "/admin/posts"

      expect(post_row("Once")).to have_css(".post-row-meta .pill.orange", text: "1 link failing")
    end

    it "tags a post failing two nights or more in pink" do
      post = post_with(dead, slow, title: "Twice")
      fail_nights(post, dead, 2)
      fail_nights(post, slow, 1)
      get "/admin/posts"

      expect(post_row("Twice")).to have_css(".post-row-meta .pill.pink", text: "2 links failing")
    end

    it "leaves a post with fine links untagged" do
      checks.record(post_id: post_with(live, title: "Fine").id, url: live, reason: nil, at:)
      get "/admin/posts"

      expect(post_row("Fine")).to have_no_css(".pill", text: "failing")
    end
  end

  describe "the short links card" do
    let(:link) { short_link(slow) }
    let(:card) { page.find(".post-broken-short") }

    before do
      short_link(live)
      fail_short(link, 1)
      get "/admin/posts", status: "broken"
    end

    it "counts the failing short links" do
      expect(card).to have_css(".card-side", text: "1 of 2 failing")
    end

    it "lists the failing destination with its reason", :aggregate_failures do
      expect(card).to have_css(".li-sub", exact_text: slow)
      expect(card).to have_css(".pill.orange", text: "failing")
      expect(card).to have_css(".post-link-reason", text: "503 Service Unavailable")
    end

    it "offers Check again, Change destination and Open link", :aggregate_failures do
      expect(card).to have_css("button[form='broken-links-check'][formaction='/admin/links/#{link.id}/check']")
      expect(card).to have_css("a[href='/admin/links/#{link.id}/edit'][title='Change destination: #{slow}']")
      expect(card).to have_css("a[href='#{slow}'][target='_blank']")
    end

    it "skips a failure checked against a link's old destination", :aggregate_failures do
      moved = short_link(dead)
      short_checks.record(short_link_id: moved.id, url: "https://old.example/", reason: "404 Not Found", at:)
      get "/admin/posts", status: "broken"

      expect(card).to have_css(".card-side", text: "1 of 3 failing")
      expect(card).to have_no_css(".li-sub", exact_text: dead)
    end
  end

  describe "checking again" do
    let(:back) { "/admin/posts?status=broken" }

    it "queues a post link and comes back to the list", :aggregate_failures do
      post = post_with(dead)
      post "/admin/posts/#{post.id}/links/check", _csrf_token: admin_csrf_token, url: dead, return_to: back

      expect(Posts::Jobs::CheckPostLinksAgain.jobs.map { it["args"] }).to eq([[post.id, dead]])
      expect(last_response.location).to end_with(back)
    end

    it "queues a short link and comes back to the list", :aggregate_failures do
      link = short_link(slow)
      post "/admin/links/#{link.id}/check", _csrf_token: admin_csrf_token, return_to: back

      expect(Shares::Jobs::CheckShortLinkAgain.jobs.map { it["args"] }).to eq([[link.id]])
      expect(last_response.location).to end_with(back)
    end

    it "says so once it lands" do
      post "/admin/links/#{short_link(slow).id}/check", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(page.find("[data-toast] .toast", visible: :all).text(:all)).to eq("Checking that link")
    end

    it "says so when the queue is down for a post link" do
      allow(Posts::Jobs::CheckPostLinksAgain).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
      post "/admin/posts/#{post_with(dead).id}/links/check", _csrf_token: admin_csrf_token, url: dead, return_to: back

      expect(toast_after_redirect).to eq(queue_down)
    end

    it "says so when the queue is down for a short link" do
      link = short_link(slow)
      allow(Shares::Jobs::CheckShortLinkAgain).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
      post "/admin/links/#{link.id}/check", _csrf_token: admin_csrf_token, return_to: back

      expect(toast_after_redirect).to eq(queue_down)
    end

    it "finds no short link that is gone" do
      post "/admin/links/0/check", _csrf_token: admin_csrf_token

      expect(last_response.status).to eq(404)
    end
  end

  describe "the stopped early banner" do
    def banner = page.find(".link-check-banner")

    def stopped = t("ui.components.link_check_banner.stopped", at: "Oct 13 · 03:12", checked: 290, due: 473)

    def t(...) = Admin::Slice["i18n"].t(...)

    context "when the last run stopped early" do
      before { finish_run(checked: 290, due: 473) }

      it "says how far it got on Posts, with Run it now", :aggregate_failures do
        get "/admin/posts", status: "broken"

        expect(banner).to have_text(stopped)
        expect(banner).to have_button("Run it now")
      end

      it "says how far it got on Today" do
        get "/admin"

        expect(banner).to have_text(stopped)
      end
    end

    it "keeps to the broken links filter on Posts" do
      finish_run(checked: 290, due: 473)
      get "/admin/posts"

      expect(page).to have_no_css(".link-check-banner")
    end

    it "stays away after a run that checked every link" do
      finish_run(checked: 290, due: 473, finished_at: at)
      finish_run(checked: 473, due: 473)
      get "/admin/posts", status: "broken"

      expect(page).to have_no_css(".link-check-banner")
    end

    it "stays away while a run is still going" do
      finish_run(checked: 290, due: 473, finished_at: at)
      runs.insert(started_at: at + 60, links_due: 473)
      get "/admin"

      expect(page).to have_no_css(".link-check-banner")
    end

    it "comes back to the page it was on" do
      finish_run(checked: 290, due: 473)
      get "/admin/posts", status: "broken"

      expect(banner.find("input[name=return_to]", visible: :all).value).to eq("/admin/posts?status=broken")
    end
  end

  describe "running it now" do
    let(:back) { "/admin/posts?status=broken" }

    it "starts a new run and comes back", :aggregate_failures do
      post "/admin/posts/links/check", _csrf_token: admin_csrf_token, return_to: back

      expect(Posts::Jobs::CheckPostLinks.jobs.size).to eq(1)
      expect(last_response.location).to end_with(back)
    end

    it "says so when the queue is down" do
      allow(Posts::Jobs::CheckPostLinks).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
      post "/admin/posts/links/check", _csrf_token: admin_csrf_token, return_to: back

      expect(toast_after_redirect).to eq(queue_down)
    end

    it "records the new run once the job runs", :aggregate_failures do
      post_with(live)
      stub_request(:get, live).to_return(status: 200)
      post "/admin/posts/links/check", _csrf_token: admin_csrf_token
      Posts::Jobs::CheckPostLinks.drain

      expect(runs.to_a.map { it[:links_checked] }).to eq([1])
    end

    it "says so once it lands" do
      post "/admin/posts/links/check", _csrf_token: admin_csrf_token, return_to: back
      follow_redirect!

      expect(page.find("[data-toast] .toast", visible: :all).text(:all)).to eq("Checking every link")
    end
  end
end

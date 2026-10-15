# frozen_string_literal: true

RSpec.describe "Admin post links drawer", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:drawer) { page.find("dialog#post-links", visible: :all) }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def at = Time.utc(2026, 10, 12, 8)

  def check(post, url = nil)
    post "/admin/posts/#{post.id}/links/check", { _csrf_token: admin_csrf_token, url: }.compact
  end

  def checks = Posts::Slice["relations.post_link_checks"]

  def dead = "https://bob.example/gone"

  def fail_nights(post, url, nights)
    nights.times { checks.record(post_id: post.id, url:, reason: "404 Not Found", at: at + (it * 86_400)) }
  end

  def fresh = "https://dee.example/new"

  def live = "https://ada.example/notes/1"

  def post_with(*urls, status: :published)
    create(:post, status, body: ["intro", *urls.map { "See [note #{it}](#{it})." }].join("\n\n"))
  end

  def row(url) = rows.find { it.has_css?(".li-sub", text: url, visible: :all) }

  def rows = drawer.all(".li", visible: :all)

  def slow = "https://cy.example/slow"

  before { sign_in_to_admin }

  describe "a published post" do
    let(:subject_post) { post_with(live, slow, dead, fresh) }

    before do
      fail_nights(subject_post, dead, 3)
      fail_nights(subject_post, slow, 1)
      checks.record(post_id: subject_post.id, url: live, reason: nil, at:)
      get "/admin/posts/#{subject_post.id}/edit"
    end

    it "counts the failing links on the Links button" do
      expect(page).to have_css("button[data-dialog-open='post-links'] .post-links-count", text: "2 failing")
    end

    it "sums up the links", :aggregate_failures do
      expect(drawer).to have_css(".post-links-sum", text: "4 links", visible: :all)
      expect(drawer).to have_css(".post-links-sum", text: "2 failing", visible: :all)
      expect(drawer).to have_css(".post-links-sum", text: "1 not checked yet", visible: :all)
    end

    it "lists failing links first, longest failing on top, then links not checked yet" do
      urls = rows.first(3).map { it.first(".li-sub", visible: :all).text(:all) }

      expect(urls).to eq([dead, slow, fresh])
    end

    it "shows a link failing for nights in pink with its count", :aggregate_failures do
      expect(row(dead)).to have_css(".pill.pink", text: "failing 3 nights", visible: :all)
      expect(row(dead)).to have_css(".post-link-reason", text: "404 Not Found", visible: :all)
      expect(row(dead)).to have_text(:all, "first failed Oct 12, 2026")
    end

    it "shows a link failing one night in orange" do
      expect(row(slow)).to have_css(".pill.orange", text: "failing", visible: :all)
    end

    it "shows a new link as not checked yet", :aggregate_failures do
      expect(row(fresh)).to have_css(".pill", text: "not checked yet", visible: :all)
      expect(row(fresh)).to have_text(:all, "added since the last check")
    end

    it "folds the fine links under a count" do
      expect(drawer).to have_css("details.post-links-fine summary", text: "1 fine", visible: :all)
    end

    it "offers Find in post, Check again and Open link on a row", :aggregate_failures do
      expect(row(dead)).to have_css("[data-find-link='#{dead}']", visible: :all)
      expect(row(dead)).to have_css("button[form='post-links-check'][name='url'][value='#{dead}']", visible: :all)
      expect(row(dead)).to have_css("a[href='#{dead}'][target='_blank']", visible: :all)
    end

    it "checks every link again from the foot" do
      expect(drawer).to have_css(".dialog-foot button[form='post-links-check']:not([name])", visible: :all)
    end

    it "reloads with the drawer when a check lands" do
      expect(page).to have_css("[data-live-tables~='post_link_checks']", visible: :all)
    end
  end

  describe "a draft" do
    before do
      draft = post_with(dead, status: :draft)
      get "/admin/posts/#{draft.id}/edit"
    end

    it "shows its links as not checked yet until the post goes live", :aggregate_failures do
      expect(row(dead)).to have_css(".pill", text: "not checked yet", visible: :all)
      expect(row(dead)).to have_text(:all, "checked once the post is live")
      expect(drawer).to have_text(:all, "Drafts are not checked overnight")
    end

    it "offers no check" do
      expect(drawer).to have_no_css("button[form='post-links-check']", visible: :all)
    end
  end

  it "says when a post links nowhere" do
    get "/admin/posts/#{post_with.id}/edit"

    expect(drawer).to have_css(".post-links-sum", text: "No links", visible: :all)
  end

  describe "checking again" do
    let(:jobs) { Posts::Jobs::CheckPostLinksAgain.jobs.map { it["args"] } }

    it "queues a check of every link and opens the drawer", :aggregate_failures do
      published = post_with(dead)
      check(published)

      expect(jobs).to eq([[published.id]])
      expect(last_response.location).to end_with("/admin/posts/#{published.id}/edit?links=1")
    end

    it "queues a check of one link" do
      published = post_with(dead, live)
      check(published, dead)

      expect(jobs).to eq([[published.id, dead]])
    end

    it "says so once it lands" do
      check(post_with(dead), dead)
      follow_redirect!

      expect(toast).to eq("Checking that link")
    end

    it "opens the drawer when it lands" do
      check(post_with(dead))
      follow_redirect!

      expect(drawer["data-dialog-show"]).not_to be_nil
    end

    it "queues nothing for a draft", :aggregate_failures do
      check(post_with(dead, status: :draft))
      follow_redirect!

      expect(jobs).to be_empty
      expect(toast).to eq("Not checked · links get checked once the post is live")
    end
  end
end

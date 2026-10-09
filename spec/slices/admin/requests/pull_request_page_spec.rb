# frozen_string_literal: true

RSpec.describe "Admin pull request page", :frozen_clock, type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:ready_at) { Blog::TimeZone.local_time(2026, 10, 1, 14, 30) }
  let(:ended_at) { Blog::TimeZone.local_time(2026, 10, 3, 9, 5) }

  def pull_request(**) = create(:pull_request, ready_at:, **)

  def stats = page.all(".stat").map { [it.find(".stat-key").text, it.find(".stat-value").text] }

  def visit_pull_request(record) = get("/admin/pull-requests/#{record.id}")

  describe "signed out" do
    let(:record) { pull_request(repo: "employer/payroll", body: "for the March run") }

    it "redirects to sign-in" do
      visit_pull_request(record)

      expect(last_response.location).to end_with("/admin/sign-in")
    end

    it "sends neither the repo nor the description", :aggregate_failures do
      visit_pull_request(record)

      expect(last_response.body).not_to include("employer/payroll")
      expect(last_response.body).not_to include("for the March run")
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers 404 for a pull request that isn't there" do
      get "/admin/pull-requests/999999"

      expect(last_response.status).to eq(404)
    end

    it "heads the page with the title, the number and the repo", :aggregate_failures do
      visit_pull_request(pull_request(repo: "someone/gem", number: 42, title: "Fix the parser"))

      expect(page).to have_css(".page-head h1", text: "Fix the parser")
      expect(page).to have_css(".page-head-kicker", exact_text: "Pull request #42")
      expect(page).to have_css(".page-head-sub", text: "someone/gem")
    end

    it "renders the description as Markdown" do
      visit_pull_request(pull_request(body: "first para\n\n- one\n- two"))

      expect(page.all(".commit-body li").map(&:text)).to eq(%w[one two])
    end

    it "says so when there is no description" do
      visit_pull_request(pull_request(body: ""))

      expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.pull_requests.show.no_body"))
    end

    it "shows an open pull request with its opened time" do
      visit_pull_request(pull_request)

      expect(stats).to eq([%w[State Open], ["Opened", "Oct 1, 2026, 14:30"]])
    end

    it "shows a merged pull request with its merged time" do
      visit_pull_request(pull_request(merged_at: ended_at))

      expect(stats).to eq([%w[State Merged], ["Opened", "Oct 1, 2026, 14:30"], ["Merged", "Oct 3, 2026, 09:05"]])
    end

    it "shows a closed pull request with its closed time" do
      visit_pull_request(pull_request(closed_at: ended_at))

      expect(stats).to eq([%w[State Closed], ["Opened", "Oct 1, 2026, 14:30"], ["Closed", "Oct 3, 2026, 09:05"]])
    end

    it "shows a draft with no times" do
      visit_pull_request(pull_request(ready_at: nil))

      expect(stats).to eq([%w[State Draft]])
    end

    it "links the pull request on GitHub" do
      visit_pull_request(pull_request(url: "https://github.com/someone/gem/pull/42"))

      expect(page).to have_link(href: "https://github.com/someone/gem/pull/42")
    end

    it "links back to the activity" do
      visit_pull_request(pull_request)

      expect(page).to have_link("Activity", href: "/admin/activity")
    end
  end
end

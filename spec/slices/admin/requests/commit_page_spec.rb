# frozen_string_literal: true

RSpec.describe "Admin commit page", :frozen_clock, type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }

  def bodies(selector) = page.all(".commit-body #{selector}").map(&:text)

  def commit_record(**) = create(:commit, commit_date: today, commit_time: "14:30", **)

  def stats = page.all(".stat").map { [it.find(".stat-key").text, it.find(".stat-value").text] }

  def visit_commit(record) = get("/admin/commits/#{record.id}")

  describe "signed out" do
    let(:record) { commit_record(repo: "employer/payroll", message: "fix the rate table\n\nfor the March run") }

    it "redirects to sign-in" do
      visit_commit(record)

      expect(last_response.location).to end_with("/admin/sign-in")
    end

    it "sends neither the repo nor the message", :aggregate_failures do
      visit_commit(record)

      expect(last_response.body).not_to include("employer/payroll")
      expect(last_response.body).not_to include("for the March run")
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers 404 for a commit that isn't there" do
      get "/admin/commits/999999"

      expect(last_response.status).to eq(404)
    end

    it "heads the page with the subject" do
      visit_commit(commit_record(message: "admin: add the view\n\nand say why"))

      expect(page).to have_css(".page-head h1", text: "admin: add the view")
    end

    it "shows the repo and the branch with the date and the time" do
      visit_commit(commit_record(repo: "aaronmallen/sai", branch: "spike"))
      stamp = "aaronmallen/sai · spike · #{today.strftime('%b %-d, %Y')} at 14:30"

      expect(page).to have_css(".page-head-sub", text: stamp)
    end

    it "shows the short sha and the line counts" do
      visit_commit(commit_record(sha: "abc1234#{'0' * 33}", additions: 12, deletions: 3))

      expect(stats).to eq([["Added", "+12"], ["Removed", "−3"], ["Commit", "abc1234"]])
    end

    it "shows the body, not just the first line" do
      visit_commit(commit_record(message: "admin: add the view\n\nand here is why it matters"))

      expect(page).to have_css(".commit-body", text: "and here is why it matters")
    end

    it "keeps two paragraphs apart rather than flattening them" do
      visit_commit(commit_record(message: "subject\n\nfirst para\n\nsecond para"))

      expect(bodies("p")).to eq(["first para", "second para"])
    end

    it "renders a list in the body as a list" do
      visit_commit(commit_record(message: "subject\n\n- one\n- two"))

      expect(bodies("li")).to eq(%w[one two])
    end

    it "turns a remote image in the body into a link to it", :aggregate_failures do
      visit_commit(commit_record(message: "subject\n\n![shot](https://example.com/shot.png)"))

      expect(page.find(".commit-body")).to have_link("shot", href: "https://example.com/shot.png")
      expect(page).to have_no_css(".commit-body img")
    end

    it "keeps an image from the site's own /media path in the body" do
      visit_commit(commit_record(message: "subject\n\n![shot](/media/#{'a' * 32}.png)"))

      expect(page).to have_css(".commit-body img[src='/media/#{'a' * 32}.png'][alt='shot']")
    end

    it "says so when the subject is the whole message" do
      visit_commit(commit_record(message: "admin: add the view"))

      expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.commits.show.no_body"))
    end

    it "names the short sha above the subject" do
      visit_commit(commit_record(sha: "abc1234#{'0' * 33}"))

      expect(page).to have_css(".page-head-kicker", exact_text: "Commit abc1234")
    end

    it "links back to the activity" do
      visit_commit(commit_record)

      expect(page).to have_link("Activity", href: "/admin/activity")
    end

    it "puts the linked records beside the message" do
      visit_commit(commit_record)

      expect(page).to have_css(".g-main > .card + aside > .record-links")
    end

    it "links the commit on GitHub" do
      record = commit_record(repo: "aaronmallen/sai", sha: "f" * 40)
      visit_commit(record)

      expect(page).to have_link(href: "https://github.com/aaronmallen/sai/commit/#{'f' * 40}")
    end

    it "reads the commit out of the database, asking GitHub nothing about it" do
      record = commit_record(repo: "aaronmallen/sai", message: "subject\n\nbody")
      visit_commit(record)
      asked = a_request(:get, "https://api.github.com/repos/aaronmallen/sai/commits/#{record.sha}")

      expect(asked).not_to have_been_made
    end
  end
end

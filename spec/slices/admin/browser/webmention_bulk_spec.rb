# frozen_string_literal: true

RSpec.describe "Admin bulk webmention actions", type: :feature do
  let(:relation) { Social::Slice["relations.webmentions"] }

  def acts = find("[data-bulk-acts]", visible: :all)

  def all_box = find("[data-bulk-all] input")

  def authors(status) = relation.where(status:).order(:author_name).pluck(:author_name)

  def box(author) = find(".li", text: author).find("input[name='ids[]']")

  def scripts_off
    page.driver.browser.page.disable_javascript
    visit "/admin/webmentions"
  end

  def scripts_on = page.driver.browser.page.command("Emulation.setScriptExecutionDisabled", value: false)

  before do
    target = create(:post, :published)
    %w[Ada Grace Alan].each { create(:webmention, post_id: target.id, author_name: it) }
    create(:webmention, :spam, post_id: target.id, author_name: "Barbara")
    sign_in_to_admin
  end

  describe "with scripts on" do
    before { visit "/admin/webmentions" }

    it "hides the actions while nothing is ticked" do
      expect(acts).not_to be_visible
    end

    it "shows the actions once a row is ticked" do
      box("Grace").check

      expect(acts).to be_visible
    end

    it "approves the ticked webmentions and leaves the rest", :aggregate_failures do
      box("Ada").check
      box("Alan").check
      within("form#webmention-bulk") { click_button("Approve") }

      expect(page).to have_css("[data-toast] .toast", text: "Approved 2 webmentions")
      expect(authors("pending")).to eq(["Grace"])
    end

    it "ignores every webmention on the page with select all", :aggregate_failures do
      all_box.check
      within("form#webmention-bulk") { click_button("Ignore") }

      expect(page).to have_css("[data-toast] .toast", text: "Ignored 3 webmentions")
      expect(authors("pending")).to be_empty
    end

    it "marks the ticked webmentions as spam", :aggregate_failures do
      box("Grace").check
      within("form#webmention-bulk") { click_button("Spam") }

      expect(page).to have_css("[data-toast] .toast", text: "Marked 1 webmention as spam")
      expect(authors("spam")).to eq(%w[Barbara Grace])
    end
  end

  describe "on the spam list" do
    before { visit "/admin/webmentions?status=spam" }

    it "approves the ticked webmentions", :aggregate_failures do
      box("Barbara").check
      within("form#webmention-bulk") { click_button("Approve") }

      expect(page).to have_css("[data-toast] .toast", text: "Approved 1 webmention")
      expect(authors("spam")).to be_empty
    end
  end

  describe "with scripts off" do
    before { scripts_off }

    after { scripts_on }

    it "shows the actions with nothing ticked" do
      expect(acts).to be_visible
    end

    it "still approves the ticked webmentions with a plain post", :aggregate_failures do
      box("Ada").check
      within("form#webmention-bulk") { click_button("Approve") }

      expect(page).to have_current_path("/admin/webmentions?status=pending")
      expect(authors("pending")).to eq(%w[Alan Grace])
    end
  end
end

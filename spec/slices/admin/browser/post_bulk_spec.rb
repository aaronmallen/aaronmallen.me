# frozen_string_literal: true

RSpec.describe "Admin bulk post actions", type: :feature do
  let(:repo) { Posts::Slice["repos.post_repo"] }

  def acts = find("[data-bulk-acts]", visible: :all)

  def all_box = find("[data-bulk-all] input")

  def box(title) = find(".li", text: title).find("input[name='ids[]']")

  def confirm_dialog = find("dialog#confirm-dialog[open]")

  def delete_ticked
    within("form#post-bulk") { click_button("Delete") }
    confirm_dialog.click_button("Yes")
  end

  def scripts_off
    page.driver.browser.page.disable_javascript
    visit "/admin/posts"
  end

  def scripts_on = page.driver.browser.page.command("Emulation.setScriptExecutionDisabled", value: false)

  def tag_ticked(name)
    within("form#post-bulk") do
      fill_in("tag", with: name)
      click_button("Tag")
    end
  end

  def tagged(name) = repo.all.select { |post| post.tags.any? { it.name == name } }.map(&:title)

  def titles = repo.all.map(&:title)

  before do
    create(:post, :draft, title: "first draft", updated_at: Time.now - 30)
    create(:post, :draft, title: "second draft", updated_at: Time.now - 20)
    create(:post, :published, title: "live post")
    sign_in_to_admin
  end

  describe "with scripts on" do
    before { visit "/admin/posts" }

    it "hides the actions while nothing is ticked" do
      expect(acts).not_to be_visible
    end

    it "shows the actions once a row is ticked" do
      box("first draft").check

      expect(acts).to be_visible
    end

    it "ticks every row on the page with select all" do
      all_box.check

      expect(page.all("input[name='ids[]']:checked").size).to eq(3)
    end

    it "deletes the ticked drafts after asking", :aggregate_failures do
      box("first draft").check
      box("second draft").check
      delete_ticked

      expect(page).to have_css("[data-toast] .toast", text: "Deleted 2 drafts")
      expect(titles).to eq(["live post"])
    end

    it "keeps every post when a published one is ticked", :aggregate_failures do
      all_box.check
      delete_ticked

      expect(page).to have_css("[data-toast] .toast", text: "Nothing changed · live post is not a draft")
      expect(titles.size).to eq(3)
    end

    it "tags rather than deletes when Enter goes in the tag field", :aggregate_failures do
      box("live post").check
      find("form#post-bulk input[name='tag']").send_keys("ruby", :enter)

      expect(page).to have_css("[data-toast] .toast", text: "Tagged 1 post ruby")
      expect(tagged("ruby")).to eq(["live post"])
    end
  end

  describe "with scripts off" do
    before { scripts_off }

    after { scripts_on }

    it "shows the actions with nothing ticked" do
      expect(acts).to be_visible
    end

    it "draws no select all" do
      expect(page).to have_no_css("[data-bulk-all]")
    end

    it "still tags the ticked posts with a plain post" do
      box("first draft").check
      tag_ticked("ruby")

      expect(tagged("ruby")).to eq(["first draft"])
    end

    it "still deletes the ticked drafts with a plain post", :aggregate_failures do
      box("second draft").check
      within("form#post-bulk") { click_button("Delete") }

      expect(page).to have_current_path("/admin/posts?status=all")
      expect(titles).to contain_exactly("first draft", "live post")
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Admin edit note dialog", type: :feature do
  let(:article) { create(:post, :published, title: "Hello", slug: "hello", body: "one") }
  let(:post_edit_repo) { Posts::Slice["repos.post_edit_repo"] }
  let(:post_repo) { Posts::Slice["repos.post_repo"] }

  def dialog = find("dialog[data-edit-note-dialog]")

  def focused_value = evaluate_script("document.activeElement.value")

  def notes = post_edit_repo.for_post(article.id).map(&:note)

  def save = click_button("Save", match: :first)

  def saved_body = post_repo.by_id(article.id).body

  def visit_editor(post = article) = visit("/admin/posts/#{post.id}/edit")

  before { sign_in_to_admin }

  describe "on a published post" do
    before { visit_editor }

    it "hides the note field until Save", :aggregate_failures do
      expect(page).to have_no_field("What changed and why")
      expect(page).to have_no_css(".card-label", text: "What changed and why")
    end

    it "saves an unchanged body without asking", :aggregate_failures do
      fill_in "Title", with: "Changed"
      save

      expect(page).to have_css(".toast", text: "Saved")
      expect(page).to have_no_css("dialog[open]")
      expect(post_repo.by_id(article.id).title).to eq("Changed")
    end

    it "does not ask when only the newline style changes" do
      visit_editor(create(:post, :published, body: "one\ntwo"))
      execute_script("document.getElementById('post-body').value = 'one\\r\\ntwo'")
      save

      expect(page).to have_css(".toast", text: "Saved")
    end

    describe "after the body changes" do
      before do
        fill_in "Body", with: "two"
        save
      end

      it "asks for the note in a modal and saves nothing yet", :aggregate_failures do
        expect(dialog).to have_field("What changed and why")
        expect(page).to have_no_css(".toast")
        expect(saved_body).to eq("one")
      end

      it "offers the full Markdown editor", :aggregate_failures do
        expect(dialog).to have_css(".seg-option", text: "Write")
        expect(dialog).to have_css(".seg-option", text: "Preview")
        expect(dialog).to have_css("[role='toolbar']")
      end

      it "saves the post and the note on confirm", :aggregate_failures do
        dialog.fill_in "What changed and why", with: "Fixed a typo"
        dialog.click_button "Save"

        expect(page).to have_css(".toast", text: "Saved")
        expect(saved_body).to eq("two")
        expect(notes).to eq(["Fixed a typo"])
      end

      it "leaves the post unsaved on Cancel and hands focus to Save", :aggregate_failures do
        dialog.click_button "Cancel"

        expect(page).to have_no_css("dialog[open]")
        expect(focused_value).to eq("save")
        expect(saved_body).to eq("one")
      end

      it "leaves the post unsaved on a click outside and hands focus to Save", :aggregate_failures do
        page.driver.browser.mouse.click(x: 5, y: 5)

        expect(page).to have_no_css("dialog[open]")
        expect(focused_value).to eq("save")
        expect(saved_body).to eq("one")
      end

      it "leaves the post unsaved on Escape and hands focus to Save", :aggregate_failures do
        dialog.send_keys(:escape)

        expect(page).to have_no_css("dialog[open]")
        expect(focused_value).to eq("save")
        expect(saved_body).to eq("one")
      end
    end
  end

  describe "after a failed save" do
    before do
      visit_editor
      fill_in "Body", with: "two"
    end

    describe "with a note" do
      before do
        fill_in "Title", with: " "
        save
        dialog.fill_in "What changed and why", with: "Fixed a typo"
        dialog.click_button "Save"
      end

      it "shows the note inline with its text", :aggregate_failures do
        expect(page).to have_no_css("dialog[open]")
        expect(page.find(".editor-main")).to have_field("What changed and why", with: "Fixed a typo")
      end

      it "saves without asking again", :aggregate_failures do
        fill_in "Title", with: "Hello"
        save

        expect(page).to have_css(".toast", text: "Saved")
        expect(notes).to eq(["Fixed a typo"])
      end
    end

    it "shows the note's error inline without opening the modal", :aggregate_failures do
      save
      dialog.click_button "Save"

      expect(page).to have_css(".editor-main #post-edit_note-error")
      expect(page).to have_no_css("dialog[open]")
      expect(page).to have_field("What changed and why")
    end
  end

  {
    "draft" => :draft,
    "scheduled post" => :scheduled,
  }.each do |name, trait|
    it "never asks on a #{name}", :aggregate_failures do
      visit_editor(create(:post, trait, body: "one"))
      fill_in "Body", with: "two"
      click_button "Save draft"

      expect(page).to have_css(".toast", text: "Draft saved")
      expect(page).to have_no_css("[data-edit-note-dialog]", visible: :all)
    end
  end
end

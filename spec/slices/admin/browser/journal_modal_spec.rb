# frozen_string_literal: true

RSpec.describe "Admin journal modal", type: :feature do
  let(:modal) { find("dialog#journal-write") }
  let(:repo) { Record::Slice["repos.journal_entry_queries"] }

  def press(*keys) = page.driver.browser.keyboard.type(*keys)

  before do
    sign_in_to_admin
    visit "/admin/posts"
    press("w")
  end

  it "opens with the cursor in the entry", :aggregate_failures do
    expect(modal).to have_css(".dialog-head", text: "journal · private · #{Blog::TimeZone.today.strftime('%b %-d')}")
    expect(page).to have_css("#journal-write-body:focus")
  end

  it "counts words and enables Save once there is text", :aggregate_failures do
    expect(modal).to have_button("Save", disabled: true)

    modal.fill_in "journal-write-body", with: "one two three"

    expect(modal).to have_css("[data-journal-words]", exact_text: "3 words")
    expect(modal).to have_button("Save", disabled: false)
  end

  describe "saving" do
    before do
      modal.fill_in "journal-write-body", with: "walked to the lake"
      modal.fill_in "journal-write-tags", with: "health"
      modal.click_button("Save")
    end

    it "saves today's entry with its tags and returns to the page", :aggregate_failures do
      expect(page).to have_css(".toast", text: "Journal entry saved · private")
      expect(page).to have_current_path("/admin/posts")
      expect(repo.today.map { [it.body, it.tags.map(&:name)] }).to eq([["walked to the lake", %w[health]]])
    end
  end

  it "saves on Ctrl+Enter", :aggregate_failures do
    modal.fill_in "journal-write-body", with: "walked"
    find_by_id("journal-write-body").send_keys(%i[control enter])

    expect(page).to have_css(".toast", text: "Journal entry saved · private")
    expect(repo.today.map(&:body)).to eq(["walked"])
  end

  describe "a failed save" do
    before do
      modal.fill_in "journal-write-body", with: "walked"
      modal.fill_in "journal-write-tags", with: "a/b"
      modal.click_button("Save")
    end

    it "shows its errors in the modal and keeps what was typed", :aggregate_failures do
      expect(page).to have_css("dialog#journal-write[open] #journal-write-tags-error.field-error")
      expect(page).to have_field("journal-write-body", with: "walked")
      expect(repo.count).to eq(0)
    end
  end
end

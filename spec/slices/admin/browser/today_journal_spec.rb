# frozen_string_literal: true

RSpec.describe "Admin today journal card", type: :feature do
  let(:today) { Blog::TimeZone.today }
  let(:save_button) { find_button("Save entry", disabled: :all) }
  let(:words) { "#today-journal-entry [data-journal-words]" }

  before do
    sign_in_to_admin
    visit "/admin"
  end

  describe "the word count" do
    it "counts words as you type" do
      fill_in "Entry", with: "one two three"

      expect(page).to have_css(words, exact_text: "3 words")
    end

    it "uses the singular for one word" do
      fill_in "Entry", with: "one"

      expect(page).to have_css(words, exact_text: "1 word")
    end

    it "goes back to zero when the text is cleared" do
      fill_in "Entry", with: "ab"
      find_field("Entry").send_keys(:backspace, :backspace)

      expect(page).to have_css(words, exact_text: "0 words")
    end
  end

  describe "Save entry" do
    it "starts disabled" do
      expect(save_button).to be_disabled
    end

    it "enables once there is text" do
      fill_in "Entry", with: "walked"

      expect(page).to have_button("Save entry", disabled: false)
    end

    it "stays disabled for only whitespace" do
      fill_in "Entry", with: "  \n\t "

      expect(page).to have_button("Save entry", disabled: true)
    end

    it "disables again when the text is cleared" do
      fill_in "Entry", with: "ab"
      find_field("Entry").send_keys(:backspace, :backspace)

      expect(page).to have_button("Save entry", disabled: true)
    end
  end

  describe "saving" do
    before do
      fill_in "Entry", with: "walked to the lake"
      click_button "Save entry"
      page.assert_selector(".toast", text: "Journal entry saved · private")
    end

    it "lists the entry under the card", :aggregate_failures do
      expect(page).to have_css(".today-journal-entries .journal-entry-body", exact_text: "walked to the lake")
      expect(page).to have_css(".today-journal-entry time.today-journal-time")
    end

    it "clears the textarea and disables Save entry again", :aggregate_failures do
      expect(page).to have_field("Entry", with: "")
      expect(page).to have_button("Save entry", disabled: true)
    end

    it "counts the entry in the card head and the stat", :aggregate_failures do
      expect(page).to have_css(".card-side .journal-words", exact_text: "1 today")
      expect(page).to have_css(".g-4 .stat .stat-value", exact_text: "4")
    end
  end
end

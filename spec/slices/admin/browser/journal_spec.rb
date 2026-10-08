# frozen_string_literal: true

RSpec.describe "Admin journal", type: :feature do
  let(:save_button) { find_button("Save entry", disabled: :all) }

  def bottom(selector) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().bottom")

  def choose_date(date)
    execute_script(<<~JS)
      const input = document.getElementById("journal-entry-date");
      input.value = "#{date.iso8601}";
      input.dispatchEvent(new Event("input", { bubbles: true }));
    JS
  end

  def day_heading_stuck_to_bar?
    evaluate_script(<<~JS)
      (() => {
        const bar = document.querySelector(".top-bar").getBoundingClientRect().bottom;
        return [...document.querySelectorAll(".day-head")]
          .some((head) => Math.abs(head.getBoundingClientRect().top - bar) < 1);
      })()
    JS
  end

  def editor(scope = page) = scope.find(".journal-editor [data-markdown-editor]")

  def entry_bodies_on(date) = all(".journal-day:has(time[datetime='#{date.iso8601}']) .journal-entry-body").map(&:text)

  def font(selector) = evaluate_script("getComputedStyle(document.querySelector('#{selector}')).fontFamily")

  def scroll_into_a_day
    execute_script(<<~JS)
      const day = document.querySelectorAll(".journal-day")[3];
      const bar = document.querySelector(".top-bar").getBoundingClientRect().bottom;
      window.scrollBy(0, day.getBoundingClientRect().top + (day.offsetHeight / 2) - bar);
    JS
  end

  def top(selector) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().top")

  def translate(key) = Admin::Slice["i18n"].t(key)

  before do
    sign_in_to_admin
    visit "/admin/journal"
  end

  describe "the word count" do
    it "counts words as you type" do
      fill_in "Entry", with: "one two three"

      expect(page).to have_css("[data-journal-words]", exact_text: "3 words")
    end

    it "counts runs of characters between spaces as words" do
      fill_in "Entry", with: "## one --- two\n\tthree"

      expect(page).to have_css("[data-journal-words]", exact_text: "5 words")
    end

    it "uses the singular for one word" do
      fill_in "Entry", with: "one"

      expect(page).to have_css("[data-journal-words]", exact_text: "1 word")
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

  describe "the Markdown editor" do
    it "inserts a toolbar snippet and counts its words", :aggregate_failures do
      editor.find("[role='toolbar'] button[aria-label='Bold']").click

      expect(find_field("Entry").value).to eq("**bold**")
      expect(page).to have_css("[data-journal-words]", exact_text: "1 word")
      expect(page).to have_button("Save entry", disabled: false)
    end

    describe "previewing an entry" do
      let!(:preview) do
        fill_in "Entry", with: "a **bold** day\n\n- one"
        editor.find(".seg-option", text: "Preview").click
        { html: editor.find(".preview .post-body")[:innerHTML], font: font(".journal-editor .preview .post-body") }
      end

      before do
        editor.find(".seg-option", text: "Write").click
        click_button "Save entry"
        page.assert_selector(".toast", text: "Journal entry saved · private")
      end

      it "renders the markup the saved entry shows" do
        expect(find(".journal-entry-body")[:innerHTML]).to eq(preview[:html])
      end

      it "sets it in the saved entry's typeface" do
        expect(font(".journal-entry-body")).to eq(preview[:font])
      end
    end
  end

  describe "the entry date" do
    it "titles the card with a chosen date" do
      choose_date(Date.new(2026, 9, 3))

      expect(page).to have_css("#journal-entry .card-title", exact_text: "Thursday, September 3, 2026")
    end

    it "titles the card Today again for today" do
      choose_date(Date.new(2026, 9, 3))
      choose_date(today)

      expect(page).to have_css("#journal-entry .card-title", exact_text: "Today")
    end

    it "files a backdated entry under the chosen date" do
      choose_date(today - 2)
      fill_in "Entry", with: "remembered"
      click_button "Save entry"
      page.assert_selector(".toast", text: "Journal entry saved · private")

      expect(entry_bodies_on(today - 2)).to eq(["remembered"])
    end
  end

  describe "editing an entry" do
    let!(:entry) { create(:journal_entry, entry_date: today - 2, entry_time: "21:05", body: "before") }
    let(:repo) { Record::Slice["repos.journal_entry_queries"] }
    let(:item) { find(".journal-entry", text: "21:05") }

    before do
      visit "/admin/journal"
      item.click_button "Edit"
    end

    it "swaps the text for a textarea holding it", :aggregate_failures do
      expect(item).to have_field("Entry text", with: "before")
      expect(item).to have_no_css(".journal-entry-body")
    end

    it "hides Edit and Delete while editing", :aggregate_failures do
      expect(item).to have_no_button("Edit")
      expect(item).to have_no_button("Delete")
    end

    it "focuses the textarea" do
      expect(evaluate_script("document.activeElement.name")).to eq("entry[body]")
    end

    it "saves the new body under the same day and time", :aggregate_failures do
      item.fill_in "Entry text", with: "after"
      item.click_button "Save"
      page.assert_selector(".toast", text: "Entry updated")

      expect(entry_bodies_on(today - 2)).to eq(["after"])
      expect(repo.by_id(entry.id).entry_time.strftime("%H:%M")).to eq("21:05")
    end

    it "disables Save for only whitespace" do
      item.fill_in "Entry text", with: "  \n "

      expect(item).to have_button("Save", disabled: true)
    end

    it "puts the text back on Cancel", :aggregate_failures do
      item.fill_in "Entry text", with: "changed my mind"
      item.click_button "Cancel"

      expect(item).to have_css(".journal-entry-body", exact_text: "before")
      expect(item).to have_no_field("Entry text")
      expect(repo.by_id(entry.id).body).to eq("before")
    end

    it "holds the saved text when editing again after Cancel" do
      item.fill_in "Entry text", with: "changed my mind"
      item.click_button "Cancel"
      item.click_button "Edit"

      expect(item).to have_field("Entry text", with: "before")
    end
  end

  describe "an entry's links" do
    let(:entry) { create(:journal_entry, body: "Packed the rack") }
    let(:item) { find(".journal-entry") }

    before do
      Links::Slice["operations.link_records"]
        .call("journal_entry", entry.id, { other_kind: "post", other_id: create(:post, title: "On racks").id })
      visit "/admin/journal"
      item.click_link "Links"
    end

    it "hides the section on Cancel" do
      item.click_button "Cancel"

      expect(item).to have_no_css(".record-links")
    end
  end

  describe "cancelling an edit to a markdown entry" do
    let(:item) { find(".journal-entry") }

    before do
      create(:journal_entry, body: "a **bold** day\n\n- one")
      visit "/admin/journal"
      item.click_button "Edit"
      item.fill_in "Entry text", with: "changed my mind"
      item.click_button "Cancel"
    end

    it "puts the markdown source back in the textarea" do
      item.click_button "Edit"

      expect(item).to have_field("Entry text", with: "a **bold** day\n\n- one")
    end

    it "shows the rendered entry again", :aggregate_failures do
      expect(item).to have_css(".journal-entry-body strong", exact_text: "bold")
      expect(item).to have_css(".journal-entry-body li", exact_text: "one")
    end
  end

  describe "previewing an edit" do
    let(:item) { find(".journal-entry") }

    before do
      create(:journal_entry, body: "before")
      visit "/admin/journal"
      item.click_button "Edit"
      item.fill_in "Entry text", with: "an *edited* entry"
      editor(item).find(".seg-option", text: "Preview").click
    end

    it "previews the edited text" do
      expect(editor(item)).to have_css(".preview em", exact_text: "edited")
    end

    it "opens on Write with the saved text after Cancel", :aggregate_failures do
      item.click_button "Cancel"
      item.click_button "Edit"

      expect(item).to have_field("Entry text", with: "before")
      editor(item).find(".seg-option", text: "Preview").click
      expect(editor(item)).to have_css(".preview p", exact_text: "before")
    end
  end

  describe "a rejected edit" do
    let(:item) { find(".journal-entry") }

    before do
      create(:journal_entry, body: "before")
      visit "/admin/journal"
      execute_script(<<~JS)
        const form = document.querySelector("[data-journal-edit-form]");
        form.querySelector("textarea").value = " ";
        form.submit();
      JS
      page.assert_selector(".field-error", text: translate("ui.components.journal.field_error.body.blank"))
    end

    it "clears the error on Cancel", :aggregate_failures do
      item.click_button "Cancel"
      item.click_button "Edit"

      expect(item).to have_field("Entry text", with: "before")
      expect(item).to have_no_css(".field-error")
    end
  end

  describe "deleting an entry" do
    before do
      create(:journal_entry, body: "keep me")
      create(:journal_entry, entry_date: today - 1, body: "drop me")
      visit "/admin/journal"
    end

    let(:item) { find(".journal-entry", text: "drop me") }

    it "asks with the confirmation text" do
      message = confirm_no { item.click_button "Delete" }

      expect(message).to eq(translate("ui.components.journal.entry.confirm_delete"))
    end

    it "keeps the entry when I don't confirm", :aggregate_failures do
      confirm_no { item.click_button "Delete" }

      expect(page).to have_no_css(".toast")
      expect(page).to have_css(".journal-entry-body", text: "drop me")
    end

    it "removes the entry and updates the counts once I confirm", :aggregate_failures do
      confirm_yes { item.click_button "Delete" }
      page.assert_selector(".toast", text: "Entry deleted")

      expect(page).to have_no_css(".journal-entry-body", text: "drop me")
      expect(page).to have_css(".page-head-sub", text: "1 entry · 2 words")
      expect(page).to have_css(".page-head-sub", text: "wrote on 1 of the last 30 days")
    end
  end

  describe "scrolling" do
    before do
      12.times { |days| 3.times { create(:journal_entry, entry_date: today - days) } }
      visit "/admin/journal"
      execute_script("window.scrollTo(0, 1500)")
    end

    it "scrolls past the top of the page" do
      expect(evaluate_script("window.scrollY")).to eq(1500)
    end

    it "keeps the composer in view below the top bar" do
      expect(top(".journal-compose")).to be >= bottom(".top-bar")
    end

    it "keeps the composer on screen" do
      expect(top(".journal-compose")).to be < 200
    end

    it "sticks a day heading directly below the top bar" do
      scroll_into_a_day

      expect(day_heading_stuck_to_bar?).to be(true)
    end
  end

  describe "on a narrow screen" do
    before do
      page.driver.resize(375, 800)
      visit "/admin/journal"
    end

    it "stacks the composer above the entries" do
      expect(bottom(".journal-compose")).to be <= top(".journal-days")
    end
  end
end

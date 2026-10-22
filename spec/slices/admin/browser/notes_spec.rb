# frozen_string_literal: true

RSpec.describe "Admin notes", type: :feature do
  let(:queries) { Notes::Slice["repos.note_queries"] }
  let(:note) { create(:note, title: "Plan", body: "Old") }

  before { sign_in_to_admin }

  describe "the editor" do
    before { visit "/admin/notes/#{note.id}?edit=1" }

    it "saves the body as I type and keeps the version each save sends back", :aggregate_failures do
      find("textarea[name='note[body]']").fill_in(with: "First")
      expect(page).to have_css("[data-note-status]", text: /saved \d/)
      find("textarea[name='note[body]']").fill_in(with: "Second")

      expect(page).to have_css("[data-note-status]", text: /saved \d/, wait: 5)
      expect { queries.by_id(note.id).body }.to eventually(eq("Second"))
    end

    it "tells me the note changed elsewhere when a save is refused" do
      Notes::Slice["operations.edit_note"].call(note.id, { body: "Agent", version: 1 })
      find("textarea[name='note[body]']").fill_in(with: "Mine")

      expect(page).to have_css("[data-note-refused]", text: "This note changed elsewhere")
    end

    it "keeps the old title when another note has the one I typed", :aggregate_failures do
      create(:note, title: "Taken")
      find("input[name='note[title]']").fill_in(with: "Taken")

      expect(page).to have_css("[data-note-title-error]", text: /called “Taken”/)
      find("textarea[name='note[body]']").click
      expect(find("input[name='note[title]']").value).to eq("Plan")
    end

    it "saves a tag I add" do
      find(".nt-ta-add").click
      find("[data-note-tag-input]").send_keys("ruby", :enter)

      expect { queries.by_id(note.id).tags.map(&:name) }.to eventually(eq(["ruby"]))
    end
  end

  describe "the tree" do
    before do
      create(:note_folder, name: "work")
      visit "/admin/notes"
    end

    it "makes a nested folder from the inline input" do
      find_by_id("note-new-folder").click
      find("[data-note-folder-form] input").send_keys("work/clients", :enter)

      expect(page).to have_css("summary.nt-dr", text: "clients")
    end

    it "remembers a folder I collapse", :aggregate_failures do
      find("summary.nt-dr", text: "work").click
      visit "/admin/notes"

      expect(page).to have_css("details.nt-dir:not([open])")
    end
  end

  describe "on a phone" do
    before { page.current_window.resize_to(390, 844) }

    after { page.current_window.resize_to(1280, 800) }

    it "shows the note without the tree and goes back to it", :aggregate_failures do
      visit "/admin/notes/#{note.id}"
      expect(page).to have_css(".nt-page")
      expect(page).to have_no_css(".nt-side")

      click_link "Files"
      expect(page).to have_css(".nt-side")
    end
  end
end

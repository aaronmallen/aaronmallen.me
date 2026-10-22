# frozen_string_literal: true

RSpec.describe "Admin notes", type: :request do
  let(:queries) { Notes::Slice["repos.note_queries"] }

  def json_post(path, **params)
    post(path, { _csrf_token: admin_csrf_token, **params }, { "HTTP_ACCEPT" => "application/json" })
  end

  def note_titles = page.all(".nt-tree a.nt-r .nt-t").map(&:text)

  before { sign_in_to_admin }

  describe "the tab" do
    before do
      create(:note)
      create(:note)
      get "/admin/notes"
    end

    it "sits in the journal tabs with a count of notes", :aggregate_failures do
      expect(page).to have_css("a.screen-tab[aria-current='page'][href='/admin/notes']", text: "notes")
      expect(page).to have_css("a.screen-tab[href='/admin/notes'] .screen-tab-note", text: "2")
    end

    it "sits in the switcher menu with a note icon" do
      expect(page).to have_css(".switcher-panel a.switcher-row[href='/admin/notes'] i.fa-note-sticky", visible: :all)
    end

    it "counts the notes and folders under the heading" do
      expect(page).to have_css(".page-head-sub", text: "2 notes in 0 folders")
    end
  end

  describe "the tree" do
    let!(:work) { create(:note_folder, name: "work") }
    let!(:clients) { create(:note_folder, name: "clients", parent_id: work.id) }
    let!(:empty) { create(:note_folder, name: "empty") }

    before do
      create(:note, title: "Pinned one", pinned: true)
      create(:note, title: "Acme", folder_id: clients.id)
      create(:note, title: "Plan", folder_id: work.id)
      get "/admin/notes"
    end

    it "lists pinned notes first" do
      expect(page).to have_css(".nt-side > form.nt-sr:first-child + p.nt-g + a.nt-r", text: "Pinned one")
    end

    it "nests folders that collapse and count every note beneath them", :aggregate_failures do
      expect(page).to have_css("details.nt-dir[open] > a.nt-dl", text: /work\s*2/)
      expect(page).to have_css("details.nt-dir details.nt-dir > a.nt-dl", text: /clients\s*1/)
    end

    it "lists folders before the notes beside them" do
      expect(note_titles).to eq(["Acme", "Plan", "Pinned one"])
    end

    it "marks an empty folder and offers to remove it", :aggregate_failures do
      expect(page).to have_css("details[data-note-folder='#{empty.id}'] .nt-emp", text: "Empty")
      expect(page).to have_css("details[data-note-folder='#{empty.id}'] form[action$='/folders/#{empty.id}/delete']")
      expect(page).to have_no_css("details[data-note-folder='#{work.id}'] > .nt-da form[action$='/delete']")
    end

    it "adds notes and folders from each folder", :aggregate_failures do
      expect(page).to have_css(
        ".nt-da form[action='/admin/notes'] input[name='folder_id'][value='#{work.id}']", visible: :all,
      )
      expect(page).to have_css(".nt-da button[data-note-new-folder='work/clients/']")
    end

    it "holds the inline new-folder input" do
      expect(page).to have_css("form[action='/admin/notes/folders'][hidden] input[name='path']", visible: :all)
    end

    it "lists the eight notes edited last when nothing is open", :aggregate_failures do
      9.times { create(:note, updated_at: Time.now - 3600) }
      create(:note, title: "Newest", folder_id: clients.id, updated_at: Time.now + 60)
      get "/admin/notes"

      expect(page.all(".nt-rw")).to have_attributes(size: 8)
      expect(page).to have_css(".nt-rw:first-child .nt-mt", text: "work/clients")
    end
  end

  describe "folders" do
    it "makes each folder on a nested path" do
      admin_post "/admin/notes/folders", path: "work/clients"

      expect(queries.folders.map(&:name)).to eq(%w[clients work])
    end

    it "nests a subfolder under the folder its menu named" do
      work = create(:note_folder, name: "work")
      admin_post "/admin/notes/folders", prefix: "work/", path: "clients"

      expect(queries.child_folder(work.id, "clients")).not_to be_nil
    end

    it "moves a folder's notes up when it goes", :aggregate_failures do
      work = create(:note_folder, name: "work")
      note = create(:note, folder_id: work.id)
      admin_post "/admin/notes/folders/#{work.id}/delete"

      expect(toast).to eq("Folder removed")
      expect(queries.by_id(note.id).folder_id).to be_nil
    end

    it "refuses a move inside itself" do
      work = create(:note_folder, name: "work")
      create(:note_folder, name: "inner", parent_id: work.id)
      admin_post "/admin/notes/folders/#{work.id}/move", path: "work/inner"

      expect(toast).to eq("A folder can't move inside itself")
    end

    it "renames a folder" do
      work = create(:note_folder, name: "work")
      admin_post "/admin/notes/folders/#{work.id}/rename", name: "jobs"

      expect(queries.folder_by_id(work.id).name).to eq("jobs")
    end
  end

  describe "the sidebar search" do
    let!(:pottery) { create(:note_folder, name: "pottery") }

    def hits = page.all(".nt-side a.nt-hit").map { [it.find(".nt-t").text, it.find(".nt-p").text] }

    def search(text, at: "/admin/notes") = get(at, q: text)

    before do
      create(:note, title: "Glaze log", body: "Tried celadon", folder_id: pottery.id, updated_at: Time.now - 60)
      create(:note, title: "Firing", body: "Intro\n## The **glaze** went [[Glaze log|cloudy]]", updated_at: Time.now)
      create(:note, title: "Wheel", body: "Centering", folder_id: pottery.id, updated_at: Time.now - 120)
      create(:note, title: "Errands", body: "Buy milk")
      admin_post "/admin/notes/#{queries.listed.find { it.title == 'Errands' }.id}/tags", tag: "kiln"
    end

    it "holds a search box that asks for words or a #tag" do
      search("")

      expect(page).to have_css(
        "form.nt-sr[role='search'][method='get'][action='/admin/notes'] input[type='search'][name='q']" \
        "[aria-label='Search notes'][placeholder='search notes · #tag']",
      )
    end

    it "lists title matches first, then the rest newest first, each with its folder and a snippet" do
      search("glaze")

      expect(hits).to eq([["Glaze log", "pottery"], ["Firing", "/ · The glaze went cloudy"]])
    end

    it "counts the matches in place of the tree", :aggregate_failures do
      search("glaze")

      expect(page).to have_css(".nt-side p.nt-g", exact_text: "2 matches")
      expect(page).to have_no_css(".nt-tree")
    end

    it "matches a note by its folder" do
      search("pottery")

      expect(hits.map(&:first)).to eq(["Glaze log", "Wheel"])
    end

    it "matches a note by its tags" do
      search("kiln")

      expect(hits).to eq([%w[Errands /]])
    end

    it "filters by a #tag", :aggregate_failures do
      search("#kiln")

      expect(hits).to eq([%w[Errands /]])
      expect(page).to have_css(".nt-side p.nt-g", exact_text: "1 tagged #kiln")
    end

    it "keeps the search when a hit opens its note" do
      search("glaze")

      expect(page).to have_link("Firing", href: %r{/admin/notes/\d+\?q=glaze\z})
    end

    it "searches from a note page and keeps the note open", :aggregate_failures do
      wheel = queries.listed.find { it.title == "Wheel" }
      search("glaze", at: "/admin/notes/#{wheel.id}")

      expect(page).to have_css("form.nt-sr[action='/admin/notes/#{wheel.id}']")
      expect(hits.map(&:first)).to eq(["Glaze log", "Firing"])
    end

    it "offers to create a note by that name when nothing matches", :aggregate_failures do
      search("Bisque")

      expect(page).to have_css(".nt-side p.nt-g", exact_text: "0 matches")
      offer = ".nt-side form[action='/admin/notes'] input[name='title'][value='Bisque'] ~ button.nt-r"
      expect(page).to have_css(offer, text: "Create “Bisque”", visible: :all)
    end

    it "offers nothing to create for a #tag no note holds" do
      search("#nothing")

      expect(page).to have_no_css(".nt-side form[action='/admin/notes'] input[name='title']", visible: :all)
    end

    it "offers to create it in the open note's folder" do
      search("Bisque", at: "/admin/notes/#{queries.listed.find { it.title == 'Wheel' }.id}")

      expect(page).to have_css(
        ".nt-side form[action='/admin/notes'] input[name='folder_id'][value='#{pottery.id}']", visible: :all,
      )
    end
  end

  describe "a new note" do
    it "takes the next free Untitled number and opens in edit mode", :aggregate_failures do
      create(:note, title: "Untitled")
      admin_post "/admin/notes"

      expect(last_response.location).to match(%r{/admin/notes/\d+\?edit=1\z})
      expect(queries.recent(1).first.title).to eq("Untitled 2")
    end

    it "lands in the folder it was made in" do
      work = create(:note_folder, name: "work")
      admin_post "/admin/notes", folder_id: work.id

      expect(queries.recent(1).first.folder_id).to eq(work.id)
    end
  end

  describe "the note page" do
    let(:work) { create(:note_folder, name: "work") }
    let(:note) do
      created = create(:note, title: "Plan", body: "Ship **it**", folder_id: work.id)
      Notes::Slice["operations.tag_note"].call(created.id, "ruby")
      created
    end

    before { get "/admin/notes/#{note.id}" }

    it "renders the body as Markdown" do
      expect(page).to have_css(".nt-prose strong", text: "it")
    end

    it "shows the folder, tags, created date, word count and a private marker", :aggregate_failures do
      expect(page).to have_css(".nt-crumb", text: %r{work /\s*Plan})
      expect(page).to have_css("input[name='path'][value='work']")
      expect(page).to have_css(".nt-tags .nt-tg a.tag", text: "#ruby")
      expect(page).to have_css(".nt-facts .nt-mt", text: /created \w+ \d+.*2 words.*private/)
    end

    it "hides the tree on a phone and offers a way back to it", :aggregate_failures do
      expect(page).to have_css(".nt.open > .nt-side")
      expect(page).to have_css(".nt-bar a.nt-back[href='/admin/notes']", text: "Files")
    end

    it "asks before it deletes" do
      expect(page).to have_css("form[action='/admin/notes/#{note.id}/delete'][data-confirm='Delete “Plan”?']")
    end

    it "is missing for a note that does not exist" do
      get "/admin/notes/999999"

      expect(status).to eq(404)
    end
  end

  describe "editing" do
    let(:note) { create(:note, title: "Plan", body: "Old") }

    it "draws an autosaving editor that holds the version it read", :aggregate_failures do
      get "/admin/notes/#{note.id}?edit=1"

      expect(page).to have_css(
        "form[data-note-editor][data-live-keep] input[name='note[version]'][value='1']", visible: :all,
      )
      expect(page).to have_css("textarea[name='note[body]']", text: "Old")
    end

    it "saves title, tags and body and sends back the next version", :aggregate_failures do
      json_post "/admin/notes/#{note.id}", note: { title: "Plan B", body: "New", tags: "ruby", version: 1 }

      expect(document).to eq("version" => 2, "title" => "Plan B")
      expect(queries.by_id(note.id)).to have_attributes(title: "Plan B", body: "New")
      expect(queries.by_id(note.id).tags.map(&:name)).to eq(["ruby"])
    end

    it "refuses a save from a version that changed elsewhere", :aggregate_failures do
      json_post "/admin/notes/#{note.id}", note: { body: "Mine", version: 1 }
      json_post "/admin/notes/#{note.id}", note: { body: "Stale", version: 1 }

      expect(status).to eq(422)
      expect(document).to eq("errors" => { "version" => "changed" })
      expect(queries.by_id(note.id).body).to eq("Mine")
    end

    it "refuses a title another note has and keeps the old one", :aggregate_failures do
      create(:note, title: "Taken")
      json_post "/admin/notes/#{note.id}", note: { title: "taken", body: "New", version: 1 }

      expect(document).to eq("errors" => { "title" => "taken" })
      expect(queries.by_id(note.id).title).to eq("Plan")
    end

    it "shows the duplicate title error without scripts", :aggregate_failures do
      create(:note, title: "Taken")
      admin_post "/admin/notes/#{note.id}", note: { title: "Taken", body: "New", version: 1 }

      expect(status).to eq(422)
      expect(page).to have_css("[data-note-title-error]", text: /called “Taken”/)
    end

    it "saves without scripts and returns to the editor" do
      admin_post "/admin/notes/#{note.id}", note: { title: "Plan", body: "New", version: 1 }

      expect(last_response.location).to end_with("/admin/notes/#{note.id}?edit=1")
    end
  end

  describe "row actions" do
    let(:note) { create(:note, title: "Plan") }

    it "pins a note" do
      admin_post "/admin/notes/#{note.id}/pin", pinned: "1"

      expect(queries.by_id(note.id).pinned).to be(true)
    end

    it "renames a note and refuses a taken title", :aggregate_failures do
      create(:note, title: "Taken")
      admin_post "/admin/notes/#{note.id}/rename", title: "Taken"

      expect(toast).to eq("Another note has that title")
      expect(queries.by_id(note.id).title).to eq("Plan")
    end

    it "moves a note to a folder path, making the folder", :aggregate_failures do
      admin_post "/admin/notes/#{note.id}/move", path: "work/clients"

      expect(toast).to eq("Moved to work/clients")
      expect(queries.folder_by_id(queries.by_id(note.id).folder_id).name).to eq("clients")
    end

    it "moves a note to the top level" do
      note = create(:note, folder_id: create(:note_folder).id)
      admin_post "/admin/notes/#{note.id}/move", path: ""

      expect(queries.by_id(note.id).folder_id).to be_nil
    end

    it "duplicates a note and opens the copy" do
      admin_post "/admin/notes/#{note.id}/duplicate"

      expect(last_response.location).to match(%r{/admin/notes/\d+\z})
    end

    it "tags a note" do
      admin_post "/admin/notes/#{note.id}/tags", tag: "ruby"

      expect(queries.by_id(note.id).tags.map(&:name)).to eq(["ruby"])
    end

    it "deletes a note and leaves its page", :aggregate_failures do
      admin_post "/admin/notes/#{note.id}/delete", return_to: "/admin/notes/#{note.id}"

      expect(last_response.location).to end_with("/admin/notes")
      expect(queries.by_id(note.id)).to be_nil
    end
  end

  describe "wiki links" do
    let(:work) { create(:note_folder, name: "work") }
    let!(:ruby) { write("Ruby", "See [[Rails|the framework]]") }
    let!(:rails) { write("Rails", "Built on [[ruby]]\n\n- [[Rack]]", folder_id: work.id) }

    def write(title, body, folder_id: nil)
      Notes::Slice["operations.create_note"].call({ title:, body:, folder_id: }).value!
    end

    it "links a written note by its title and keeps the link text" do
      get "/admin/notes/#{ruby.id}"

      expect(page).to have_css(".nt-prose a.wl[href='/admin/notes/#{rails.id}']", text: "the framework")
    end

    it "draws a link to a note not written yet as a button that makes it in the same folder", :aggregate_failures do
      get "/admin/notes/#{rails.id}"

      expect(page).to have_css(".nt-prose button.wl.miss[form='note-create'][name='title'][value='Rack']", text: "Rack")
      form = "form#note-create[action='/admin/notes'] input[name='folder_id'][value='#{work.id}']"
      expect(page).to have_css(form, visible: :all)
    end

    it "makes the missing note under the title its link sends, in the folder the form holds", :aggregate_failures do
      admin_post "/admin/notes", title: "Rack", folder_id: work.id

      made = queries.listed.find { it.title == "Rack" }
      expect(made.folder_id).to eq(work.id)
      expect(last_response.location).to end_with("/admin/notes/#{made.id}?edit=1")
    end

    it "lists the backlinks with the line that links and marks the links out not written", :aggregate_failures do
      get "/admin/notes/#{rails.id}"

      expect(page).to have_css(".nt-links li.nt-bl a[href='/admin/notes/#{ruby.id}']", text: /Ruby\s*See the framework/)
      expect(page.all(".nt-links li.record-link-row").map(&:text)).to eq(["Racknot written", "Ruby"])
    end

    it "warns how many notes link to a note before it deletes it" do
      get "/admin/notes/#{rails.id}"

      expect(page).to have_css("form[data-confirm='Delete “Rails”? 1 note links to it.']")
    end

    it "lists titles linked but not written on the home pane, each with a Create button", :aggregate_failures do
      get "/admin/notes"

      expect(page).to have_css(".nt-links .card-title", text: "Linked, not written")
      expect(page).to have_css(".nt-ms", text: /Rack\s*from Rails/)
      expect(page).to have_css("form[action='/admin/notes'] input[name='title'][value='Rack']", visible: :all)
      expect(page).to have_css(".nt-rw", text: /Rails.*1 backlink/)
    end

    it "renames a note, rewrites the links to it and says how many notes changed", :aggregate_failures do
      admin_post "/admin/notes/#{rails.id}/rename", title: "Hanami"

      expect(toast).to eq("Renamed · links updated in 1 note")
      expect(queries.by_id(ruby.id).body).to eq("See [[Hanami|the framework]]")
    end

    it "says how many notes changed when the editor saves a new title" do
      json_post "/admin/notes/#{rails.id}", note: { title: "Hanami", version: rails.version }

      expect(JSON.parse(last_response.body)["relinked"]).to eq("Renamed · links updated in 1 note")
    end
  end

  describe "menus" do
    let(:work) { create(:note_folder, name: "work") }

    it "copies the note's wiki link" do
      get "/admin/notes/#{create(:note, title: 'Plan').id}/menu"

      expect(page).to have_css("button[data-copy='[[Plan]]']", text: "Copy link")
    end

    it "offers the note actions the design draws" do
      get "/admin/notes/#{create(:note, folder_id: work.id).id}/menu"

      expect(menu_items).to include(
        "Open", "Edit", "Pin", "Rename", "Move to", "Top level", "work", "Tags", "Copy link", "Duplicate",
        "New note beside it", "Delete note",
      )
    end

    it "offers the folder actions the design draws", :aggregate_failures do
      create(:note, folder_id: work.id)
      get "/admin/notes/folders/#{work.id}/menu"

      expect(menu_items).to include("Collapse", "New note here", "New subfolder", "Rename", "Move to", "Copy path",
                                    "Remove folder")
      expect(page).to have_css("[data-confirm-inline='Click again · 1 note moves up']", visible: :all)
    end

    it "offers to expand a folder that is shut" do
      get "/admin/notes/folders/#{work.id}/menu?shut=1"

      expect(menu_items).to include("Expand")
    end

    it "leaves a folder out of the places it can move to inside itself" do
      create(:note_folder, name: "inner", parent_id: work.id)
      get "/admin/notes/folders/#{work.id}/menu"

      expect(menu_items).not_to include("work/inner")
    end

    it "offers the root actions the design draws" do
      get "/admin/notes/menu"

      expect(menu_items).to eq(["New note", "New folder", "Collapse all", "Expand all"])
    end
  end
end

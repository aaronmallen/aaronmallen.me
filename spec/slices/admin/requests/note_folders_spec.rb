# frozen_string_literal: true

RSpec.describe "Admin note folders", type: :request do
  let(:queries) { Notes::Slice["repos.note_queries"] }
  let(:work) { create(:note_folder, name: "work") }
  let(:clients) { create(:note_folder, name: "clients", parent_id: work.id, description: "Paid work, one per client") }
  let(:folder_page) { "/admin/notes/folders/#{clients.id}" }

  before { sign_in_to_admin }

  describe "the page" do
    before do
      body = "```ruby\n\n## The [[Kickoff|first call]] went _well_\nmore"
      acme = create(:note, title: "Acme", folder_id: clients.id, pinned: true, body:, updated_at: Time.now - 60)
      Notes::Slice["operations.tag_note"].call(acme.id, "ruby")
      create(:note, title: "Brief", folder_id: clients.id, body: "One two three", updated_at: Time.now - 3600)
      create(:note_folder, name: "globex", parent_id: clients.id)
      get folder_page
    end

    it "links each folder in the tree to its page and marks the open one", :aggregate_failures do
      expect(page).to have_css(".nt-tree a.nt-dl[href='/admin/notes/folders/#{work.id}']:not([aria-current])")
      expect(page).to have_css(".nt-tree a.nt-dl[href='#{folder_page}'][aria-current='page']", text: "clients")
      expect(page).to have_css(".nt-tree summary.nt-dr.on", text: "clients")
    end

    it "shows breadcrumbs back to each folder above it", :aggregate_failures do
      expect(page).to have_css(".nt-crumb a.nt-cb[href='/admin/notes/folders/#{work.id}']", text: "work")
      expect(page).to have_css(".nt-crumb .nt-cur", text: "clients")
    end

    it "heads the page with the name, description, counts and last edit", :aggregate_failures do
      expect(page).to have_css("h1.nt-h", text: "clients")
      expect(page).to have_css("h1.nt-h i.fa-folder-open")
      expect(page).to have_css(".nt-fd", text: "Paid work, one per client")
      expect(page).to have_css(".nt-fm", text: /2 notes · 1 folder\s*last edited/)
    end

    it "gathers the tags of its notes" do
      expect(page).to have_css(".nt-fh .nt-tags a.tag[href='/admin/tags/ruby']", text: "#ruby")
    end

    it "lists subfolders, then notes newest first", :aggregate_failures do
      expect(page.all(".nt-ix .nt-rt").map(&:text)).to eq(%w[globex Acme Brief])
      expect(page).to have_css(".nt-ix .nt-rw", text: /globex\s*empty/)
    end

    it "draws each note with its excerpt, pin, word count and tags", :aggregate_failures do
      expect(page).to have_css(".nt-ixt i.fa-thumbtack[aria-label='pinned']")
      expect(page).to have_css(".nt-ex", text: "The first call went well")
      expect(page).to have_css(".nt-rw", text: /Brief.*3 words/m)
      expect(page).to have_css(".nt-rw .nt-mt a.tag", text: "#ruby")
    end

    it "counts each note's backlinks" do
      Notes::Slice["operations.create_note"].call({ title: "Plan", body: "See [[Brief]]" })
      get folder_page

      expect(page).to have_css(".nt-rw", text: /Brief.*1 backlink/m)
    end

    it "makes notes and subfolders in the folder", :aggregate_failures do
      new_note = ".nt-bar form[action='/admin/notes'] input[name='folder_id'][value='#{clients.id}']"
      new_folder = ".nt-bar form[action='/admin/notes/folders'] input[name='prefix'][value='work/clients/']"

      expect(page).to have_css(new_note, visible: :all)
      expect(page).to have_css(new_folder, visible: :all)
    end

    it "hides the tree on a phone and offers a way back to it" do
      expect(page).to have_css(".nt.open .nt-bar a.nt-back[href='/admin/notes']")
    end

    it "asks before it removes a folder that holds notes" do
      expect(page).to have_css(
        "form[action='#{folder_page}/delete']" \
        "[data-confirm='Remove clients? Its 2 notes move to work. Folder links are dropped.']",
      )
    end
  end

  it "says when a folder is empty" do
    get folder_page

    expect(page).to have_css(".nt-ix .empty", text: "This folder is empty")
  end

  it "is missing for a folder that does not exist" do
    get "/admin/notes/folders/999999"

    expect(status).to eq(404)
  end

  it "opens from the folder menu" do
    get "/admin/notes/folders/#{work.id}/menu"

    expect(page).to have_css("a[href='/admin/notes/folders/#{work.id}']", text: "Open folder", visible: :all)
  end

  describe "the settings" do
    before { get folder_page }

    it "renames the folder and stays on its page", :aggregate_failures do
      return_to = page.find("form[action$='/rename'] input[name='return_to']", visible: :all).value
      admin_post("#{folder_page}/rename", name: "accounts", return_to:)

      expect(queries.folder_by_id(clients.id).name).to eq("accounts")
      expect(last_response.location).to eq(folder_page)
    end

    it "moves the folder inside another", :aggregate_failures do
      create(:note_folder, name: "archive")
      admin_post "#{folder_page}/move", path: "archive", return_to: folder_page

      expect(queries.folder_by_id(clients.id).parent_id).to eq(queries.child_folder(nil, "archive").id)
      expect(toast).to eq("Moved to archive")
    end

    it "offers every place but itself to move into", :aggregate_failures do
      create(:note_folder, name: "globex", parent_id: clients.id)
      get folder_page

      expect(page).to have_css("input[name='path'][value='work'][list='note-folder-places']")
      expect(page.all("#note-folder-places option", visible: :all).map(&:value)).to eq(["work"])
    end

    it "edits the description", :aggregate_failures do
      admin_post "#{folder_page}/describe", description: "Old clients too", return_to: folder_page

      expect(queries.folder_by_id(clients.id).description).to eq("Old clients too")
      expect(toast).to eq("Description saved")
    end

    it "refuses a description past the limit" do
      admin_post "#{folder_page}/describe", description: "x" * 1001, return_to: folder_page

      expect(toast).to eq("Nothing changed · check what you typed")
    end
  end

  describe "removing it from its page" do
    it "moves its notes up one level and opens the parent", :aggregate_failures do
      note = create(:note, folder_id: clients.id)
      admin_post "#{folder_page}/delete", return_to: folder_page

      expect(queries.by_id(note.id).folder_id).to eq(work.id)
      expect(last_response.location).to eq("/admin/notes/folders/#{work.id}")
    end

    it "opens the notes home when the folder sat at the top level" do
      admin_post "/admin/notes/folders/#{work.id}/delete", return_to: "/admin/notes/folders/#{work.id}"

      expect(last_response.location).to eq("/admin/notes")
    end
  end

  describe "record links" do
    let(:task) { create(:task, title: "Index the activities table") }

    def link(kind, id, other_kind, other_id)
      Links::Slice["operations.link_records"].call(kind, id, { other_kind:, other_id: })
    end

    def linked(kind, id) = Links::Slice["repos.record_link_queries"].for_record(kind, id)

    def parents = page.find(".nt-meta .card", text: "From parent folders")

    it "shows the folder's links with the picker", :aggregate_failures do
      link("note_folder", clients.id, "task", task.id)
      get folder_page

      expect(page.find(".record-links")).to have_link("Index the activities table", href: "/admin/tasks/#{task.id}")
      expect(page).to have_css(".record-links .record-picker")
    end

    it "says the links apply to every note inside it" do
      get folder_page

      expect(page).to have_text(/Links here apply to every note in clients, including subfolders/)
    end

    it "links a record with a plain form and comes back to the folder", :aggregate_failures do
      admin_post "#{folder_page}/records", record: { other_kind: "task", other_id: task.id.to_s }

      expect(last_response.location).to end_with(folder_page)
      expect(linked("note_folder", clients.id).keys).to eq(%w[task])
    end

    it "unlinks a record with a plain form and comes back to the folder", :aggregate_failures do
      link("note_folder", clients.id, "task", task.id)
      admin_post "/admin/records/note_folder/#{clients.id}/links/task/#{task.id}/delete"

      expect(last_response.location).to end_with(folder_page)
      expect(linked("note_folder", clients.id)).to be_empty
    end

    it "lists the links of its parent folders read only", :aggregate_failures do
      link("note_folder", work.id, "task", task.id)
      get folder_page

      expect(parents).to have_link("Index the activities table", href: "/admin/tasks/#{task.id}")
      expect(parents).to have_text("work")
      expect(parents).to have_no_css("form")
    end

    it "leaves the parent card off when no folder above it has links" do
      get folder_page

      expect(page).to have_no_text("From parent folders")
    end

    it "links back from the task to the folder page" do
      link("task", task.id, "note_folder", clients.id)

      expect(linked("task", task.id).fetch("note_folder").first.url).to eq(folder_page)
    end
  end
end

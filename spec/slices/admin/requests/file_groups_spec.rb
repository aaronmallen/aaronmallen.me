# frozen_string_literal: true

require "vips"

RSpec.describe "Admin file groups", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:group) { make_group(%w[a a.txt text/plain], ["png", "shot.png", "image/png"]) }
  let(:drawer) { page.find("dialog#share-group-#{group.id}-drawer", visible: :all) }

  def csrf = { "HTTP_X_CSRF_TOKEN" => admin_csrf_token }

  def dot = Vips::Image.black(30, 30).write_to_buffer(".png")

  def file(bytes, name, type) = Rack::Test::UploadedFile.new(StringIO.new(bytes), type, original_filename: name)

  def files = Shares::Slice["relations.share_group_files"].order(:id).to_a

  def image = files.find { it[:filename] == "shot.png" }

  def make_group(*uploads)
    Shares::Slice["operations.upload_share_group"].call(uploads.map { share_upload(*it) }).value!
  end

  def stored = Shares::Slice["relations.share_groups"].with_code.by_pk(group.id).one

  before do
    sign_in_to_admin
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
    group
  end

  describe "the list" do
    it "shows a group as one card with its file count, link and views", :aggregate_failures do
      get "/admin/files"
      card = page.find(".file-card", text: "2 files")

      expect(card).to have_css(".file-card-link", exact_text: "shares.localhost/#{group.code}")
      expect(card.find(".file-card-meta").text).to include("0 views")
    end

    it "opens the group's drawer from its card, linking to the edit page without scripts" do
      get "/admin/files"

      opener = "a[href='/admin/files/groups/#{group.id}/edit'][data-dialog-open='share-group-#{group.id}-drawer']"

      expect(page).to have_css(".file-card-name #{opener}")
    end

    it "shows its first image as the thumbnail" do
      get "/admin/files"

      expect(page).to have_css("img.file-card-thumb[src='http://shares.localhost/#{group.code}/#{image[:id]}?preview']")
    end

    it "shows a named group by its name in the list and its drawer", :aggregate_failures do
      Shares::Slice["relations.share_groups"].by_pk(group.id).update(name: "Beach trip")
      get "/admin/files"

      expect(page).to have_css(".file-card-name", exact_text: "Beach trip")
      expect(drawer).to have_css(".file-drawer-name", exact_text: "Beach trip", visible: :all)
    end

    it "lists groups before single files" do
      upload_share
      get "/admin/files"

      expect(page.all(".file-card-name").map(&:text)).to eq(["2 files", "hello.txt"])
    end

    it "finds a group by the name of a file in it" do
      make_group(%w[b notes.md text/markdown])
      get "/admin/files", search: "shot"

      expect(page.all(".file-card-name").map(&:text)).to eq(["2 files"])
    end

    it "finds a group by its code" do
      get "/admin/files", search: group.code

      expect(page).to have_css(".file-card-name", text: "2 files")
    end

    it "keeps a group that holds an image under the images filter", :aggregate_failures do
      make_group(%w[b notes.md text/markdown])
      get "/admin/files", kind: "images"

      expect(page.all(".file-card-name").map(&:text)).to eq(["2 files"])
    end

    it "says nothing matches rather than nothing shared when only groups exist" do
      get "/admin/files", search: "nothing"

      expect(page).to have_css(".empty", text: i18n.t("ui.views.files.index.no_match"))
    end

    describe "past the first page" do
      before { 13.times { upload_share("x", "shot-#{it}.txt") } }

      it "counts the group among the matches but shows no card", :aggregate_failures do
        get "/admin/files", search: "shot", page: "2"

        expect(page).to have_css(".hint", text: "14 matches")
        expect(page).to have_no_css(".file-card-name", text: "2 files")
      end

      it "loads no group files" do
        statements = counting { get "/admin/files", search: "shot", page: "2" }

        expect(statements.grep(/"share_group_id" IN \(\d/)).to be_empty
      end
    end
  end

  describe "the drawer" do
    before do
      Shares::Slice["relations.share_groups"].by_pk(group.id).update(view_count: 7, zip_download_count: 3)
      Shares::Slice["relations.share_group_files"].by_pk(image[:id]).update(download_count: 2)
      get "/admin/files"
    end

    it "shows the page views and zip downloads" do
      expect(drawer.find(".file-drawer-meta", visible: :all).text(:all)).to include("7 views", "3 zip downloads")
    end

    it "shows each file's downloads" do
      row = drawer.find(".file-group-item", text: "shot.png", visible: :all)

      expect(row.text(:all)).to include("2 downloads")
    end

    it "edits the group's name and code", :aggregate_failures do
      expect(drawer).to have_field("group[name]", with: "", visible: :all)
      expect(drawer).to have_field("group[code]", with: group.code, visible: :all)
    end

    it "edits each file's name", :aggregate_failures do
      expect(drawer).to have_field("group[files][#{image[:id]}][filename]", with: "shot.png", visible: :all)
      expect(drawer.all("input[name$='[filename]']", visible: :all).size).to eq(2)
    end

    it "edits the alt text of images only", :aggregate_failures do
      expect(drawer).to have_field("group[files][#{image[:id]}][alt_text]", visible: :all)
      expect(drawer.all("input[name$='[alt_text]']", visible: :all).size).to eq(1)
    end

    it "removes a file through a form of its own", :aggregate_failures do
      form = "share-group-#{group.id}-remove-#{image[:id]}"
      action = "/admin/files/groups/#{group.id}/files/#{image[:id]}/delete"

      expect(page).to have_css("form##{form}[action='#{action}'][data-confirm]", visible: :all)
      expect(drawer).to have_css("button[form='#{form}']", visible: :all)
    end

    it "adds files through the upload route" do
      form = drawer.find("form.file-group-add[action='/admin/files'][enctype='multipart/form-data']", visible: :all)

      expect(form).to have_css("input[type='hidden'][name='group_id'][value='#{group.id}']", visible: :all)
    end

    it "asks before it deletes the group" do
      expect(page).to have_css(
        "form#share-group-#{group.id}-delete[action='/admin/files/groups/#{group.id}/delete'][data-confirm]",
        visible: :all,
      )
    end
  end

  describe "the edit page" do
    it "shows the form without scripts" do
      get "/admin/files/groups/#{group.id}/edit"

      expect(page).to have_css("form[action='/admin/files/groups/#{group.id}'] input[name='group[code]']")
    end

    it "answers 404 for a missing group" do
      get "/admin/files/groups/0/edit"

      expect(last_response).to be_not_found
    end
  end

  describe "adding files" do
    def add(*uploads, id: group.id)
      post "/admin/files", { files: uploads, group_id: id.to_s }, csrf
    end

    it "adds them to the group and stores each one", :aggregate_failures do
      add(file("%PDF", "deck.pdf", "application/pdf"))
      follow_redirect!

      expect(files.map { it[:filename] }).to eq(%w[a.txt shot.png deck.pdf])
      expect(a_request(:put, share_store_url(files.last[:key]))).to have_been_made
      expect(page).to have_css("[data-toast]", text: "Added to the group")
    end

    it "makes no single share or new group" do
      add(file("b", "b.txt", "text/plain"))

      expect([Shares::Slice["relations.shares"].count, Shares::Slice["relations.share_groups"].count]).to eq([0, 1])
    end

    it "answers 404 for a missing group" do
      add(file("b", "b.txt", "text/plain"), id: 999_999)

      expect(last_response).to be_not_found
    end

    it "adds nothing when the store fails", :aggregate_failures do
      stub_request(:put, %r{\A#{share_store_url}/}).to_return(status: 500)
      add(file("b", "b.txt", "text/plain"))

      expect(files.size).to eq(2)
    end
  end

  describe "removing a file" do
    let(:text) { files.first }

    def remove(id = text[:id]) = post("/admin/files/groups/#{group.id}/files/#{id}/delete", {}, csrf)

    it "drops its row and its object", :aggregate_failures do
      removed = stub_request(:delete, share_store_url(text[:key]))
      remove

      expect(files.map { it[:filename] }).to eq(%w[shot.png])
      expect(removed).to have_been_requested
    end

    it "drops an image's preview with it" do
      stub_request(:delete, %r{\A#{share_store_url}/})
      photo = make_group([dot, "dot.png", "image/png"], %w[b b.txt text/plain])
      file = photo.share_group_files.first
      post("/admin/files/groups/#{photo.id}/files/#{file.id}/delete", {}, csrf)

      expect(a_request(:delete, share_store_url(file.preview_key))).to have_been_made
    end

    it "says it removed it" do
      stub_request(:delete, share_store_url(text[:key]))
      remove
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: "File removed from the group")
    end

    it "keeps the file when the store fails", :aggregate_failures do
      stub_request(:delete, share_store_url(text[:key])).to_return(status: 500)
      remove
      follow_redirect!

      expect(files.size).to eq(2)
      expect(page).to have_css("[data-toast]", text: i18n.t("files_page.toasts.failed.delete"))
    end

    it "keeps the group while it holds files" do
      stub_request(:delete, share_store_url(text[:key]))
      remove

      expect(stored).not_to be_nil
    end

    it "deletes the group and frees its code with its last file", :aggregate_failures do
      last = image
      files.each { stub_request(:delete, share_store_url(it[:key])) }
      [text[:id], last[:id]].each { remove(it) }

      expect(stored).to be_nil
      expect(Rack::MockRequest.new(Shares::Slice["server"]).get("/#{group.code}").status).to eq(404)
    end

    it "answers 404 for a file in another group" do
      other = make_group(%w[b b.txt text/plain])
      remove(other.share_group_files.first.id)

      expect(last_response).to be_not_found
    end
  end

  describe "saving" do
    let(:server) { Rack::MockRequest.new(Shares::Slice["server"]) }

    def error(reason) = i18n.t(reason, scope: "ui.components.files.field_error.code")

    def save(**fields) = post("/admin/files/groups/#{group.id}", { group: fields }, csrf)

    it "changes the code so the page moves with it", :aggregate_failures do
      old = group.code
      save(code: "beach-trip")

      expect(server.get("/beach-trip").status).to eq(200)
      expect(server.get("/#{old}").status).to eq(404)
    end

    it "says it saved" do
      save(code: "trip")
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: "Group saved")
    end

    describe "the hints" do
      def hints
        get "/admin/files/groups/#{group.id}/edit"
        Capybara.string(last_response.body).all(".hint").map(&:text)
      end

      it "says a new code moves the page and the old one stops working" do
        old = group.code
        save(code: "beach-trip")
        hint = i18n.t("ui.components.links.link_form.code_hint", host: "shares.localhost")

        expect([server.get("/beach-trip").status, server.get("/#{old}").status,
                hints]).to match([200, 404, include(hint)])
      end

      it "says the group's page uses the alt text for the image" do
        save(code: group.code, files: { image[:id].to_s => { alt_text: "A cat" } })
        shown = Capybara.string(server.get("/#{group.code}").body).all("img").map { it[:alt] }

        expect([shown,
                hints]).to match([include("A cat"), include(i18n.t("ui.components.files.group_file.alt_text_hint"))])
      end
    end

    it "names the group, which titles its page and its zip", :aggregate_failures do
      save(code: group.code, name: " Beach trip ")

      expect(stored[:name]).to eq("Beach trip")
      expect(Capybara.string(server.get("/#{group.code}").body)).to have_css("h1", exact_text: "Beach trip")
    end

    it "clears the name when left blank" do
      save(code: group.code, name: "Beach trip")
      save(code: group.code, name: " ")

      expect(stored[:name]).to be_nil
    end

    it "keeps the name when the form sends none" do
      save(code: group.code, name: "Beach trip")
      save(code: "trip")

      expect(stored[:name]).to eq("Beach trip")
    end

    it "renames a file and keeps its link", :aggregate_failures do
      id = image[:id]
      save(code: group.code, files: { id.to_s => { filename: "cat.png" } })

      expect(image).to be_nil
      expect(files.find { it[:id] == id }[:filename]).to eq("cat.png")
    end

    it "refuses a blank file name and changes nothing", :aggregate_failures do
      save(code: "trip", name: "Beach trip", files: { image[:id].to_s => { filename: " " } })

      expect(last_response.status).to eq(422)
      expect(page).to have_css("#share-group-#{group.id}-file-#{image[:id]}-filename[aria-invalid='true']")
      expect([stored[:code], stored[:name], image[:filename]]).to eq([group.code, nil, "shot.png"])
    end

    it "sets the alt text on an image" do
      save(code: group.code, files: { image[:id].to_s => { alt_text: "A cat" } })

      expect(image[:alt_text]).to eq("A cat")
    end

    it "sets no alt text on a file that is no image" do
      save(code: group.code, files: { files.first[:id].to_s => { alt_text: "Words" } })

      expect(files.first[:alt_text]).to be_nil
    end

    it "refuses a code another share holds", :aggregate_failures do
      upload_share.value!.then { save(code: it.code) }

      expect(last_response.status).to eq(422)
      expect(page).to have_css(".field-error", text: error("taken"))
    end

    it "refuses a bad alt text and changes nothing", :aggregate_failures do
      was = stored[:code]
      save(code: "trip", files: { image[:id].to_s => { alt_text: "A\u0000cat" } })

      expect(last_response.status).to eq(422)
      expect(page).to have_css("#share-group-#{group.id}-file-#{image[:id]}-alt_text[aria-invalid='true']")
      expect([stored[:code], image[:alt_text]]).to eq([was, nil])
    end
  end

  describe "deleting" do
    def delete_group = post("/admin/files/groups/#{group.id}/delete", {}, csrf)

    it "removes the group, its code, its files and their objects", :aggregate_failures do
      removed = files.map { stub_request(:delete, share_store_url(it[:key])) }
      delete_group

      expect([Shares::Slice["relations.share_groups"].count, files.size]).to eq([0, 0])
      expect(Shares::Slice["relations.short_codes"].count).to eq(0)
      expect(removed).to all(have_been_requested)
    end

    it "says it deleted" do
      stub_request(:delete, %r{\A#{share_store_url}/})
      delete_group
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: "Group deleted")
    end

    describe "when the store fails on one object" do
      def fail_on(index)
        files.map.with_index do |file, at|
          stub = stub_request(:delete, share_store_url(file[:key]))
          at == index ? stub.to_return(status: 500) : stub
        end
      end

      it "removes the group when the second fails", :aggregate_failures do
        fail_on(1)
        delete_group
        follow_redirect!

        expect([Shares::Slice["relations.share_groups"].count, files.size]).to eq([0, 0])
        expect(page).to have_css("[data-toast]", text: "Group deleted")
      end

      it "still deletes the others when the first fails" do
        kept = fail_on(0).last
        delete_group

        expect(kept).to have_been_requested
      end
    end
  end
end

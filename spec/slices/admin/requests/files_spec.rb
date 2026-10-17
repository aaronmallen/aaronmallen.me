# frozen_string_literal: true

RSpec.describe "Admin files", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }

  def code(name) = Shares::Slice["relations.shares"].with_code.where(filename: name).one[:code]

  def file(bytes, name, type) = Rack::Test::UploadedFile.new(StringIO.new(bytes), type, original_filename: name)

  def json = JSON.parse(last_response.body)

  def lede(count, size) = i18n.t("ui.views.files.index.lede", count:, size:, host: "shares.localhost")

  def names = page.all(".file-card-name").map(&:text)

  def share(name, type = "text/plain", at: Time.now)
    upload_share("x" * 2048, name, type).value!.tap do |found|
      Shares::Slice["relations.shares"].by_pk(found.id).update(created_at: at)
    end
  end

  def shares = Shares::Slice["relations.shares"].to_a

  def upload(*files, accept: "text/html", group: "0", **env)
    post "/admin/files", { files:, group: }, { "HTTP_X_CSRF_TOKEN" => admin_csrf_token, "HTTP_ACCEPT" => accept, **env }
  end

  describe "signed in with a store" do
    before do
      sign_in_to_admin
      connect_share_store
      stub_request(:put, %r{\A#{share_store_url}/})
      stub_request(:head, %r{\A#{share_store_url}/})
    end

    it "lists the tab under Publish beside Links" do
      get "/admin/files"

      expect(page.all(".screen-tabs a.screen-tab").map { it[:href] })
        .to eq(%w[/admin/posts /admin/social /admin/files /admin/links])
    end

    it "says when nothing is shared yet" do
      get "/admin/files"

      expect(page).to have_css(".empty", text: i18n.t("ui.views.files.index.empty"))
    end

    describe "a card" do
      before do
        share("deck.pdf", "application/pdf")
        get "/admin/files"
      end

      let(:link) { "http://shares.localhost/#{code('deck.pdf')}" }

      it "shows the name, link, size, date and download count", :aggregate_failures do
        card = page.find(".file-card")

        expect(card).to have_css(".file-card-name", exact_text: "deck.pdf")
        expect(card).to have_css(".file-card-link", exact_text: link.delete_prefix("http://"))
        expect(card.find(".file-card-meta").text).to include("2 KB", "0 downloads")
        expect(card).to have_css(".file-card-thumb .fa-file-pdf")
      end

      it "copies and opens the share host link", :aggregate_failures do
        expect(page).to have_css(".file-card button[data-record-key='#{link}']", text: "Copy link")
        expect(page).to have_css(".file-card a[href='#{link}'][target='_blank']")
      end

      it "sums the files in the lede" do
        expect(page.find(".page-head-sub").text).to start_with("1 file shared on shares.localhost, 2 KB in all.")
      end

      it "says anyone with the link can open the file, and the link opens it signed out", :aggregate_failures do
        stub_request(:get, %r{\A#{share_store_url}/}).to_return(body: "x" * 2048)

        expect(page).to have_css(".page-head-sub", exact_text: lede(1, "2 KB"))
        expect(Rack::MockRequest.new(Shares::Slice["server"]).get("/#{code('deck.pdf')}").status).to eq(200)
      end
    end

    it "says anyone with a file's link can open it when there are several" do
      %w[deck.pdf notes.txt].each { share(it) }
      get "/admin/files"

      expect(page).to have_css(".page-head-sub", exact_text: lede(2, "4 KB"))
    end

    it "shows an image as a thumbnail with its alt text" do
      share("shot.png", "image/png")
      Shares::Slice["relations.shares"].update(alt_text: "A cat")
      get "/admin/files"

      expect(page).to have_css("img.file-card-thumb[alt='A cat'][src^='http://shares.localhost/']")
    end

    it "asks for a thumbnail as a preview the download count skips" do
      found = share("shot.png", "image/png")
      get "/admin/files"

      expect(page).to have_css("img.file-card-thumb[src='http://shares.localhost/#{found.code}?preview']")
    end

    describe "search and the filter" do
      before do
        share("notes.txt")
        share("photo.png", "image/png")
        share("clip.mp4", "video/mp4")
      end

      it "narrows by name" do
        get "/admin/files", search: "NOTES"

        expect(names).to eq(%w[notes.txt])
      end

      it "narrows by type", :aggregate_failures do
        get "/admin/files", search: "video"

        expect(names).to eq(%w[clip.mp4])
        expect(page).to have_css(".file-search .hint", text: "1 match")
      end

      it "narrows by code" do
        get "/admin/files", search: code("notes.txt")

        expect(names).to eq(%w[notes.txt])
      end

      it "keeps only images" do
        get "/admin/files", kind: "images"

        expect(names).to eq(%w[photo.png])
      end

      it "keeps everything but images" do
        get "/admin/files", kind: "other"

        expect(names).to contain_exactly("notes.txt", "clip.mp4")
      end

      it "keeps the search when filtering" do
        get "/admin/files", search: "notes"

        switch = "form:has([type=radio][name=kind])"

        expect(page).to have_css("#{switch} [type=hidden][name=search][value=notes]", visible: :hidden)
      end

      it "says when nothing matches" do
        get "/admin/files", search: "nothing"

        expect(page).to have_css(".empty", text: i18n.t("ui.views.files.index.no_match"))
      end
    end

    describe "paging" do
      before { 13.times { share("file-#{it}.txt", at: Time.utc(2026, 9, 1 + it)) } }

      it "shows the newest twelve and links to older files", :aggregate_failures do
        get "/admin/files", kind: "other"

        expect(names).to eq((1..12).map { "file-#{13 - it}.txt" })
        expect(page).to have_css("nav.pager a[rel='next'][href='/admin/files?kind=other&page=2']", text: "Older")
      end

      it "shows the rest on the next page with a link back", :aggregate_failures do
        get "/admin/files", kind: "other", page: "2"

        expect(names).to eq(%w[file-0.txt])
        expect(page).to have_css("nav.pager a[rel='prev'][href='/admin/files?kind=other']", text: "Newer")
      end

      it "returns 404 past the end" do
        get "/admin/files", page: "3"

        expect(last_response).to be_not_found
      end
    end

    describe "the upload form" do
      before { get "/admin/files" }

      it "posts multipart to the files route with a submit button for no script", :aggregate_failures do
        form = page.find("form.file-drop[action='/admin/files'][method='post'][enctype='multipart/form-data']")

        expect(form).to have_field("files[]", type: "file")
        expect(form).to have_unchecked_field("Share as one link")
        expect(form).to have_css("noscript", visible: :all)
      end
    end

    describe "uploading" do
      it "creates a share for each file and says so", :aggregate_failures do
        upload(file("a", "a.txt", "text/plain"), file("%PDF", "b.pdf", "application/pdf"))
        follow_redirect!

        expect(shares.map { it[:filename] }).to contain_exactly("a.txt", "b.pdf")
        expect(page).to have_css("[data-toast]", text: "2 files uploaded")
      end

      it "takes a file over the 1 MB form limit" do
        upload(file("a" * 2 * 1024 * 1024, "big.zip", "application/zip"))

        expect(shares.map { it[:byte_size] }).to eq([2 * 1024 * 1024])
      end

      it "takes a file over the 33 MB photo limit" do
        size = Blog::ParamsGuard::ENCODED_UPLOAD_LIMIT + 1
        upload(file("a" * size, "big.zip", "application/zip"))

        expect(shares.map { it[:byte_size] }).to eq([size])
      end

      it "refuses a body over Cloudflare's 100 MB limit", :aggregate_failures do
        allow(Rack::Multipart).to receive(:parse_multipart).and_call_original
        upload(file("a", "a.txt", "text/plain"), "CONTENT_LENGTH" => (Blog::ParamsGuard::SHARE_UPLOAD_LIMIT + 1).to_s)

        expect(last_response.status).to eq(413)
        expect(Rack::Multipart).not_to have_received(:parse_multipart)
        expect(shares).to be_empty
      end

      it "answers a script with the links", :aggregate_failures do
        upload(file("a", "a.txt", "text/plain"), accept: "application/json")

        expect(last_response.status).to eq(201)
        expect(json).to eq("links" => ["http://shares.localhost/#{code('a.txt')}"], "message" => "Uploaded")
      end

      describe "as one link" do
        let(:groups) { Shares::Slice["relations.share_groups"].with_code.to_a }

        let(:group_files) { Shares::Slice["relations.share_group_files"].to_a }

        def upload_group(**)
          upload(file("a", "a.txt", "text/plain"), file("%PDF", "b.pdf", "application/pdf"), group: "1", **)
        end

        it "makes one group with one code and no single shares", :aggregate_failures do
          upload_group

          expect(groups.size).to eq(1)
          expect(group_files.map { it[:filename] }).to contain_exactly("a.txt", "b.pdf")
          expect(shares).to be_empty
        end

        it "stores each file in the share bucket" do
          upload_group

          group_files.each { expect(a_request(:put, share_store_url(it[:key]))).to have_been_made }
        end

        it "says so" do
          upload_group
          follow_redirect!

          expect(page).to have_css("[data-toast]", text: "2 files uploaded as one link")
        end

        it "answers a script with the group's link", :aggregate_failures do
          upload_group(accept: "application/json")

          expect(last_response.status).to eq(201)
          expect(json["links"]).to eq(["http://shares.localhost/#{groups.first[:code]}"])
        end

        it "refuses a post with no file" do
          upload(group: "1", accept: "application/json")

          expect(last_response.status).to eq(422)
        end
      end

      it "makes one share per file when the box is left unticked", :aggregate_failures do
        upload(file("a", "a.txt", "text/plain"), file("b", "b.txt", "text/plain"), accept: "application/json")

        expect(json["links"]).to contain_exactly(
          "http://shares.localhost/#{code('a.txt')}", "http://shares.localhost/#{code('b.txt')}",
        )
        expect(Shares::Slice["relations.share_groups"].count).to eq(0)
      end

      it "refuses a post with no file", :aggregate_failures do
        upload(accept: "application/json")

        expect(last_response.status).to eq(422)
        expect(json["message"]).to eq(i18n.t("files_page.toasts.failed.blank"))
      end
    end

    describe "a drawer" do
      let!(:file) { share("deck.pdf", "application/pdf") }
      let(:drawer) { page.find("dialog#share-#{file.id}-drawer", visible: :all) }
      let(:confirm) { i18n.t("ui.components.files.share_form.confirm_delete", name: "deck.pdf") }

      def link = "http://shares.localhost/#{file.code}"

      before { get "/admin/files" }

      it "opens from the card's name, which links to the edit page without scripts" do
        expect(page).to have_css(
          ".file-card-name a[href='/admin/files/#{file.id}/edit'][data-dialog-open='share-#{file.id}-drawer']",
        )
      end

      it "shows the name, size, type, date and downloads", :aggregate_failures do
        expect(drawer).to have_css(".file-drawer-name", exact_text: "deck.pdf", visible: :all)
        expect(drawer.find(".file-drawer-meta", visible: :all).text(:all))
          .to include("2 KB", "application/pdf", "uploaded ", "0 downloads")
      end

      it "shows and copies the link", :aggregate_failures do
        expect(drawer).to have_css(".file-drawer-link", exact_text: link, visible: :all)
        expect(drawer).to have_css("button[data-record-key='#{link}']", visible: :all)
      end

      it "copies the file as a markdown link by its name" do
        expect(drawer).to have_css("button[data-record-key='[deck.pdf](#{link})']", visible: :all)
      end

      it "edits the name and the code but no alt text for a file that is no image", :aggregate_failures do
        expect(drawer).to have_field("share[filename]", with: "deck.pdf", visible: :all)
        expect(drawer).to have_field("share[code]", with: file.code, visible: :all)
        expect(drawer).to have_no_field("share[alt_text]", visible: :all)
        expect(drawer).to have_no_css("[data-record-key^='![']", visible: :all)
      end

      it "asks before it deletes", :aggregate_failures do
        expect(page).to have_css(
          "form#share-#{file.id}-delete[action='/admin/files/#{file.id}/delete'][data-confirm='#{confirm}']",
          visible: :all,
        )
        expect(drawer).to have_css("button[form='share-#{file.id}-delete']", visible: :all)
      end
    end

    describe "an image's drawer" do
      let(:file) { share("shot.png", "image/png") }
      let(:drawer) { page.find("dialog#share-#{file.id}-drawer", visible: :all) }

      before do
        Shares::Slice["relations.shares"].by_pk(file.id).update(alt_text: "A cat")
        get "/admin/files"
      end

      it "edits the alt text" do
        expect(drawer).to have_field("share[alt_text]", with: "A cat", visible: :all)
      end

      it "copies the image as markdown with its alt text" do
        markdown = "![A cat](http://shares.localhost/#{file.code})"

        expect(drawer).to have_css("button[data-record-key='#{markdown}']", visible: :all)
      end

      it "says the markdown I copy uses the alt text" do
        markdown = "![A cat](http://shares.localhost/#{file.code})"
        hint = i18n.t("ui.components.files.share_form.alt_text_hint")

        expect(drawer).to have_css("button[data-record-key='#{markdown}']", visible: :all)
          .and have_css(".hint", text: hint, visible: :all)
      end
    end

    it "escapes brackets and backslashes in the alt text it copies as markdown" do
      file = share("shot.png", "image/png")
      Shares::Slice["relations.shares"].by_pk(file.id).update(alt_text: "A [cat] \\ dog")
      get "/admin/files"
      copy = page.find("dialog#share-#{file.id}-drawer button[data-record-key^='!']", visible: :all)

      expect(copy["data-record-key"]).to eq("![A \\[cat\\] \\\\ dog](http://shares.localhost/#{file.code})")
    end

    describe "the edit page" do
      it "shows the form without scripts", :aggregate_failures do
        file = share("deck.pdf", "application/pdf")
        get "/admin/files/#{file.id}/edit"

        expect(page).to have_css("form[action='/admin/files/#{file.id}'] input[name='share[code]']")
        expect(page).to have_css("button[form='share-#{file.id}-form'][type='submit']")
      end

      it "answers 404 for a missing file" do
        get "/admin/files/0/edit"

        expect(last_response).to be_not_found
      end
    end

    describe "saving" do
      let(:file) { share("shot.png", "image/png") }
      let(:server) { Rack::MockRequest.new(Shares::Slice["server"]) }

      def error(reason) = i18n.t(reason, scope: "ui.components.files.field_error.code")

      def name_error(reason)
        i18n.t(reason, scope: "ui.components.files.field_error.filename", default: :"ui.field_error.#{reason}")
      end

      def save(**fields)
        post("/admin/files/#{file.id}", { share: fields }, { "HTTP_X_CSRF_TOKEN" => admin_csrf_token })
      end

      def stored = Shares::Slice["relations.shares"].with_code.by_pk(file.id).one.to_h.slice(:code, :alt_text)

      it "says it saved" do
        save(code: "resume", alt_text: "")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: i18n.t("files_page.toasts.saved"))
      end

      it "serves the file at the new code and no longer at the old one", :aggregate_failures do
        old = file.code
        stub_request(:get, share_store_url(file.key)).to_return(body: "x" * 2048)
        save(code: "resume", alt_text: "")

        expect(server.get("/resume").status).to eq(200)
        expect(server.get("/#{old}").status).to eq(404)
      end

      it "says a new code moves the link and the old one stops working" do
        old = file.code
        save(code: "resume", alt_text: "")
        get "/admin/files/#{file.id}/edit"

        expect([server.get("/#{old}").status, page.all(".hint").map(&:text)])
          .to match([404, include(i18n.t("ui.components.links.link_form.code_hint", host: "shares.localhost"))])
      end

      it "saves the alt text" do
        save(code: file.code, alt_text: "A cat")

        expect(stored[:alt_text]).to eq("A cat")
      end

      it "renames the file, which downloads under its new name at the same link", :aggregate_failures do
        stub_request(:get, share_store_url(file.key)).to_return(body: "x" * 2048)
        save(code: file.code, filename: " cat.png ")
        downloaded = server.get("/#{file.code}")

        expect(downloaded.status).to eq(200)
        expect(downloaded["content-disposition"]).to include('filename="cat.png"')
      end

      { "a blank name" => [" ", "blank"], "a name with a control character" => ["a\u0007.png", "control"] }
        .each do |name, (filename, reason)|
          it "refuses #{name} and keeps the old one", :aggregate_failures do
            save(code: file.code, filename:)

            expect([last_response.status, shares.find { it[:id] == file.id }[:filename]]).to eq([422, "shot.png"])
            expect(page).to have_css(".field-error", text: name_error(reason))
          end
        end

      { "a bad code" => ["Re Sume", "format"], "a blank code" => [" ", "blank"] }.each do |name, (code, reason)|
        it "refuses #{name} and changes nothing", :aggregate_failures do
          was = stored
          save(code:, alt_text: "A cat")

          expect(last_response.status).to eq(422)
          expect(page).to have_css(".field-error", text: error(reason))
          expect(stored).to eq(was)
        end
      end

      it "refuses a code another share holds" do
        save(code: share("deck.pdf").code)

        expect(page).to have_css(".field-error", text: error("taken"))
      end

      it "keeps the code when it refuses the alt text", :aggregate_failures do
        was = stored
        save(code: "resume", alt_text: "A\u0000cat")

        expect(last_response.status).to eq(422)
        expect(stored).to eq(was)
      end

      it "refuses a code a short link holds", :aggregate_failures do
        Shares::Slice["relations.short_codes"].command(:create).call(code: "resume")
        save(code: "resume", alt_text: "A cat")

        expect(page).to have_css("#share-#{file.id}-code[aria-invalid='true']")
        expect(stored[:alt_text]).to be_nil
      end
    end

    describe "deleting" do
      let(:file) { share("deck.pdf") }

      def delete_file = post("/admin/files/#{file.id}/delete", {}, { "HTTP_X_CSRF_TOKEN" => admin_csrf_token })

      it "removes the share, its code and its file", :aggregate_failures do
        removed = stub_request(:delete, share_store_url(file.key))
        delete_file

        expect(shares).to be_empty
        expect(Shares::Slice["relations.short_codes"].to_a).to be_empty
        expect(removed).to have_been_requested
      end

      it "says it deleted" do
        stub_request(:delete, share_store_url(file.key))
        delete_file
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: i18n.t("files_page.toasts.deleted"))
      end

      it "keeps the share when the store fails", :aggregate_failures do
        stub_request(:delete, share_store_url(file.key)).to_return(status: 500)
        delete_file
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: i18n.t("files_page.toasts.failed.delete"))
        expect(shares.size).to eq(1)
      end

      it "answers 404 for a missing file" do
        post "/admin/files/0/delete", {}, { "HTTP_X_CSRF_TOKEN" => admin_csrf_token }

        expect(last_response).to be_not_found
      end
    end
  end

  describe "with no store" do
    before { sign_in_to_admin }

    it "uploads nothing and says why", :aggregate_failures do
      upload(file("a", "a.txt", "text/plain"), accept: "application/json")

      expect(last_response.status).to eq(503)
      expect(shares).to be_empty
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Admin files", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }

  def code(name) = Shares::Slice["relations.shares"].with_code.where(filename: name).one[:code]

  def file(bytes, name, type) = Rack::Test::UploadedFile.new(StringIO.new(bytes), type, original_filename: name)

  def json = JSON.parse(last_response.body)

  def names = page.all(".file-card-name").map(&:text)

  def share(name, type = "text/plain", at: Time.now)
    upload_share("x" * 2048, name, type).value!.tap do |found|
      Shares::Slice["relations.shares"].by_pk(found.id).update(created_at: at)
    end
  end

  def shares = Shares::Slice["relations.shares"].to_a

  def upload(*files, accept: "text/html", **env)
    post "/admin/files", { files: }, { "HTTP_X_CSRF_TOKEN" => admin_csrf_token, "HTTP_ACCEPT" => accept, **env }
  end

  describe "signed in with a store" do
    before do
      sign_in_to_admin
      connect_share_store
      stub_request(:put, %r{\A#{share_store_url}/})
    end

    it "lists the tab under Publish beside Projects" do
      get "/admin/files"

      expect(page.all(".screen-tabs a.screen-tab").map { it[:href] })
        .to eq(%w[/admin/posts /admin/social /admin/projects /admin/files])
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
    end

    it "shows an image as a thumbnail with its alt text" do
      share("shot.png", "image/png")
      Shares::Slice["relations.shares"].update(alt_text: "A cat")
      get "/admin/files"

      expect(page).to have_css("img.file-card-thumb[alt='A cat'][src^='http://shares.localhost/']")
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

      it "refuses a post with no file", :aggregate_failures do
        upload(accept: "application/json")

        expect(last_response.status).to eq(422)
        expect(json["message"]).to eq(i18n.t("files_page.toasts.failed.blank"))
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

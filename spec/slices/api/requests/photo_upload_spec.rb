# frozen_string_literal: true

require "base64"

RSpec.describe "API photo upload", type: :request do
  let(:stored) { {} }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def bytes_of(name) = Hanami.app.root.join("spec/fixtures/photos", name).binread

  def claims_of(owner) = Media::Slice["relations.photo_claims"].where(owner:).to_a.map { it[:photo_id] }

  def keep_puts
    stub_request(:put, store_url).to_return do |request|
      stored[File.basename(request.uri.path)] = { body: request.body.b, content_type: request.headers["Content-Type"] }
      { status: 200 }
    end
  end

  def message(key) = Admin::Slice["i18n"].t(key, scope: "photo_upload.errors")

  def photos = Media::Slice["relations.photos"].to_a

  def refusal(key) = { "error" => "invalid", "message" => message(key), "errors" => { "data" => [message(key)] } }

  def send_photo(fields, token: api_token)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    post "/api/v1/photos", JSON.generate(fields), headers
    JSON.parse(last_response.body)
  end

  def status = last_response.status

  def store_url = %r{\Ahttps://store\.example(?::443)?/photos/[0-9a-f]{32}\.[a-z]+\z}

  def upload(bytes = nil, data: Base64.strict_encode64(bytes), filename: "photo.png", token: api_token)
    send_photo({ data:, filename: }, token:)
  end

  def url_of(key) = Hanami.app.settings.site_url("/media/#{key}")

  shared_examples "a refusal" do |code, key|
    it "answers #{code} with the admin's reason" do
      expect([answered, status]).to eq([refusal(key), code])
    end

    it "stores nothing", :aggregate_failures do
      answered
      expect(stored).to be_empty
      expect(photos).to be_empty
    end
  end

  describe "POST /api/v1/photos" do
    before do
      connect_media_store
      keep_puts
    end

    { "animated.gif" => "gif", "rotated_with_gps.jpg" => "jpg", "small.png" => "png", "animated.webp" => "webp",
      "photo.heic" => "jpg" }.each do |name, extension|
      it "stores #{name} as #{extension.upcase}" do
        upload(bytes_of(name), filename: name)

        expect([status, stored.keys.first]).to match([201, end_with(".#{extension}")])
      end

      it "answers #{name} with its URL and size" do
        answered = upload(bytes_of(name), filename: name)
        row = photos.first

        expect(answered).to eq("url" => url_of(row[:key]), "width" => row[:width], "height" => row[:height])
      end
    end

    it "answers the size it stored" do
      expect(upload(bytes_of("rotated_with_gps.jpg")).slice("width", "height")).to eq("width" => 20, "height" => 40)
    end

    it "judges the photo by its bytes, not its name" do
      upload(bytes_of("rotated_with_gps.jpg"), filename: "photo.png")

      expect(stored.keys.first).to end_with(".jpg")
    end

    it "sends the store no checksum header it does not need" do
      upload(bytes_of("small.png"))

      expect(a_request(:put, store_url).with { it.headers.keys.grep(/checksum/i).empty? }).to have_been_made
    end

    it "waits 30 seconds for the store to answer" do
      expect(Media::Slice["store.client"].instance_variable_get(:@connection).config.http_read_timeout).to eq(30)
    end

    it "takes base64 broken across lines" do
      upload(data: Base64.encode64(bytes_of("small.png")))

      expect([status, photos.size]).to eq([201, 1])
    end

    describe "blank data" do
      let(:answered) { upload(data: "") }

      it_behaves_like "a refusal", 422, "blank"
    end

    describe "data over 20 MB" do
      let(:answered) { upload("\xFF\xD8\xFF".b + ("\0" * Media::Contracts::PhotoContract::MAX_BYTES)) }

      it_behaves_like "a refusal", 422, "large"
    end

    describe "a photo over 100 megapixels" do
      let(:answered) { upload(bytes_of("huge.png")) }

      it_behaves_like "a refusal", 422, "oversized"
    end

    describe "an SVG" do
      let(:answered) { upload(%(<svg xmlns="http://www.w3.org/2000/svg"></svg>), filename: "a.svg") }

      it_behaves_like "a refusal", 422, "type"
    end

    describe "a file that only starts like a JPEG" do
      let(:answered) { upload("#{"\xFF\xD8\xFF".b}not a photo", filename: "photo.jpg") }

      it_behaves_like "a refusal", 422, "unreadable"
    end

    describe "data that is not base64" do
      let(:answered) { upload(data: "not*base64!") }

      it_behaves_like "a refusal", 422, "unreadable"
    end

    describe "a store that fails" do
      let(:answered) do
        stub_request(:put, store_url).to_timeout
        upload(bytes_of("small.png"))
      end

      it "answers 503 with the admin's reason" do
        expect([answered, status])
          .to eq([{ "error" => "unavailable", "message" => message("unavailable") }, 503])
      end

      it "keeps no row" do
        answered
        expect(photos).to be_empty
      end
    end

    it "refuses a request with no file name" do
      expect([send_photo({ data: "" }).fetch("errors"), status]).to eq([{ "filename" => ["filename is missing"] }, 422])
    end

    it "refuses a request with no token and stores nothing", :aggregate_failures do
      upload(bytes_of("small.png"), token: nil)

      expect(status).to eq(401)
      expect(stored).to be_empty
    end
  end

  shared_examples "no store" do
    it "answers 503 with the admin's reason" do
      expect([upload(bytes_of("small.png")), status])
        .to eq([{ "error" => "unavailable", "message" => message("unavailable") }, 503])
    end

    it "reaches no store" do
      upload(bytes_of("small.png"))

      expect(a_request(:any, /.*/)).not_to have_been_made
    end
  end

  describe "with no store" do
    it_behaves_like "no store"
  end

  describe "with an endpoint that does not parse" do
    before { connect_media_store(endpoint: "not a url") }

    it_behaves_like "no store"
  end

  describe "the MCP tool" do
    before do
      connect_media_store
      keep_puts
    end

    def fields_of(name) = { data: Base64.strict_encode64(bytes_of(name)), filename: name }

    def tool_upload(name = "small.png") = mcp_answer("upload_photo", **fields_of(name))

    it "answers as upload_photo does, less the random key" do
      answered = upload(bytes_of("small.png"))

      expect(unstamped(tool_upload).except("url")).to eq(unstamped(answered).except("url"))
    end

    it "answers with the URL of the photo it stored" do
      expect(tool_upload.fetch("url")).to eq(url_of(photos.first[:key]))
    end

    it "refuses with the message the endpoint gives" do
      refused = upload(data: "")

      expect(mcp_text("upload_photo", data: "", filename: "photo.png")).to eq(refused.fetch("message"))
    end

    it "refuses when the store is down with the message the endpoint gives" do
      stub_request(:put, store_url).to_timeout

      expect(mcp_text("upload_photo", **fields_of("small.png"))).to eq(message("unavailable"))
    end

    it "lets a journal entry saved through MCP claim the photo" do
      url = tool_upload.fetch("url")
      mcp_answer("create_journal_entry", body: "![A photo](#{url})")

      expect(claims_of("journal_entry")).to eq([photos.first[:id]])
    end

    it "lets a post saved through MCP claim the photo" do
      url = tool_upload.fetch("url")
      mcp_answer("create_post", title: "Hello", body: "![A photo](#{url})")

      expect(claims_of("post")).to eq([photos.first[:id]])
    end
  end
end

# frozen_string_literal: true

require "tempfile"

RSpec.describe "Admin photo upload", type: :request do
  let(:stored) { {} }

  def file_of(bytes, name)
    file = Tempfile.new(["upload", File.extname(name)], binmode: true)
    file.write(bytes)
    file.flush
    Rack::Test::UploadedFile.new(file.path, "image/jpeg", true, original_filename: name)
  end

  def fixture(name, type = "application/octet-stream")
    Rack::Test::UploadedFile.new(Hanami.app.root.join("spec/fixtures/photos", name), type)
  end

  def image = Vips::Image.new_from_buffer(stored.values.first.fetch(:body), "")

  def json = JSON.parse(last_response.body)

  def keep_puts
    stub_request(:put, store_url).to_return do |request|
      stored[File.basename(request.uri.path)] = { body: request.body.b, content_type: request.headers["Content-Type"] }
      { status: 200 }
    end
  end

  def message(key) = Admin::Slice["i18n"].t(key)

  def photos = Media::Slice["relations.photos"].to_a

  def store_url = %r{\Ahttps://store\.example(?::443)?/photos/[0-9a-f]{32}\.[a-z]+\z}

  def upload(file, token: admin_csrf_token)
    post "/admin/photos", { photo: file }, { "HTTP_X_CSRF_TOKEN" => token, "HTTP_ACCEPT" => "application/json" }
  end

  shared_examples "a refusal" do |status, key|
    it "answers #{status} with the reason", :aggregate_failures do
      expect(last_response.status).to eq(status)
      expect(json).to eq("error" => message(key))
    end

    it "stores nothing", :aggregate_failures do
      expect(stored).to be_empty
      expect(photos).to be_empty
    end
  end

  describe "signed in with a store" do
    before do
      sign_in_to_admin
      connect_media_store
      keep_puts
    end

    describe "a JPEG with GPS data and a rotation tag" do
      before { upload(fixture("rotated_with_gps.jpg", "image/jpeg")) }

      it "answers 201 with the photo's absolute URL", :aggregate_failures do
        expect(last_response.status).to eq(201)
        expect(json.fetch("url")).to eq(Blog::Site.url("/media/#{stored.keys.first}"))
      end

      it "stores it under a random key as a JPEG", :aggregate_failures do
        expect(stored.keys.first).to match(/\A[0-9a-f]{32}\.jpg\z/)
        expect(stored.values.first[:content_type]).to eq("image/jpeg")
      end

      it "stores it upright" do
        expect(image).to have_attributes(width: 20, height: 40)
      end

      it "strips its metadata", :aggregate_failures do
        expect(image.get_fields).not_to include("exif-data", "orientation", "xmp-data", "iptc-data")
        expect(stored.values.first[:body]).not_to include("Exif")
      end

      it "keeps a row for it with no owner" do
        expect(photos.map(&:to_h)).to contain_exactly(
          include(key: stored.keys.first, width: 20, height: 40, byte_size: stored.values.first[:body].bytesize),
        )
      end
    end

    describe "a HEIC photo" do
      before { upload(fixture("photo.heic")) }

      it "stores it as a JPEG", :aggregate_failures do
        expect(last_response.status).to eq(201)
        expect(stored.keys.first).to end_with(".jpg")
        expect(stored.values.first[:content_type]).to eq("image/jpeg")
        expect(stored.values.first[:body]).to start_with("\xFF\xD8\xFF".b)
      end
    end

    describe "a photo with a long edge over 2560px" do
      before { upload(fixture("large.png", "image/png")) }

      it "shrinks its long edge to 2560px and keeps its shape" do
        expect(image).to have_attributes(width: 2560, height: 853)
      end
    end

    describe "a photo under 2560px" do
      before { upload(fixture("small.png", "image/png")) }

      it "keeps its size" do
        expect(image).to have_attributes(width: 32, height: 24)
      end
    end

    { "gif" => "image/gif", "webp" => "image/webp" }.each do |extension, type|
      describe "an animated #{extension.upcase}" do
        before { upload(fixture("animated.#{extension}")) }

        it "stores it as #{extension.upcase}", :aggregate_failures do
          expect(last_response.status).to eq(201)
          expect(stored.keys.first).to end_with(".#{extension}")
          expect(stored.values.first[:content_type]).to eq(type)
        end

        it "keeps every frame at its size", :aggregate_failures do
          frames = Vips::Image.new_from_buffer(stored.values.first.fetch(:body), "", n: -1)

          expect(frames.get("n-pages")).to eq(3)
          expect(frames.get("page-height")).to eq(24)
          expect(frames.width).to eq(32)
        end

        it "keeps a row with one frame's height" do
          expect(photos.map(&:to_h)).to contain_exactly(include(width: 32, height: 24))
        end
      end
    end

    describe "a photo over 100 megapixels" do
      before { upload(fixture("huge.png", "image/png")) }

      it_behaves_like "a refusal", 422, "photo_upload.errors.oversized"
    end

    describe "a JPEG named as a PNG" do
      before { upload(file_of(Hanami.app.root.join("spec/fixtures/photos/rotated_with_gps.jpg").binread, "photo.png")) }

      it "judges it by its bytes" do
        expect(stored.keys.first).to end_with(".jpg")
      end
    end

    describe "a file over 20 MB" do
      before { upload(file_of("\xFF\xD8\xFF".b + ("\0" * Media::Contracts::PhotoContract::MAX_BYTES), "big.jpg")) }

      it_behaves_like "a refusal", 422, "photo_upload.errors.large"
    end

    describe "an SVG" do
      before { upload(file_of(%(<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>), "a.svg")) }

      it_behaves_like "a refusal", 422, "photo_upload.errors.type"
    end

    describe "a file whose bytes match no allowed type" do
      before { upload(file_of("just some text", "photo.jpg")) }

      it_behaves_like "a refusal", 422, "photo_upload.errors.type"
    end

    describe "a file that only starts like a JPEG" do
      before { upload(file_of("#{"\xFF\xD8\xFF".b}not a photo", "photo.jpg")) }

      it_behaves_like "a refusal", 422, "photo_upload.errors.unreadable"
    end

    describe "no file" do
      before { post "/admin/photos", { photo: "" }, { "HTTP_X_CSRF_TOKEN" => admin_csrf_token } }

      it_behaves_like "a refusal", 422, "photo_upload.errors.blank"
    end

    describe "a store that fails" do
      before do
        stub_request(:put, store_url).to_timeout
        upload(fixture("small.png", "image/png"))
      end

      it_behaves_like "a refusal", 503, "photo_upload.errors.unavailable"
    end

    it "refuses an upload without a CSRF token" do
      upload(fixture("small.png", "image/png"), token: nil)

      expect(last_response).to be_forbidden
    end
  end

  describe "signed in with no store" do
    before do
      sign_in_to_admin
      upload(fixture("small.png", "image/png"))
    end

    it_behaves_like "a refusal", 503, "photo_upload.errors.unavailable"
  end

  describe "signed out" do
    let(:session_token) do
      get "/admin/sign-in"
      last_request.env["rack.session"]["_csrf_token"]
    end

    before do
      connect_media_store
      keep_puts
      upload(fixture("small.png", "image/png"), token: session_token)
    end

    it "redirects to sign-in" do
      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "stores nothing", :aggregate_failures do
      expect(stored).to be_empty
      expect(photos).to be_empty
    end
  end
end

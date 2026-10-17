# frozen_string_literal: true

RSpec.describe Shares::Operations::UploadShare do
  let(:stored) { {} }

  def keep_puts
    stub_request(:put, %r{\A#{share_store_url}/}).to_return do |request|
      stored[File.basename(request.uri.path)] = { body: request.body.b, content_type: request.headers["Content-Type"] }
      { status: 200 }
    end
  end

  def photo = File.binread(Hanami.app.root.join("spec/fixtures/photos/rotated_with_gps.jpg"))

  def shares = Shares::Slice["relations.shares"].to_a

  describe "with a store" do
    before do
      connect_share_store
      keep_puts
    end

    {
      "a PDF" => ["%PDF-1.7\n%\xE2\xE3\xCF\xD3\n1 0 obj\n<<>>\nendobj\n%%EOF\n".b, "deck.pdf", "application/pdf"],
      "a zip" => ["PK\x03\x04\x14\x00\x00\x00\x00\x00".b + Random.bytes(64), "files.zip", "application/zip"],
      "an mp4" => ["\x00\x00\x00\x18ftypmp42".b + Random.bytes(64), "clip.mp4", "video/mp4"],
    }.each do |name, (bytes, filename, type)|
      it "stores #{name} byte for byte under a three character code", :aggregate_failures do
        share = upload_share(bytes, filename, type).value!

        expect(share.code).to match(/\A[abcdefghjkmnpqrstuvwxyz23456789]{3}\z/)
        expect(share).to have_attributes(filename:, content_type: type, byte_size: bytes.bytesize, download_count: 0)
        expect(stored.fetch(share.key)).to eq(body: bytes, content_type: type)
      end
    end

    it "keeps a JPEG's camera and GPS data", :aggregate_failures do
      share = upload_share(photo, "IMG_0001.JPG", "image/jpeg").value!

      expect(stored.fetch(share.key)[:body]).to eq(photo)
      expect(stored.fetch(share.key)[:body]).to include("Exif")
    end

    it "keeps the share out of the media bucket and the photos table", :aggregate_failures do
      upload_share(photo, "IMG_0001.JPG", "image/jpeg")

      expect(a_request(:any, /store\.example/)).not_to have_been_made
      expect(Media::Slice["relations.photos"].count).to eq(0)
    end

    it "calls a file sent with no type an octet stream" do
      expect(upload_share("data", "blob", "").value!.content_type).to eq("application/octet-stream")
    end

    it "tries a new code when the first is taken", :aggregate_failures do
      Shares::Slice["relations.short_codes"].insert(code: "aaa")
      allow(Shares::Helpers::Code).to receive(:pick).and_return("aaa", "bbb")

      expect(upload_share.value!.code).to eq("bbb")
      expect(shares.size).to eq(1)
    end

    it "refuses a file with no name and stores nothing", :aggregate_failures do
      expect(upload_share("data", " ", "text/plain").failure).to eq([:invalid, { filename: ["blank"] }])
      expect(shares).to be_empty
      expect(stored).to be_empty
    end

    it "saves nothing when the store fails", :aggregate_failures do
      stub_request(:put, %r{\A#{share_store_url}/}).to_return(status: 500)

      expect(upload_share.failure).to eq([:unavailable])
      expect(shares).to be_empty
      expect(Shares::Slice["relations.short_codes"].count).to eq(0)
    end
  end

  it "refuses an upload with no store" do
    expect(upload_share.failure).to eq([:unavailable])
  end
end

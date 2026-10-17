# frozen_string_literal: true

RSpec.describe "API reading a photo", type: :request do
  let(:bytes) { Hanami.app.root.join("spec/fixtures/photos/rotated_with_gps.jpg").binread }
  let(:photo) { create(:photo, width: 20, height: 40, byte_size: bytes.bytesize) }

  def read(reference)
    get "/api/v1/photos", { photo: reference },
        { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    JSON.parse(last_response.body)
  end

  describe "with the store connected" do
    before do
      connect_media_store
      stub_request(:get, media_store_url(photo.key)).to_return(body: bytes, headers: { "Content-Type" => "image/jpeg" })
    end

    it "answers the photo's details and its bytes in base64 with a 200" do
      details = { "key" => photo.key, "width" => 20, "height" => 40, "byte_size" => bytes.bytesize }

      expect([read(photo.key), status])
        .to eq([details.merge("content_type" => "image/jpeg", "data" => Base64.strict_encode64(bytes)), 200])
    end

    it "takes the photo's URL" do
      expect(read("https://aaronmallen.me/photos/#{photo.key}").fetch("key")).to eq(photo.key)
    end

    it "answers a key the site does not keep with a 404" do
      expect([read("missing.jpg").fetch("message"), status]).to eq(["no photo has the key missing.jpg", 404])
    end
  end

  it "answers with a 503 when the store is not set up" do
    read(photo.key)

    expect(status).to eq(503)
  end
end

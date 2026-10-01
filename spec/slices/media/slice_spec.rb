# frozen_string_literal: true

RSpec.describe Media::Slice do
  let(:client) { described_class["store.client"] }
  let(:key) { "a1b2c3.jpg" }
  let(:url) { media_store_url(key) }

  def checksum_headers(request) = request.headers.keys.grep(/checksum/i)

  describe "with no store settings" do
    it "boots with a client that is not configured" do
      expect(client).not_to be_configured
    end

    it "reaches no store" do
      client.put(key, "photo", content_type: "image/jpeg")
      client.get(key)
      client.delete(key)

      expect(a_request(:any, /.*/)).not_to have_been_made
    end
  end

  describe "with an endpoint that does not parse" do
    before { connect_media_store(endpoint: "not a url") }

    it "leaves the client not configured" do
      expect(client).not_to be_configured
    end
  end

  describe "with store settings" do
    before { connect_media_store }

    it "reports the client configured" do
      expect(client).to be_configured
    end

    it "stores a photo under its key in the bucket" do
      stub_request(:put, url)

      client.put(key, "photo", content_type: "image/jpeg")

      expect(a_request(:put, url).with(body: "photo", headers: { "Content-Type" => "image/jpeg" })).to have_been_made
    end

    it "sends no checksum header the request does not need" do
      stub_request(:put, url)

      client.put(key, "photo", content_type: "image/jpeg")

      expect(a_request(:put, url).with { checksum_headers(it).empty? }).to have_been_made
    end

    it "reads a stored photo with its content type" do
      stub_request(:get, url).to_return(body: "photo", headers: { "Content-Type" => "image/png" })

      expect(client.get(key)).to have_attributes(body: "photo", content_type: "image/png")
    end

    it "answers nil for a key the store does not hold" do
      missing = "<Error><Code>NoSuchKey</Code><Message>The specified key does not exist.</Message></Error>"
      stub_request(:get, url).to_return(status: 404, body: missing)

      expect(client.get(key)).to be_nil
    end

    it "deletes a photo by its key" do
      stub_request(:delete, url).to_return(status: 204)

      client.delete(key)

      expect(a_request(:delete, url)).to have_been_made
    end

    it "raises its own error when the store does not answer" do
      stub_request(:get, url).to_timeout

      expect { client.get(key) }.to raise_error(Media::Store::Client::Error)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "MCP photo tools", type: :request do
  describe "read_photo" do
    let(:bytes) { Hanami.app.root.join("spec/fixtures/photos/rotated_with_gps.jpg").binread }
    let(:photo) { create(:photo, width: 20, height: 40, byte_size: bytes.bytesize) }

    def blocks(reference = photo.key) = mcp_call("read_photo", photo: reference)

    def image(reference = photo.key) = blocks(reference).fetch("content").find { it.fetch("type") == "image" }

    def refusal(reference) = blocks(reference).values_at("isError", "content")

    def stub_store(**response) = stub_request(:get, media_store_url(photo.key)).to_return(**response)

    def text(reference = photo.key) = blocks(reference).fetch("content").find { it.fetch("type") == "text" }

    describe "with the store connected" do
      before do
        connect_media_store
        stub_store(body: bytes, headers: { "Content-Type" => "image/jpeg" })
      end

      it "answers the stored bytes as one image block", :aggregate_failures do
        shown = image

        expect(shown.slice("type", "mimeType")).to eq("type" => "image", "mimeType" => "image/jpeg")
        expect(Base64.strict_decode64(shown.fetch("data"))).to eq(bytes)
      end

      it "answers the key, width, height and byte size in one text block" do
        expect(JSON.parse(text.fetch("text")))
          .to eq("key" => photo.key, "width" => 20, "height" => 40, "byte_size" => bytes.bytesize)
      end

      it "answers one image block and one text block" do
        expect(blocks.fetch("content").map { it.fetch("type") }).to eq(%w[image text])
      end

      it "takes the photo's URL" do
        expect(JSON.parse(text(photo.url).fetch("text")).fetch("key")).to eq(photo.key)
      end

      it "shows a photo no published post claims" do
        Media::Slice["relations.photo_claims"].command(:create)
                                              .call(owner: "post", owner_id: create(:post,
                                                                                    :draft).id, photo_id: photo.id)

        expect(image.fetch("mimeType")).to eq("image/jpeg")
      end

      it "refuses a key the site does not keep and names it" do
        missing = "#{'f' * 32}.png"

        expect(refusal("https://aaronmallen.me/media/#{missing}"))
          .to eq([true, [{ "type" => "text", "text" => "no photo has the key #{missing}" }]])
      end
    end

    it "refuses when the store is not set up" do
      expect(refusal(photo.key).last.first.fetch("text")).to include("not set up or did not answer")
    end

    it "refuses when the store does not answer" do
      connect_media_store
      stub_store(status: 500)

      expect(refusal(photo.key)).to eq([true, [{ "type" => "text", "text" => MCP::Tools::ReadPhoto::UNAVAILABLE }]])
    end
  end
end

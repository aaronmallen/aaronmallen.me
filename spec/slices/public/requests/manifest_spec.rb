# frozen_string_literal: true

RSpec.describe "Web manifest", type: :request do
  def asset(source) = Hanami.app["assets"][source].url

  def icon(source, sizes) = { "src" => asset(source), "sizes" => sizes, "type" => "image/png" }

  def manifest = JSON.parse(last_response.body)

  describe "GET /site.webmanifest" do
    before { get "/site.webmanifest" }

    it "answers as a web manifest" do
      expect(last_response.media_type).to eq("application/manifest+json")
    end

    it "lists the 192px and 512px icons by their fingerprinted URLs" do
      expect(manifest["icons"]).to eq([icon("icon-192.png", "192x192"), icon("icon-512.png", "512x512")])
    end
  end

  it "answers a browser that accepts anything" do
    get "/site.webmanifest", {}, "HTTP_ACCEPT" => "*/*"

    expect(last_response.media_type).to eq("application/manifest+json")
  end

  it "names the site after the owner the settings give" do
    allow(Hanami.app.settings).to receive(:owner).and_return({ name: "Ada Lovelace" })
    get "/site.webmanifest"

    expect(manifest).to include("name" => "Ada Lovelace", "short_name" => "Ada Lovelace")
  end
end

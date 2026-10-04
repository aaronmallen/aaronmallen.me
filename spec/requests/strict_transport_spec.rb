# frozen_string_literal: true

RSpec.describe "Strict transport", type: :request do
  let(:app) { Rack::Builder.parse_file(Hanami.app.root.join(".config/config.ru").to_s) }

  before { allow(Hanami).to receive(:boot) }

  def strict_transport = last_response.headers["Strict-Transport-Security"]

  context "when the site runs in production" do
    before { allow(Hanami).to receive(:env).and_return(:production) }

    it "tells the browser to keep to HTTPS for a year on a page" do
      get "/"

      expect(strict_transport).to eq("max-age=31536000")
    end

    it "tells the browser on a static file" do
      get "/favicon.ico"

      expect(strict_transport).to eq("max-age=31536000")
    end

    it "tells the browser on a request the site refuses", :aggregate_failures do
      get "/", {}, "QUERY_STRING" => "a=%"

      expect(last_response.status).to eq(400)
      expect(strict_transport).to eq("max-age=31536000")
    end

    it "tells the browser on the MCP server" do
      get "/.well-known/oauth-authorization-server"

      expect(strict_transport).to eq("max-age=31536000")
    end
  end

  context "when the site runs in development" do
    before { allow(Hanami).to receive(:env).and_return(:development) }

    it "leaves the header off" do
      get "/"

      expect(strict_transport).to be_nil
    end
  end
end

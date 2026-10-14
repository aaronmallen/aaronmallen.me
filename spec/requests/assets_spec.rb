# frozen_string_literal: true

RSpec.describe "Assets", type: :request do
  def asset(source) = Hanami.app["assets"][source].url

  %w[app.css app.js favicon.svg].each do |source|
    describe "GET #{source}" do
      before { get asset(source) }

      it "serves a fingerprinted name" do
        expect(asset(source)).to match(%r{\A/assets/.+-[A-Z0-9]{8}\.\w+\z})
      end

      it "lets browsers and Cloudflare keep it for a year" do
        expect(last_response.headers["Cache-Control"]).to eq("public, max-age=31536000, immutable")
      end
    end
  end

  describe "GET a fingerprinted name that is not there" do
    before { get "/assets/app-AAAAAAAA.css" }

    it "answers 404" do
      expect(last_response).to be_not_found
    end

    it "keeps the miss out of every cache" do
      expect(last_response.headers["Cache-Control"]).to be_nil
    end
  end

  describe "GET the manifest" do
    before { get "/assets/assets.json" }

    it "serves it" do
      expect(last_response).to be_ok
    end

    it "keeps it out of every cache" do
      expect(last_response.headers["Cache-Control"]).to be_nil
    end
  end
end

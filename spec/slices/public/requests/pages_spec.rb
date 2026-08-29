# frozen_string_literal: true

RSpec.describe "Public pages", type: :request do
  before do
    %i[analytics bluesky github mastodon maxmind].each do |name|
      allow(Hanami.app.settings).to receive(name).and_return({})
    end
  end

  %w[/ /about /contact /projects /writing].each do |path|
    it "renders #{path} with every credential blank" do
      get path

      expect(last_response).to be_ok
    end

    it "sets no cookie on #{path}" do
      get path

      expect(last_response.headers["set-cookie"]).to be_nil
    end
  end
end

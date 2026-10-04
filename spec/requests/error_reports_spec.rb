# frozen_string_literal: true

RSpec.describe "An error raised in a request", type: :request do
  let(:agent) { Honeybadger::Agent.instance }
  let(:app) { Hanami.app }
  let(:crash) { RuntimeError.new("boom") }

  before do
    Hanami.app.start(:honeybadger)
    allow(agent).to receive(:notify).and_call_original
  end

  context "when a public action raises" do
    before { replace_component("posts.queries.published_page", ->(_page) { raise crash }) }

    def read_writing
      get "/writing"
    rescue crash.class
      nil
    end

    it "raises the error again" do
      expect { get "/writing" }.to raise_error(crash)
    end

    it "tells Honeybadger what the action raised" do
      read_writing

      expect(agent).to have_received(:notify).with(crash)
    end
  end

  context "when the app answers" do
    it "tells Honeybadger nothing" do
      get "/about"

      expect(agent).not_to have_received(:notify)
    end
  end
end

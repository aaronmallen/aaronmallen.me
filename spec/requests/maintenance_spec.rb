# frozen_string_literal: true

RSpec.describe "Maintenance mode", type: :request do
  let(:app) { Rack::Builder.parse_file(Hanami.app.root.join(".config/config.ru").to_s) }
  let(:flag) { Hanami.app.root.join("tmp/maintenance-#{SecureRandom.hex}").to_s }
  let(:hooks) { [] }

  before do
    allow(Hanami).to receive(:boot)
    allow(Hanami.app.settings).to receive(:maintenance).and_return(flag_path: flag)
    allow(connection).to receive(:synchronize).and_call_original
  end

  after { FileUtils.rm_f(flag) }

  def connection = Hanami.app["db.rom"].gateways[:default].connection

  def fetch(path, **env) = get(path, {}, { "rack.after_reply" => hooks }.merge(env))

  shared_examples "a maintenance reply" do
    it "answers 503" do
      expect(last_response.status).to eq(503)
    end

    it "keeps it from every cache" do
      expect(last_response.headers["Cache-Control"]).to eq("no-store")
    end

    it "tells the client when to try again" do
      expect(last_response.headers["Retry-After"]).to eq("300")
    end

    it "opens no database connection" do
      expect(connection).not_to have_received(:synchronize)
    end

    it "records no request timing" do
      expect(hooks).to be_empty
    end
  end

  shared_examples "the maintenance page" do
    it_behaves_like "a maintenance reply"

    it "answers the page", :aggregate_failures do
      expect(last_response.content_type).to start_with("text/html")
      expect(page).to have_css("h1", text: "Down for maintenance")
    end

    it "links nowhere" do
      expect(page).to have_no_css("a")
    end
  end

  shared_examples "the JSON reply" do
    it_behaves_like "a maintenance reply"

    it "answers JSON" do
      expect(JSON.parse(last_response.body)).to include("error" => "temporarily_unavailable")
    end
  end

  context "when the flag file exists" do
    before { FileUtils.touch(flag) }

    describe "a public page" do
      before { fetch "/" }

      it_behaves_like "the maintenance page"
    end

    describe "an admin page" do
      before { fetch "/admin" }

      it_behaves_like "the maintenance page"
    end

    describe "the share host" do
      before { fetch "/abc", "HTTP_HOST" => "shares.localhost" }

      it_behaves_like "the maintenance page"
    end

    describe "the MCP sign-in page" do
      before { fetch "/oauth/authorize" }

      it_behaves_like "the maintenance page"
    end

    describe "an API request" do
      before { fetch "/api/v1/posts" }

      it_behaves_like "the JSON reply"
    end

    describe "an MCP request" do
      before { post "/mcp", "{}", "CONTENT_TYPE" => "application/json", "rack.after_reply" => hooks }

      it_behaves_like "the JSON reply"
    end

    describe "the MCP token endpoint" do
      before { post "/oauth/token", {}, "rack.after_reply" => hooks }

      it_behaves_like "the JSON reply"
    end

    describe "the MCP metadata" do
      before { fetch "/.well-known/oauth-authorization-server" }

      it_behaves_like "the JSON reply"
    end

    it "ends once the file is gone", :aggregate_failures do
      fetch "/"
      expect(last_response.status).to eq(503)

      FileUtils.rm(flag)
      fetch "/"

      expect(last_response.status).to eq(200)
    end
  end

  context "when the flag file is absent" do
    before { fetch "/" }

    it "serves the page" do
      expect(last_response.status).to eq(200)
    end

    it "records the request timing" do
      expect(hooks).not_to be_empty
    end

    it "uses the database connection" do
      expect(connection).to have_received(:synchronize).at_least(:once)
    end
  end
end

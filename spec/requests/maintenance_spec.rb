# frozen_string_literal: true

RSpec.describe "Maintenance mode", type: :request do
  let(:app) { Rack::Builder.parse_file(Hanami.app.root.join(".config/config.ru").to_s) }
  let(:flag) { File.join(Dir.tmpdir, "maintenance-#{SecureRandom.hex}") }
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

    describe "the owner cookie" do
      let(:served) { File.read(Hanami.app.root.join("public/503.html")) }

      def deactivate(**env) = post("/maintenance/deactivate", {}, { "rack.after_reply" => hooks }.merge(env))

      def owner(cookie) = { "HTTP_COOKIE" => "#{Blog::Maintenance::COOKIE}=#{Rack::Utils.escape(cookie)}" }

      def pass(at = File.mtime(flag)) = Blog::Maintenance.pass(Hanami.app.settings.app_secret, at)

      context "when it is valid" do
        before { fetch "/", **owner(pass) }

        it_behaves_like "the maintenance page"

        it "offers the Deactivate button" do
          form = page.find("form[method='post'][action='/maintenance/deactivate']")

          expect(form).to have_button("Deactivate maintenance mode")
        end
      end

      it "keeps the JSON reply for an API request" do
        fetch "/api/v1/posts", **owner(pass)

        expect(last_response.body).to eq(Blog::Maintenance::JSON_BODY)
      end

      {
        "missing" => {},
        "forged" => { "HTTP_COOKIE" => "#{Blog::Maintenance::COOKIE}=#{Time.now.to_i * 1000}--#{'0' * 64}" },
        "garbled" => { "HTTP_COOKIE" => "#{Blog::Maintenance::COOKIE}=nonsense" },
      }.each do |name, cookie|
        it "serves today's page when the cookie is #{name}" do
          fetch("/", **cookie)

          expect(last_response.body).to eq(served)
        end
      end

      it "serves today's page when the cookie predates the flag file" do
        fetch "/", **owner(pass(File.mtime(flag) - 1))

        expect(last_response.body).to eq(served)
      end

      describe "deactivating" do
        before { deactivate(**owner(pass)) }

        it "removes the flag file" do
          expect(File).not_to exist(flag)
        end

        it "clears the cookie" do
          expect(last_response.headers["Set-Cookie"]).to start_with("#{Blog::Maintenance::COOKIE}=; path=/; max-age=0")
        end

        it "lands on Settings", :aggregate_failures do
          expect(last_response.status).to eq(303)
          expect(last_response.location).to eq("/admin/settings/security")
        end

        it "opens no database connection" do
          expect(connection).not_to have_received(:synchronize)
        end
      end

      describe "deactivating without a cookie" do
        before { deactivate }

        it_behaves_like "the maintenance page"

        it "leaves the flag file in place" do
          expect(File).to exist(flag)
        end
      end

      describe "deactivating with a stale cookie" do
        before { deactivate(**owner(pass(File.mtime(flag) - 1))) }

        it_behaves_like "the maintenance page"

        it "leaves the flag file in place" do
          expect(File).to exist(flag)
        end
      end
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

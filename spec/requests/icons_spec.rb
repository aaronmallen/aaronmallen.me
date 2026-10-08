# frozen_string_literal: true

RSpec.describe "Icons", type: :request do
  def asset(source) = Hanami.app["assets"][source].url

  def authorize_path
    client = Spec::DB::Factories[:mcp].create(:oauth_client)
    params = {
      client_id: client.client_id,
      code_challenge: MCP::OAuth::PKCE.challenge(Blog::Types::NewSecret[]),
      code_challenge_method: "S256",
      redirect_uri: client.redirect_uris.first,
      resource: "https://aaronmallen.me/mcp",
      response_type: "code",
      scope: "read",
    }
    "/oauth/authorize?#{Rack::Utils.build_query(params)}"
  end

  def have_tag(selector) = have_css(selector, visible: :all)

  def head = Capybara.string(last_response.body).find("head", visible: :all)

  {
    "the public site" => -> { get "/" },
    "the admin" => -> { get "/admin/sign-in" },
    "the MCP screens" => lambda do
      sign_in_to_admin
      get authorize_path
    end,
  }.each do |place, visit|
    describe "a page in #{place}" do
      before { instance_exec(&visit) }

      it "links the SVG icon" do
        expect(head).to have_tag("link[rel='icon'][type='image/svg+xml'][href='#{asset('favicon.svg')}']")
      end

      it "links the ICO fallback" do
        expect(head).to have_tag("link[rel='icon'][href='#{asset('favicon.ico')}']")
      end

      it "links the apple-touch-icon" do
        expect(head).to have_tag("link[rel='apple-touch-icon'][href='#{asset('apple-touch-icon.png')}']")
      end

      it "links the web manifest" do
        expect(head).to have_tag("link[rel='manifest'][href='/site.webmanifest']")
      end
    end
  end

  describe "GET /favicon.ico" do
    before { get "/favicon.ico" }

    it "answers 200" do
      expect(last_response.status).to eq(200)
    end

    it "answers as an icon" do
      expect(last_response.content_type).to eq("image/vnd.microsoft.icon")
    end

    it "serves the rendered ICO" do
      expect(last_response.body.b).to eq(Hanami.app.root.join("app/assets/images/favicon.ico").binread)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "An unknown failure reason", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def document = JSON.parse(last_response.body)

  def refuse(key, operation, reason = :gone_wrong)
    replace_component(key, instance_double(operation, call: Dry::Monads::Failure(reason)))
  end

  describe "an admin action" do
    before { sign_in_to_admin }

    it "answers 500 rather than raising" do
      token = admin_csrf_token
      project = create(:project)
      refuse("projects.operations.archive_project", Projects::Operations::ArchiveProject)
      post "/admin/projects/#{project.id}/archive", _csrf_token: token

      expect(last_response.status).to eq(500)
    end

    it "answers 500 for a reason carrying a payload" do
      token = admin_csrf_token
      project = create(:project)
      refuse("projects.operations.archive_project", Projects::Operations::ArchiveProject, [:gone_wrong, {}])
      post "/admin/projects/#{project.id}/archive", _csrf_token: token

      expect(last_response.status).to eq(500)
    end
  end

  describe "the sign-in callback" do
    before do
      stub_github_sign_in
      refuse("operations.sign_in", Admin::Operations::SignIn)
      get "/admin/sign-in"
      state = Rack::Utils.parse_query(URI(last_response.location).query).fetch("state")
      get "/admin/auth/github/callback", code: "code", state:
    end

    it "answers 500 rather than raising" do
      expect(last_response.status).to eq(500)
    end

    it "says the sign-in did not finish" do
      expect(page.text).to include(Admin::Slice["i18n"].t("ui.views.sessions.failed.unexpected"))
    end
  end

  describe "the MCP endpoint" do
    before do
      refuse("operations.authenticate", MCP::Operations::Authenticate)
      headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer nope" }
      post "/mcp", JSON.generate({ jsonrpc: "2.0", id: 1, method: "tools/list" }), headers
    end

    it "still refuses the request" do
      expect(last_response.status).to eq(401)
    end

    it "names the request as the problem" do
      expect(document["error"]).to eq("invalid_request")
    end

    it "still points at the resource metadata" do
      expect(last_response.headers["WWW-Authenticate"]).to include("resource_metadata=")
    end
  end

  describe "the token endpoint" do
    before do
      refuse("operations.issue_token", MCP::Operations::IssueToken)
      post "/oauth/token", grant_type: "authorization_code"
    end

    it "answers 400 rather than raising" do
      expect(last_response.status).to eq(400)
    end

    it "names the request as the problem" do
      expect(document["error"]).to eq("invalid_request")
    end
  end

  describe "the registration endpoint" do
    before do
      refuse("operations.register_client", MCP::Operations::RegisterClient)
      body = JSON.generate({ redirect_uris: %w[https://claude.ai/callback] })
      post "/oauth/register", body, "CONTENT_TYPE" => "application/json"
    end

    it "answers 400 rather than raising" do
      expect(last_response.status).to eq(400)
    end

    it "names the request as the problem" do
      expect(document["error"]).to eq("invalid_request")
    end
  end

  describe "the authorization endpoint" do
    before do
      refuse("operations.authorize", MCP::Operations::Authorize)
      get "/oauth/authorize", client_id: "whoever", response_type: "code"
    end

    it "answers 400 rather than raising" do
      expect(last_response.status).to eq(400)
    end

    it "names the request as the problem" do
      expect(document["error"]).to eq("invalid_request")
    end
  end
end

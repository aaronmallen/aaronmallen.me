# frozen_string_literal: true

RSpec.describe "CSRF protection", type: :request do
  def cookie(slice) = sessions(slice).options.first.except(:coder)

  def sessions(slice) = slice.config.actions.sessions

  describe "a signed-out admin form" do
    let(:session_token) do
      get "/admin/sign-in"
      last_request.env["rack.session"]["_csrf_token"]
    end

    it "is refused without a token before it is sent to sign in" do
      post "/admin/projects", project: { name: "sneaky" }

      expect(last_response.status).to eq(403)
    end

    it "is sent to sign in with the session's token" do
      post "/admin/projects", project: { name: "sneaky" }, _csrf_token: session_token

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "saves nothing" do
      post "/admin/projects", project: { name: "sneaky" }

      expect(Projects::Slice["repos.project_repo"].live).to be_empty
    end
  end

  describe "the session cookie" do
    it "is the one cookie both slices read" do
      expect(cookie(MCP::Slice)).to eq(cookie(Admin::Slice))
    end

    it "is the cookie the shared config names" do
      expect(cookie(Admin::Slice)).to include(key: Blog::SessionCookie::KEY)
    end

    it "is stored the way the shared config says" do
      expect(sessions(MCP::Slice).storage).to eq(Blog::SessionCookie.store.first)
    end
  end

  describe "the admin forms the kit draws" do
    let(:page) { Capybara.string(last_response.body) }

    def field_values(form) = form.all("input[name='_csrf_token']", visible: :all).map(&:value)

    def post_forms = page.all("form[method='post']", visible: :all)

    before { sign_in_to_admin }

    %w[
      /admin /admin/journal /admin/people/new /admin/posts/new /admin/projects/new /admin/tags /admin/tasks
    ].each do |path|
      it "carries the session's token once in every POST form on #{path}" do
        get path

        expect(post_forms.map { field_values(it) }).to include([admin_csrf_token]).and all(eq([admin_csrf_token]))
      end
    end

    it "signs out through the form the today page draws" do
      get "/admin"
      form = page.find("main form[action='/admin/sign-out']", visible: :all)
      post("/admin/sign-out", form.all("input[type='hidden']", visible: :all).to_h { [it[:name], it.value] })

      expect(last_response.location).to eq("/")
    end
  end

  describe "an admin form without a token" do
    before do
      sign_in_to_admin
      post "/admin/projects", project: { name: "sneaky" }
    end

    it "is refused" do
      expect(last_response.status).to eq(403)
    end

    it "tells every cache not to store the refusal" do
      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end

    it "keeps the browser from indexing the refusal" do
      expect(last_response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end

    it "saves nothing" do
      expect(Projects::Slice["repos.project_repo"].live).to be_empty
    end
  end

  describe "an admin form with a token that is not a string" do
    let(:agent) { Hanami.app["honeybadger.agent"] }
    let(:page) { Capybara.string(last_response.body) }

    before do
      allow(agent).to receive(:notify).and_call_original
      sign_in_to_admin
      post "/admin/projects", project: { name: "sneaky" }, _csrf_token: [admin_csrf_token]
    end

    it "is refused" do
      expect(last_response.status).to eq(403)
    end

    it "answers the page a missing token gets" do
      expect(page).to have_css("h1", exact_text: Admin::Slice["i18n"].t("ui.views.forms.rejected.heading"))
    end

    it "saves nothing" do
      expect(Projects::Slice["repos.project_repo"].live).to be_empty
    end

    it "sends no notice" do
      expect(agent).not_to have_received(:notify)
    end
  end

  describe "an MCP approval without a token" do
    let(:client) { Spec::DB::Factories[:mcp].create(:oauth_client) }

    def approval
      {
        client_id: client.client_id,
        decision: "approve",
        redirect_uri: client.redirect_uris.first,
        response_type: "code",
      }
    end

    before do
      sign_in_to_admin
      post "/oauth/authorize", approval
    end

    it "is refused" do
      expect(last_response.status).to eq(403)
    end

    it "issues no code" do
      expect(MCP::Slice["db.rom"].relations[:oauth_codes].to_a).to be_empty
    end
  end

  describe "an MCP approval with a token that is not a string" do
    let(:agent) { Hanami.app["honeybadger.agent"] }
    let(:client) { Spec::DB::Factories[:mcp].create(:oauth_client) }
    let(:page) { Capybara.string(last_response.body) }

    def approval
      {
        _csrf_token: [admin_csrf_token],
        client_id: client.client_id,
        decision: "approve",
        redirect_uri: client.redirect_uris.first,
        response_type: "code",
      }
    end

    before do
      allow(agent).to receive(:notify).and_call_original
      sign_in_to_admin
      post "/oauth/authorize", approval
    end

    it "is refused" do
      expect(last_response.status).to eq(403)
    end

    it "answers the page a missing token gets" do
      heading = MCP::Slice["i18n"].t("ui.views.authorizations.rejected.heading")

      expect(page).to have_css("h1", exact_text: heading)
    end

    it "issues no code" do
      expect(MCP::Slice["db.rom"].relations[:oauth_codes].to_a).to be_empty
    end

    it "sends no notice" do
      expect(agent).not_to have_received(:notify)
    end
  end
end

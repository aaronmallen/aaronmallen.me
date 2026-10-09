# frozen_string_literal: true

RSpec.describe "Admin connected services", type: :request do
  def add_connection(provider, account_id, label, credentials: { api_key: "lin_api_secret" }, **)
    Services::Slice["repos.connection_mutations"].add(provider:, account_id:, label:, credentials:, **)
  end

  def connect(provider = "linear", **connection)
    post("/admin/services/#{provider}", connection:, _csrf_token: admin_csrf_token)
  end

  def connections = Services::Slice["repos.connection_queries"].for(:linear)

  def fail_sync(name)
    Record::Slice["repos.sync_state_mutations"].record_failure(Blog::Types::SyncName[name], :unreachable)
  end

  def group(label) = page.find(".svc-group", text: label)

  def names(label) = group(label).all(".li-title").map(&:text)

  def page = Capybara.string(last_response.body)

  def pickable = page.all("#connect-service .svc-pick .svc-line-name", visible: :all).map(&:text)

  def row(name) = page.find(".li", text: name)

  def toast = page.find("[data-toast]").text

  describe "signed out" do
    it "sends me to sign-in" do
      get "/admin/services"

      expect(last_response.location).to end_with("/admin/sign-in")
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "heads the tab as Settings and titles it Connected services", :aggregate_failures do
      get "/admin/services"

      expect(page).to have_css(".page-head h1", exact_text: "Settings")
      expect(page).to have_title("Connected services | Admin | #{Hanami.app.settings.owner_name}")
    end

    it "lists the services that need no sign-in in their groups", :aggregate_failures do
      get "/admin/services"

      expect(names("Social")).to eq(["Bridgy"])
      expect(names("Infrastructure")).to eq(["Backup store", "Honeybadger", "MaxMind", "Media store"])
    end

    it "puts every service I can connect in the picker and none in the list", :aggregate_failures do
      get "/admin/services"

      expect(pickable).to eq(%w[GitHub Linear Bluesky Mastodon])
      expect(page).to have_no_css(".svc-group", text: "Available")
    end

    describe "with two Linear workspaces" do
      before do
        add_connection("linear", "ws-1", "ROOT workspace")
        add_connection("linear", "ws-2", "Hanakai workspace")
        get "/admin/services"
      end

      it "shows one row per workspace with its name", :aggregate_failures do
        expect(names("Code and sign-in")).to eq(%w[Linear Linear])
        expect(page.all(".svc-account").map(&:text)).to include("ROOT workspace", "Hanakai workspace")
      end

      it "keeps Linear in the picker for a third" do
        expect(pickable).to include("Linear")
      end
    end

    it "skips a connection whose service has no definition" do
      add_connection("myspace", "tom", "Tom")
      get "/admin/services"

      expect(page).to have_no_text("Tom")
    end

    describe "a service a spec defines, with no migration" do
      before do
        fake = Services::Definition.new(
          id: "fake", name: "Fakebook", icon: "fa-solid fa-ghost", group: "social", auth: "credentials",
          fields: %w[token], powers: ["Nothing at all"],
        )
        queries = Services::Repos::DefinitionQueries
        replace_component("services.repos.definition_queries", queries.new([*queries.new.all, fake]))
      end

      it "leaves it out of the picker while the site has no check for it" do
        get "/admin/services"

        expect(pickable).not_to include("Fakebook")
      end

      it "offers no form while the site has no check for it" do
        get "/admin/services?connect=fake"

        expect(page).to have_no_css("form[action='/admin/services/fake']")
      end

      it "refuses a connect while the site has no check for it" do
        connect("fake", token: "abcd")

        expect(last_response.status).to eq(404)
      end

      it "shows in its group once an account connects" do
        add_connection("fake", "1", "ghost")
        get "/admin/services"

        expect(names("Social")).to include("Fakebook")
      end
    end

    describe "status" do
      it "marks an environment service not set up while a key is missing" do
        get "/admin/services"

        expect(row("Honeybadger")).to have_css(".pill", text: "not set up")
      end

      it "marks an environment service connected once every key is set" do
        settings = Hanami.app["settings"]
        allow(settings).to receive(:honeybadger).and_return(api_key: "hbp_key", project_url: "https://hb.test")
        get "/admin/services"

        expect(row("Honeybadger")).to have_css(".pill", text: "connected")
      end

      it "pauses Bridgy while the webmention toggle is off", :aggregate_failures do
        get "/admin/services"
        expect(row("Bridgy")).to have_css(".pill", text: "connected")

        Social::Slice["operations.update_webmention_settings"].call(accept_bridgy: false)
        get "/admin/services"
        expect(row("Bridgy")).to have_css(".pill", text: "paused")
      end

      describe "when a job fails" do
        before do
          add_connection("linear", "ws-1", "ROOT workspace")
          fail_sync("linear_issues")
          get "/admin/services"
        end

        it "marks the service failing and counts it", :aggregate_failures do
          expect(row("Linear")).to have_css(".pill", text: "failing")
          expect(page).to have_css(".settings-count", text: "1 failing")
        end

        it "names the failure at a glance" do
          expect(page).to have_css(".settings-side .sync-failure")
        end
      end
    end

    describe "the detail panel" do
      it "says what to do while nothing is picked" do
        get "/admin/services"

        expect(page).to have_css(".settings-side", text: "Click a service to see what it powers")
      end

      it "opens a picked service and closes it from its row", :aggregate_failures do
        get "/admin/services?selected=maxmind"

        expect(page).to have_css(".settings-side .card-title", text: "MaxMind")
        expect(page).to have_css(".settings-side li", text: "Countries in Analytics")
        expect(page).to have_css(".settings-side .svc-line", text: "GeoIP database download")
        expect(row("MaxMind")).to have_css("a.li-title[aria-current='true'][href='/admin/services']")
      end

      it "shows each environment key as set or missing and never its value", :aggregate_failures do
        allow(Hanami.app["settings"]).to receive(:maxmind).and_return(account_id: "acct-31337", license_key: nil)
        get "/admin/services?selected=maxmind"

        expect(page.find(".svc-line", text: "MAXMIND_ACCOUNT_ID")).to have_css(".pill", text: "set")
        expect(page.find(".svc-line", text: "MAXMIND_LICENSE_KEY")).to have_css(".pill", text: "missing")
        expect(last_response.body).not_to include("acct-31337")
      end

      it "opens a connected account by its id with the scopes it holds", :aggregate_failures do
        connection = add_connection("mastodon", "1", "@aaron", host: "ruby.social", scopes: ["write:statuses"])
        get "/admin/services?selected=#{connection.id}"

        expect(page.find(".svc-line", text: "Post on your behalf")).to have_css(".pill", text: "granted")
        expect(page.find(".svc-line", text: "Look up accounts")).to have_css(".pill", text: "not granted")
      end

      it "sends Bridgy to the webmention toggle" do
        get "/admin/services?selected=bridgy"

        expect(page).to have_link("webmentions →", href: "/admin/webmentions#webmention-settings")
      end
    end
  end

  describe "connecting Linear" do
    before { sign_in_to_admin }

    it "offers a key form from the picker", :aggregate_failures do
      get "/admin/services"
      expect(page).to have_css("#connect-service a.svc-pick[href='/admin/services?connect=linear']", visible: :all)

      get "/admin/services?connect=linear"
      expect(page).to have_css(".settings-side form[action='/admin/services/linear'] input[type='password']")
    end

    describe "with a key Linear accepts" do
      before do
        stub_linear(LinearGraphQL::WORKSPACE_QUERY, linear_workspace("ws-root", "ROOT"), key: "lin_api_root")
        connect(api_key: " lin_api_root ")
      end

      it "saves the workspace under its name with the key sealed", :aggregate_failures do
        expect(connections.map { [it.account_id, it.label, it.credentials] })
          .to eq([["ws-root", "ROOT", { api_key: "lin_api_root" }]])
      end

      it "opens the new row with a toast", :aggregate_failures do
        expect(last_response.location).to end_with("/admin/services?selected=#{connections.first.id}")
        follow_redirect!
        expect(toast).to include("Linear connected as ROOT")
        expect(page).to have_css(".settings-side .svc-account", text: "ROOT")
      end
    end

    it "saves nothing for a key Linear refuses and says why", :aggregate_failures do
      stub_linear(LinearGraphQL::WORKSPACE_QUERY, linear_errors("AUTHENTICATION_ERROR", "Authentication required"))
      connect(api_key: "lin_api_bad")

      expect(last_response.status).to eq(422)
      expect(page).to have_css(".settings-side .field-error", text: "Authentication required")
      expect(connections).to be_empty
    end

    it "saves nothing for a blank key", :aggregate_failures do
      connect(api_key: "  ")

      expect(page).to have_css(".field-error", text: "Paste a key first")
      expect(a_request(:post, LinearGraphQL::URL)).not_to have_been_made
      expect(connections).to be_empty
    end

    it "saves nothing for a workspace the site already holds", :aggregate_failures do
      stub_linear(LinearGraphQL::WORKSPACE_QUERY, linear_workspace("ws-root", "ROOT"))
      connect(api_key: "lin_api_root")
      connect(api_key: "lin_api_root_again")

      expect(page).to have_css(".field-error", text: "That account is already connected")
      expect(connections.size).to eq(1)
    end

    describe "a second workspace" do
      let(:sources) { Tasks::Slice["relations.task_sources"].where(provider: "linear") }

      before do
        stub_linear(LinearGraphQL::WORKSPACE_QUERY, linear_workspace("ws-root", "ROOT"), key: "lin_api_root")
        stub_linear(LinearGraphQL::WORKSPACE_QUERY, linear_workspace("ws-hana", "Hanakai"), key: "lin_api_hana")
        stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(linear_issue("L_one")), key: "lin_api_root")
        stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(linear_issue("L_two", key: "XYZ-2")),
                    key: "lin_api_hana")
        stub_linear(LinearGraphQL::ISSUES_QUERY, linear_issues)
      end

      def connect_and_sync(api_key)
        connect(api_key:)
        Tasks::Jobs::SyncLinearIssues.new.perform
      end

      it "joins the issue sync with no restart", :aggregate_failures do
        connect_and_sync("lin_api_root")
        connect_and_sync("lin_api_hana")

        expect(connections.map(&:label)).to contain_exactly("ROOT", "Hanakai")
        expect(sources.pluck(:remote_id)).to contain_exactly("L_one", "L_two")
      end
    end
  end

  describe "a connected Linear workspace" do
    let(:connection) { add_connection("linear", "ws-root", "ROOT", credentials: { api_key: "lin_api_root" }) }

    before { sign_in_to_admin }

    it "offers a test, another account and a disconnect", :aggregate_failures do
      get "/admin/services?selected=#{connection.id}"

      expect(page).to have_css("form[action='/admin/services/#{connection.id}/test']")
      expect(page).to have_link("Add another account", href: "/admin/services?connect=linear")
      expect(page).to have_css("form[action='/admin/services/#{connection.id}/disconnect'][data-confirm]")
    end

    it "reports that Linear answers a test" do
      stub_linear(LinearGraphQL::WORKSPACE_QUERY, linear_workspace("ws-root", "ROOT"), key: "lin_api_root")
      post "/admin/services/#{connection.id}/test", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(toast).to include("Linear answered")
    end

    it "reports that Linear refuses a test" do
      stub_linear(LinearGraphQL::WORKSPACE_QUERY, linear_errors("AUTHENTICATION_ERROR", "Authentication required"))
      post "/admin/services/#{connection.id}/test", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(toast).to include("Linear isn't answering", "Authentication required")
    end

    it "deletes the row on disconnect", :aggregate_failures do
      post "/admin/services/#{connection.id}/disconnect", _csrf_token: admin_csrf_token

      expect(last_response.location).to end_with("/admin/services")
      expect(connections).to be_empty
    end

    it "answers not found for a disconnect of a row that is gone" do
      post "/admin/services/31337/disconnect", _csrf_token: admin_csrf_token

      expect(last_response.status).to eq(404)
    end
  end

  describe "stored credentials" do
    it "seals them so the table holds no plain text", :aggregate_failures do
      connection = add_connection("linear", "ws-1", "ROOT workspace")
      raw = Services::Slice["relations.service_connections"].by_pk(connection.id).dataset.get(:credentials)

      expect(raw).not_to include("lin_api_secret")
      expect(JSON.parse(Blog::Encryptor.new.open(raw))).to eq("api_key" => "lin_api_secret")
    end

    it "reads them back through the lookup" do
      add_connection("linear", "ws-1", "ROOT workspace")

      expect(Services::Slice["repos.connection_queries"].for(:linear).map(&:credentials))
        .to eq([{ api_key: "lin_api_secret" }])
    end
  end
end

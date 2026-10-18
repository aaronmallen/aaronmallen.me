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
    sync_state_mutations.record_failure(Blog::Types::SyncName[name], :unreachable)
  end

  def form_action = last_response.headers["Content-Security-Policy"][/form-action [^;]*/]

  def group(label) = page.find(".svc-group", text: label)

  def moved(**params) = get("/admin/services", params).then { last_response.location }

  def names(label) = group(label).all(".li-title").map(&:text)

  def pick(provider) = "#connect-service a.svc-pick[href='/admin/settings/services?connect=#{provider}#services']"

  def pickable = page.all("#connect-service .svc-pick .svc-line-name", visible: :all).map(&:text)

  def row(name) = page.find(".li", text: name)

  describe "signed in" do
    before { sign_in_to_admin }

    it "lets the connect form follow its redirect to an authorize page on any https origin" do
      get "/admin/settings/services"

      expect(form_action).to eq("form-action 'self' https:")
    end

    it "keeps the wider form-action when it shows the form again after a refusal", :aggregate_failures do
      connect(connection: { api_key: "" })

      expect(last_response.status).to eq(422)
      expect(form_action).to eq("form-action 'self' https:")
    end

    it "keeps form-action to my own origin on the other admin screens" do
      get "/admin/tasks"

      expect(form_action).to eq("form-action 'self'")
    end

    it "draws the services, the API tokens and the MCP clients on the tab, in that order" do
      get "/admin/settings/services"

      expect(page.all(".settings-section").map { it[:id] }).to eq(%w[services tokens clients])
    end

    it "counts the connected services on the tab label" do
      add_connection("linear", "acct-1", "Workspace")
      get "/admin/settings/services"

      shown = page.all(".svc-list .li").size
      expect(page.find("a.screen-tab[aria-current='page']")).to have_text("connected services #{shown}")
    end

    it "counts the same services on the tab label from another tab" do
      add_connection("linear", "acct-1", "Workspace")
      get "/admin/settings/services"
      shown = page.all(".svc-list .li").size
      get "/admin/settings/security"

      expect(page.find("a.screen-tab", text: "connected services")).to have_text("connected services #{shown}")
    end

    it "sends the old address to its section of the tab, keeping the pick" do
      expect([moved, moved(selected: "maxmind"), moved(connect: "linear")])
        .to eq(%w[/admin/settings/services#services /admin/settings/services?selected=maxmind#services
                  /admin/settings/services?connect=linear#services])
    end

    it "opens its section of the tab from the command palette" do
      get "/admin"

      expect(page).to have_css("[data-palette-href='/admin/settings/services#services']", visible: :all)
    end

    it "heads the tab as Settings and titles it Connected services", :aggregate_failures do
      get "/admin/settings/services"

      expect(page).to have_css(".page-head h1", exact_text: "Settings")
      expect(page).to have_title("Connected services | Admin | #{Hanami.app.settings.owner_name}")
    end

    it "lists the services that need no sign-in in their groups", :aggregate_failures do
      get "/admin/settings/services"

      expect(names("Social")).to eq(%w[Bridgy LinkedIn])
      expect(names("Infrastructure")).to eq(["Backup store", "Honeybadger", "MaxMind", "Media store"])
    end

    it "puts every service I can connect in the picker and none in the list", :aggregate_failures do
      get "/admin/settings/services"

      expect(pickable).to eq(%w[GitHub Linear Bluesky Mastodon])
      expect(page).to have_no_css(".svc-group", text: "Available")
    end

    describe "with two Linear workspaces" do
      before do
        add_connection("linear", "ws-1", "ROOT workspace")
        add_connection("linear", "ws-2", "Hanakai workspace")
        get "/admin/settings/services"
      end

      it "shows one row per workspace with its name", :aggregate_failures do
        expect(names("Code and sign-in")).to eq(%w[Linear Linear])
        expect(page.all(".svc-account").map(&:text)).to include("ROOT workspace", "Hanakai workspace")
      end

      it "keeps Linear in the picker for a third" do
        expect(pickable).to include("Linear")
      end
    end

    it "dots the account and the last use apart" do
      add_connection("linear", "ws-1", "ROOT workspace", last_used_at: Time.now - 3600)
      get "/admin/settings/services"

      expect(row("ROOT workspace").find(".li-sub").text).to start_with("ROOT workspace · ")
    end

    it "skips a connection whose service has no definition" do
      add_connection("myspace", "tom", "Tom")
      get "/admin/settings/services"

      expect(page).to have_no_text("Tom")
    end

    describe "a service a spec defines, with no migration" do
      before do
        fake = Services::Structs::Definition.new(
          id: "fake", name: "Fakebook", icon: "fa-solid fa-ghost", group: "social", auth: "credentials",
          fields: %w[token], powers: ["Nothing at all"],
        )
        queries = Services::Repos::DefinitionQueries
        replace_component("services.repos.definition_queries", queries.new([*queries.new.all, fake]))
      end

      it "leaves it out of the picker while the site has no check for it" do
        get "/admin/settings/services"

        expect(pickable).not_to include("Fakebook")
      end

      it "offers no form while the site has no check for it" do
        get "/admin/settings/services?connect=fake"

        expect(page).to have_no_css("form[action='/admin/services/fake#services']")
      end

      it "refuses a connect while the site has no check for it" do
        connect("fake", token: "abcd")

        expect(last_response.status).to eq(404)
      end

      it "shows in its group once an account connects" do
        add_connection("fake", "1", "ghost")
        get "/admin/settings/services"

        expect(names("Social")).to include("Fakebook")
      end
    end

    describe "status" do
      it "marks an environment service not set up while a key is missing" do
        get "/admin/settings/services"

        expect(row("Honeybadger")).to have_css(".pill", text: "not set up")
      end

      it "marks an environment service connected once every key is set" do
        settings = Hanami.app["settings"]
        allow(settings).to receive(:honeybadger).and_return(api_key: "hbp_key", project_url: "https://hb.test")
        get "/admin/settings/services"

        expect(row("Honeybadger")).to have_css(".pill", text: "connected")
      end

      it "pauses Bridgy while the webmention toggle is off", :aggregate_failures do
        get "/admin/settings/services"
        expect(row("Bridgy")).to have_css(".pill", text: "connected")

        Social::Slice["operations.update_webmention_settings"].call(accept_bridgy: false)
        get "/admin/settings/services"
        expect(row("Bridgy")).to have_css(".pill", text: "paused")
      end

      describe "when a job fails" do
        before do
          add_connection("linear", "ws-1", "ROOT workspace")
          fail_sync("linear_issues")
          get "/admin/settings/services"
        end

        it "marks the service failing and counts it", :aggregate_failures do
          expect(row("Linear")).to have_css(".pill", text: "failing")
          expect(page).to have_css(".settings-count", text: "1 failing")
        end

        it "names the failure at a glance" do
          expect(page).to have_css(".settings-side .sync-failure")
        end

        it "names the job as the failure banner does" do
          get "/admin/settings/services?selected=#{connections.first.id}"

          expect(page.find(".settings-side .sync-failure").text).to start_with(page.find(".svc-job").text)
        end
      end

      it "has a sync label for every job" do
        syncs = Services::Slice["repos.definition_queries"].all.flat_map(&:jobs).map { it[:sync].to_sym }

        expect(syncs - Admin::Slice["i18n"].t("ui.components.sync_failures.syncs").keys).to be_empty
      end
    end

    describe "the hints" do
      def every(job) = Fugit::Cron.parse(sidekiq_config.dig(:scheduler, :schedule, job, "cron")).rough_frequency

      def hint(key) = Admin::Slice["i18n"].t(["ui", key].join("."))

      def hints(scope) = page.all("#{scope} .hint", visible: :all).map { it.text(:all) }

      def raw(connection)
        Services::Slice["relations.service_connections"].by_pk(connection.id).dataset.get(:credentials)
      end

      it "says connected services keep their tokens encrypted and the rest read the server environment" do
        connection = add_connection("linear", "ws-1", "ROOT workspace")
        get "/admin/settings/services"

        expect([raw(connection).include?("lin_api_secret"), row("Honeybadger").text, hints(".svc-list")])
          .to match([false, include("not set up"), include(hint("components.services.list.hint"))])
      end

      it "says a picked service shows what it powers and how often its jobs run" do
        shown = get("/admin/settings/services").then { hints(".settings-side") }
        get "/admin/settings/services?selected=maxmind"

        expect([page.find(".svc-line", text: "Country database refresh").text, every("refresh_country_database"),
                shown])
          .to match([include("weekly"), 7 * 86_400, include(hint("components.services.list.pick_hint"))])
      end

      it "says the picker leaves out the services set in the server environment" do
        get "/admin/settings/services"
        env_only = ["Media store", "Backup store", "MaxMind", "Honeybadger"]

        expect([pickable & env_only, hints("#connect-service")])
          .to match([[], include(hint("components.services.picker.hint"))])
      end

      it "says an environment service's keys live in the server environment", :aggregate_failures do
        allow(Hanami.app["settings"]).to receive(:maxmind).and_return(account_id: "acct-31337", license_key: nil)
        get "/admin/settings/services?selected=maxmind"

        expect(page.all(".svc-env").map(&:text)).to eq(%w[MAXMIND_ACCOUNT_ID MAXMIND_LICENSE_KEY])
        expect(hints(".settings-side")).to include(hint("components.services.detail.environment"))
      end
    end

    describe "the detail panel" do
      it "opens a picked service and closes it from its row", :aggregate_failures do
        get "/admin/settings/services?selected=maxmind"

        expect(page).to have_css(".settings-side .card-title", text: "MaxMind")
        expect(page).to have_css(".settings-side li", text: "Countries in Analytics")
        expect(page).to have_css(".settings-side .svc-line", text: "Country database refresh")
        expect(row("MaxMind")).to have_css("a.li-title[aria-current='true'][href='/admin/settings/services#services']")
      end

      it "shows each environment key as set or missing and never its value", :aggregate_failures do
        allow(Hanami.app["settings"]).to receive(:maxmind).and_return(account_id: "acct-31337", license_key: nil)
        get "/admin/settings/services?selected=maxmind"

        expect(page.find(".svc-line", text: "MAXMIND_ACCOUNT_ID")).to have_css(".pill", text: "set")
        expect(page.find(".svc-line", text: "MAXMIND_LICENSE_KEY")).to have_css(".pill", text: "missing")
        expect(last_response.body).not_to include("acct-31337")
      end

      it "opens a connected account by its id with the scopes it holds", :aggregate_failures do
        connection = add_connection("mastodon", "1", "@aaron", host: "ruby.social", scopes: ["write:statuses"])
        get "/admin/settings/services?selected=#{connection.id}"

        expect(page.find(".svc-line", text: "Post on your behalf")).to have_css(".pill", text: "granted")
        expect(page.find(".svc-line", text: "Look up accounts")).to have_css(".pill", text: "not granted")
      end

      it "sends Bridgy to the webmention toggle" do
        get "/admin/settings/services?selected=bridgy"

        expect(page).to have_link("webmentions →", href: "/admin/settings/socials#webmentions")
      end
    end
  end

  describe "connecting Linear" do
    before { sign_in_to_admin }

    it "offers a key form from the picker", :aggregate_failures do
      get "/admin/settings/services"
      expect(page).to have_css(pick("linear"), visible: :all)

      get "/admin/settings/services?connect=linear"
      expect(page).to have_css(".settings-side form[action='/admin/services/linear#services'] input[type='password']")
    end

    it "draws Linear's own mark on its tile", :aggregate_failures do
      get "/admin/settings/services"
      tile = page.find("#{pick('linear')} .svc-tile", visible: :all)

      expect(tile).to have_css("i.linear-mark[aria-hidden='true']", visible: :all)
      expect(tile).to have_no_css("i.fa-circle-nodes", visible: :all)
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
        expect(last_response.location).to end_with("/admin/settings/services?selected=#{connections.first.id}#services")
        follow_redirect!
        expect(toast).to include("Linear connected as ROOT")
        expect(page).to have_css(".settings-side .svc-account", text: "ROOT")
      end
    end

    it "says it checks the key with Linear before it keeps it, encrypted" do
      stub_linear(LinearGraphQL::WORKSPACE_QUERY, linear_errors("AUTHENTICATION_ERROR", "Authentication required"))
      connect(api_key: "lin_api_bad")

      expect([connections, page.all(".settings-side .hint").map(&:text)])
        .to match([[], include(Admin::Slice["i18n"].t("ui.components.services.connect.hint", name: "Linear"))])
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
        Tasks::Jobs::SyncIssues.new.perform("linear")
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
      get "/admin/settings/services?selected=#{connection.id}"

      expect(page).to have_css("form[action='/admin/services/#{connection.id}/test']")
      expect(page).to have_link("Add another account", href: "/admin/settings/services?connect=linear#services")
      expect(page).to have_css("form[action='/admin/services/#{connection.id}/disconnect'][data-confirm]")
    end

    it "opens the Linear dashboard in a new tab with no opener or referrer" do
      get "/admin/settings/services?selected=#{connection.id}"

      expect(page).to have_css(
        "a[href='https://linear.app/settings/account/security'][target='_blank'][rel='noopener noreferrer']",
      )
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

      expect(last_response.location).to end_with("/admin/settings/services#services")
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
      expect(JSON.parse(Services::Encryptor.new.open(raw))).to eq("api_key" => "lin_api_secret")
    end

    it "reads them back through the lookup" do
      add_connection("linear", "ws-1", "ROOT workspace")

      expect(Services::Slice["repos.connection_queries"].for(:linear).map(&:credentials))
        .to eq([{ api_key: "lin_api_secret" }])
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Admin LinkedIn connection", type: :request do
  before { sign_in_to_admin }

  def authorize_query = Rack::Utils.parse_query(URI(last_response.location).query)

  def callback(**) = get("/admin/auth/linkedin/callback", **)

  def connection = connections.first

  def connections = Services::Slice["repos.connection_queries"].for(:linkedin)

  def grant(sub, name, access_token: "li-#{sub}")
    stub_request(:post, token_url).to_return(
      **json_response(access_token:, expires_in: lifetime, scope: "email,openid,profile,w_member_social"),
    )
    stub_request(:get, userinfo_url)
      .with(headers: { "Authorization" => "Bearer #{access_token}" })
      .to_return(**json_response(sub:, name:))
  end

  def lifetime = 5_184_000

  def page = Capybara.string(last_response.body)

  def pickable = page.all("#connect-service .svc-pick .svc-line-name", visible: :all).map(&:text)

  def start_connect
    post "/admin/services/linkedin/connect", _csrf_token: admin_csrf_token
    authorize_query.fetch("state")
  end

  def token_url = "https://www.linkedin.com/oauth/v2/accessToken"

  def userinfo_url = "https://api.linkedin.com/v2/userinfo"

  describe "without an app in settings" do
    before { set_up_linkedin_client({}) }

    it "lists LinkedIn as not set up, names the settings and leaves it out of the picker", :aggregate_failures do
      get "/admin/services", selected: "linkedin"

      expect(page.find(".svc-group", text: "Social")).to have_css(".li", text: /LinkedIn.*not set up/)
      expect(page.find(".svc-line", text: "LINKEDIN_CLIENT_ID")).to have_css(".pill", text: "missing")
      expect(pickable).not_to include("LinkedIn")
    end

    it "refuses to start a connect", :aggregate_failures do
      post "/admin/services/linkedin/connect", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(toast).to include("LinkedIn sign-in isn't set up")
      expect(connection).to be_nil
    end

    it "keeps LinkedIn off the post form even with an account held" do
      connect_linkedin
      get "/admin/posts/new"

      expect(page.find(".compose-target.linkedin input", visible: :all)).to be_disabled
    end
  end

  describe "with an app in settings" do
    before { set_up_linkedin_client }

    it "offers LinkedIn in the picker" do
      get "/admin/services"

      expect(pickable).to include("LinkedIn")
    end

    it "sends me to LinkedIn for my name and the right to post, back to the LinkedIn callback", :aggregate_failures do
      start_connect

      expect(last_response.location).to start_with("https://www.linkedin.com/oauth/v2/authorization?")
      expect(authorize_query).to include("client_id" => "li-id", "scope" => "openid profile w_member_social")
      expect(authorize_query.fetch("redirect_uri")).to end_with("/admin/auth/linkedin/callback")
    end

    describe "when LinkedIn grants access" do
      before do
        grant("member-ada", "Ada Lovelace")
        callback(code: "code", state: start_connect)
        follow_redirect!
      end

      it "keys the account on the member id and names it", :aggregate_failures do
        expect(connection).to have_attributes(account_id: "member-ada", label: "Ada Lovelace")
        expect(connection.scopes).to eq(%w[email openid profile w_member_social])
        expect(toast).to include("LinkedIn connected as Ada Lovelace")
      end

      it "stores the token and when it expires", :aggregate_failures do
        expect(connection.credentials)
          .to match(access_token: "li-member-ada", expires_at: be_within(60).of(Time.now.to_i + lifetime))
        expect(connection.lapses_at).to be_within(60).of(Time.now + lifetime)
      end

      it "sends the exchange with the app's secret" do
        sent = hash_including("client_id" => "li-id", "client_secret" => "li-secret", "code" => "code")

        expect(a_request(:post, token_url).with(body: sent)).to have_been_made
      end
    end

    describe "connecting a second profile" do
      before do
        grant("member-ada", "Ada Lovelace")
        callback(code: "code", state: start_connect)
        grant("member-grace", "Grace Hopper")
        callback(code: "code", state: start_connect)
      end

      it "shows both profiles on the services page", :aggregate_failures do
        get "/admin/services"

        expect(connections.map(&:account_id)).to contain_exactly("member-ada", "member-grace")
        expect(page.find(".svc-group", text: "Social")).to have_css(".li", text: "Ada Lovelace")
        expect(page.find(".svc-group", text: "Social")).to have_css(".li", text: "Grace Hopper")
      end

      it "lists both in the composer beside the other networks' accounts", :aggregate_failures do
        connect_social_networks
        get "/admin/social"

        handles = page.all(".compose-account-group.linkedin .compose-account-handle", visible: :all).map(&:text)
        expect(handles).to contain_exactly("Ada Lovelace", "Grace Hopper")
        expect(page).to have_css(".compose-account-group.mastodon", visible: :all)
      end

      it "offers LinkedIn as a syndication target on the post form" do
        get "/admin/posts/new"

        expect(page.find(".compose-target.linkedin input", visible: :all)).not_to be_disabled
      end
    end

    describe "a connection close to lapsing" do
      def row = page.find(".svc-group", text: "Social").find(".li", text: "Ada Lovelace")

      it "marks it on the services page and offers a reconnect", :aggregate_failures do
        held = connect_linkedin(lapses_at: Time.now + (3 * 86_400))
        get "/admin/services", selected: held.id

        expect(row).to have_css(".pill", text: "lapses soon")
        expect(page).to have_text("LinkedIn stops taking the site's token on")
        expect(page).to have_button("Reconnect")
      end

      it "marks it lapsed once the expiry passes", :aggregate_failures do
        held = connect_linkedin(lapses_at: Time.now - 60)
        get "/admin/services", selected: held.id

        expect(row).to have_css(".pill", text: "lapsed")
        expect(page).to have_text("LinkedIn no longer takes the site's token")
      end

      it "marks a connection lapsing late on the last day of the window on both pages", :aggregate_failures do
        last = Blog::TimeZone.today + 7
        connect_linkedin(lapses_at: Blog::TimeZone.local_time(last.year, last.month, last.day, 23, 59))
        get "/admin/services"

        expect(row).to have_css(".pill", text: "lapses soon")
        expect(Activity::Slice["repos.attention_queries"].stalled.map(&:kind)).to include("lapsing")
      end

      it "leaves a connection more than a week out marked connected" do
        out = Blog::TimeZone.today + 8
        connect_linkedin(lapses_at: Blog::TimeZone.local_time(out.year, out.month, out.day))
        get "/admin/services"

        expect(row).to have_css(".pill", text: "connected")
      end
    end

    describe "reconnecting a held profile" do
      let!(:held) { connect_linkedin(account_id: "member-ada", lapses_at: Time.now + 86_400) }
      let!(:delivery) do
        social_post = Social::Slice["repos.social_post_mutations"]
                      .create_with_parts(parts: %w[sent], targets: %w[linkedin], status: "posted", posted_at: Time.now)
        create(:social_post_delivery, :linkedin, social_post_id: social_post.id, connection_id: held.id)
      end

      before do
        grant("member-ada", "Ada Lovelace", access_token: "li-fresh")
        callback(code: "code", state: start_connect)
      end

      it "replaces the token on the same connection", :aggregate_failures do
        expect(connections.map(&:id)).to eq([held.id])
        expect(connection.credentials[:access_token]).to eq("li-fresh")
        expect(connection.lapses_at).to be_within(60).of(Time.now + lifetime)
      end

      it "clears the warning on the services page and the attention list", :aggregate_failures do
        get "/admin/services"

        expect(page.find(".svc-group", text: "Social").find(".li", text: "Ada Lovelace"))
          .to have_css(".pill", text: "connected")
        expect(Activity::Slice["repos.attention_queries"].stalled.map(&:kind)).not_to include("lapsing")
      end

      it "keeps the connection's past deliveries" do
        kept = Social::Slice["relations.social_post_deliveries"].where(id: delivery.id).one

        expect(kept).to include(connection_id: held.id)
      end
    end

    it "saves nothing when I decline on LinkedIn", :aggregate_failures do
      callback(error: "user_cancelled_authorize", state: start_connect)
      follow_redirect!

      expect(connection).to be_nil
      expect(toast).to include("LinkedIn didn't grant access")
    end

    it "saves nothing when LinkedIn fails the exchange", :aggregate_failures do
      stub_request(:post, token_url).to_return(**json_response(status: 400, error: "invalid_request"))
      callback(code: "code", state: start_connect)
      follow_redirect!

      expect(connection).to be_nil
      expect(toast).to include("LinkedIn didn't answer")
    end

    it "saves nothing when LinkedIn answers the member with a page that isn't JSON" do
      stub_request(:post, token_url).to_return(**json_response(access_token: "li-token", expires_in: lifetime))
      stub_request(:get, userinfo_url).to_return(body: "<html>", headers: { "Content-Type" => "application/json" })
      callback(code: "code", state: start_connect)

      expect(connection).to be_nil
    end

    it "refuses a state it never sent" do
      start_connect
      callback(code: "code", state: "forged")

      expect(connection).to be_nil
    end

    describe "disconnecting a profile" do
      let(:revoke) do
        stub_request(:post, "https://www.linkedin.com/oauth/v2/revoke")
          .with(body: { client_id: "li-id", client_secret: "li-secret", token: "li-token" })
      end
      let!(:held) { connect_linkedin }
      let!(:delivery) do
        social_post = Social::Slice["repos.social_post_mutations"]
                      .create_with_parts(parts: %w[sent], targets: %w[linkedin], status: "posted", posted_at: Time.now)
        create(:social_post_delivery, :linkedin, social_post_id: social_post.id, connection_id: held.id)
      end

      before do
        revoke
        post "/admin/services/#{held.id}/disconnect", _csrf_token: admin_csrf_token
      end

      it "revokes its token on LinkedIn and drops it", :aggregate_failures do
        expect(revoke).to have_been_made.once
        expect(connection).to be_nil
      end

      it "keeps its past deliveries" do
        kept = Social::Slice["relations.social_post_deliveries"].where(id: delivery.id).one

        expect(kept).to include(network: "linkedin", connection_id: nil)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Admin Bluesky connection", type: :request do
  let(:sign_in_url) { bluesky_url("com.atproto.server.createSession") }

  before { sign_in_to_admin }

  def connect(**connection) = post("/admin/services/bluesky", connection:, _csrf_token: admin_csrf_token)

  def connections = Services::Slice["repos.connection_queries"].for(:bluesky)

  def page = Capybara.string(last_response.body)

  def refuse_sign_in
    stub_request(:post, sign_in_url).to_return(**json_response(
      status: 401, error: "AuthenticationRequired", message: "Invalid identifier or password",
    ))
  end

  def toast = page.find("[data-toast]").text

  it "offers a handle and app password form", :aggregate_failures do
    get "/admin/services?connect=bluesky"

    form = page.find(".settings-side form[action='/admin/services/bluesky']")
    expect(form).to have_field("connection[handle]", type: "text")
    expect(form).to have_field("connection[app_password]", type: "password")
  end

  describe "with a pair Bluesky accepts" do
    before do
      stub_bluesky_session(handle: "aaron.bsky.social")
      connect(handle: " aaron.bsky.social ", app_password: "abcd-efgh")
    end

    it "signs in with the pair it was given" do
      expect(a_request(:post, sign_in_url).with(body: { identifier: "aaron.bsky.social", password: "abcd-efgh" }))
        .to have_been_made
    end

    it "saves the account under its DID and handle with the pair sealed" do
      saved = { app_password: "abcd-efgh", handle: "aaron.bsky.social" }

      expect(connections.map { [it.account_id, it.label, it.credentials] })
        .to eq([[SocialNetworks::BLUESKY_DID, "@aaron.bsky.social", saved]])
    end

    it "opens the new row with a toast" do
      follow_redirect!

      expect(toast).to include("Bluesky connected as @aaron.bsky.social")
    end
  end

  it "saves nothing for a pair Bluesky refuses and says why", :aggregate_failures do
    refuse_sign_in
    connect(handle: "aaron.bsky.social", app_password: "wrong")

    expect(last_response.status).to eq(422)
    expect(page).to have_css(".settings-side .field-error", text: "Invalid identifier or password")
    expect(connections).to be_empty
  end

  it "saves nothing for a blank field and names it", :aggregate_failures do
    connect(handle: "aaron.bsky.social", app_password: " ")

    expect(page).to have_css(".field-error", text: "Paste an app password first")
    expect(a_request(:post, sign_in_url)).not_to have_been_made
    expect(connections).to be_empty
  end

  describe "a connected account" do
    let(:connection) { connect_bluesky }

    it "offers a test, another account and a disconnect", :aggregate_failures do
      get "/admin/services?selected=#{connection.id}"

      expect(page).to have_css("form[action='/admin/services/#{connection.id}/test']")
      expect(page).to have_link("Add another account", href: "/admin/services?connect=bluesky")
      expect(page).to have_css("form[action='/admin/services/#{connection.id}/disconnect'][data-confirm]")
    end

    it "reports that Bluesky answers a test" do
      stub_bluesky_session
      post "/admin/services/#{connection.id}/test", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(toast).to include("Bluesky answered")
    end

    it "reports that Bluesky refuses a test" do
      refuse_sign_in
      post "/admin/services/#{connection.id}/test", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(toast).to include("Bluesky isn't answering", "Invalid identifier or password")
    end

    it "deletes the row on disconnect" do
      post "/admin/services/#{connection.id}/disconnect", _csrf_token: admin_csrf_token

      expect(connections).to be_empty
    end
  end

  describe "the networks" do
    let(:bluesky) { Social::Slice["networks.all"].fetch(Blog::Types::NetworkName["bluesky"]) }

    it "reads a newly connected account with no restart", :aggregate_failures do
      expect(bluesky).not_to be_configured

      connect_bluesky
      expect(bluesky).to be_configured
    end

    it "stops posting once the account disconnects" do
      connection = connect_bluesky
      post "/admin/services/#{connection.id}/disconnect", _csrf_token: admin_csrf_token

      expect(bluesky).not_to be_configured
    end
  end
end

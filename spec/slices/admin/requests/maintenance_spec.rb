# frozen_string_literal: true

RSpec.describe "Admin maintenance mode", type: :request do
  let(:app) { Rack::Builder.parse_file(Hanami.app.root.join(".config/config.ru").to_s) }
  let(:flag) { File.join(Dir.tmpdir, "maintenance-#{SecureRandom.hex}") }
  let(:page) { Capybara.string(last_response.body) }
  let(:cookie_header) { Array(last_response.headers["Set-Cookie"]).join("\n") }

  def activate = admin_post("/admin/maintenance")

  before do
    allow(Hanami).to receive(:boot)
    allow(Hanami.app.settings).to receive(:maintenance).and_return(flag_path: flag)
    sign_in_to_admin
  end

  after { FileUtils.rm_f(flag) }

  it "offers the button on the Settings page, behind the confirm question" do
    get "/admin/settings/security"

    button = page.find(".page-head-actions form[action='/admin/maintenance']", text: "Activate maintenance mode")

    expect(button["data-confirm"]).to eq(admin_t("ui.components.settings_head.maintenance.confirm"))
  end

  describe "activating it" do
    before { activate }

    it "creates the flag file" do
      expect(File).to exist(flag)
    end

    it "signs the owner cookie with the time the flag was written" do
      pass = Blog::Maintenance.pass(Hanami.app.settings.app_secret, File.mtime(flag))

      expect(cookie_header).to include("#{Blog::Maintenance::COOKIE}=#{Rack::Utils.escape(pass)}")
    end

    it "keeps the cookie from scripts and other sites, across the whole site", :aggregate_failures do
      cookie = cookie_header.lines.find { it.start_with?(Blog::Maintenance::COOKIE) }

      expect(cookie).to match(/; httponly/i)
      expect(cookie).to match(/; samesite=strict/i)
      expect(cookie).to match(%r{; path=/(;|\z)}i)
    end

    it "sends me to Settings, which answers the maintenance page", :aggregate_failures do
      expect(last_response.location).to eq("/admin/settings/security")

      follow_redirect!

      expect(last_response.status).to eq(503)
      expect(page).to have_css("h1", text: "Down for maintenance")
    end
  end

  describe "turning it off from the cookie it set" do
    before do
      activate
      post "/maintenance/deactivate"
    end

    it "removes the flag file and the cookie", :aggregate_failures do
      expect(File).not_to exist(flag)
      expect(rack_mock_session.cookie_jar[Blog::Maintenance::COOKIE].to_s).to be_empty
    end

    it "lands on Settings, back up", :aggregate_failures do
      follow_redirect!

      expect(last_request.path).to eq("/admin/settings/security")
      expect(last_response.status).to eq(200)
    end
  end

  describe "when the flag cannot be written" do
    let(:flag) { File.join(Dir.tmpdir, "missing-#{SecureRandom.hex}", "maintenance") }

    before do
      activate
      follow_redirect!
    end

    it "sets no cookie" do
      expect(rack_mock_session.cookie_jar[Blog::Maintenance::COOKIE]).to be_nil
    end

    it "keeps the site up and says why", :aggregate_failures do
      expect(last_response.status).to eq(200)
      expect(page.find("[data-toast] .toast", visible: :all).text(:all))
        .to eq(admin_t("settings_page.toasts.maintenance_unwritable"))
    end
  end

  it "changes nothing without the form's token" do
    post "/admin/maintenance"

    expect(File).not_to exist(flag)
  end
end

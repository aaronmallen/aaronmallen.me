# frozen_string_literal: true

RSpec.describe "Admin maintenance mode", type: :feature do
  let(:flag) { File.join(Dir.tmpdir, "maintenance-#{SecureRandom.hex}") }
  let(:question) { admin_t("ui.components.settings_head.maintenance.confirm") }

  def activated
    Timeout.timeout(5) { sleep 0.05 until request_gate.answered("/admin/maintenance") >= 1 }
    page.document.synchronize { raise Capybara::ExpectationNotMet if kept_page? }
  end

  def landed = page.assert_no_selector("dialog[data-palette][open]")

  def open_palette = page.driver.browser.keyboard.type([:meta, "/"])

  def query = find("[data-palette-query]")

  before do
    allow(Hanami.app.settings).to receive(:maintenance).and_return(flag_path: flag)
    sign_in_to_admin
    visit "/admin/settings/security"
    keep_page
  end

  after { FileUtils.rm_f(flag) }

  describe "the Settings button" do
    it "asks the confirm question first", :aggregate_failures do
      message = confirm_no { click_button "Activate maintenance mode" }

      expect(message).to eq(question)
      expect(File).not_to exist(flag)
    end

    it "takes the site down once I confirm", :aggregate_failures do
      confirm_yes { click_button "Activate maintenance mode" }
      activated

      expect(File).to exist(flag)
      expect(cookie(Blog::Maintenance::COOKIE)).not_to be_nil
    end
  end

  describe "the palette command" do
    before do
      open_palette
      query.send_keys(*"maintenance".chars, :enter)
    end

    it "asks the confirm question first", :aggregate_failures do
      expect(page).to have_css("#command-palette-activate-maintenance .pal-r-label", text: question)
      expect(File).not_to exist(flag)
    end

    it "changes nothing when I close it", :aggregate_failures do
      query.send_keys(:escape)
      landed

      expect(File).not_to exist(flag)
      expect(cookie(Blog::Maintenance::COOKIE)).to be_nil
    end

    it "asks again once I type", :aggregate_failures do
      query.send_keys(:backspace)

      expect(page).to have_css("#command-palette-activate-maintenance .pal-r-label", text: "Activate maintenance mode")
      expect(File).not_to exist(flag)
    end

    it "takes the site down once I confirm", :aggregate_failures do
      expect(page).to have_css("#command-palette-activate-maintenance .pal-r-label", text: question)
      query.send_keys(:enter)
      activated

      expect(File).to exist(flag)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Theme picker", type: :feature do
  def choose_theme(label)
    find(".settings-menu-toggle").click
    click_button label
  end

  def color_scheme = evaluate_script("getComputedStyle(document.documentElement).colorScheme")

  { "Light" => %w[light dark], "Dark" => %w[dark light] }.each do |label, (theme, system_theme)|
    describe "choosing #{label} while the system is #{system_theme}" do
      before do
        visit "/"
        emulate_color_scheme(system_theme)
        choose_theme(label)
      end

      it "sets the theme on the page" do
        expect(page).to have_css("html[data-site-theme='#{theme}']")
      end

      it "draws the page in the #{theme} scheme" do
        expect(color_scheme).to eq(theme)
      end

      it "presses only the #{label} button" do
        expect(page).to have_css("[data-theme-choice][aria-pressed='true']", count: 1, text: label)
      end

      it "saves the theme in a cookie" do
        expect(cookie("site_theme")).to eq(theme)
      end

      it "keeps the cookie for a year on every path, sent on links from other sites", :aggregate_failures do
        saved = page.driver.cookies["site_theme"]

        expect(saved.path).to eq("/")
        expect(saved.same_site).to eq("Lax")
        expect(saved.expires).to be_within(60).of(Time.now + (60 * 60 * 24 * 365))
      end

      it "keeps the theme on the next page", :aggregate_failures do
        visit "/writing"

        expect(page).to have_css("html[data-site-theme='#{theme}']")
        expect(color_scheme).to eq(theme)
      end
    end
  end

  describe "in a browser without the Cookie Store API" do
    before do
      visit "/"
      execute_script("Object.defineProperty(window, 'cookieStore', { value: undefined })")
      choose_theme("Dark")
    end

    it "still sets the theme on the page", :aggregate_failures do
      expect(page).to have_css("html[data-site-theme='dark']")
      expect(page).to have_css("[data-theme-choice][aria-pressed='true']", count: 1, text: "Dark")
    end

    it "saves no cookie" do
      expect(cookie("site_theme")).to be_nil
    end
  end
end

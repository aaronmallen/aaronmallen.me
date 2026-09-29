# frozen_string_literal: true

RSpec.describe "Admin today pools", type: :feature do
  before do
    create(:task, title: "Email the accountant")
    create(:task, :someday, title: "Learn Elixir")
    sign_in_to_admin
    visit "/admin"
  end

  def panel = find(".sprint-panel")

  def scroll_down
    execute_script(<<~JS)
      document.querySelector("[data-pools] .seg").scrollIntoView({ block: "center" });
      window.poolsLoaded = true;
      window.poolsScroll = window.scrollY;
    JS
  end

  def switch_to_someday = panel.find(".seg-option", exact_text: "someday · 1").click

  describe "switching the pool to someday" do
    before do
      page.driver.resize(1024, 400)
      scroll_down
      switch_to_someday
    end

    it "offers what is in someday", :aggregate_failures do
      expect(panel).to have_css(".li-title", text: "Learn Elixir")
      expect(panel).to have_no_css(".li-title", text: "Email the accountant")
    end

    it "shows someday in the address" do
      expect(page).to have_current_path("/admin?pool=someday")
    end

    it "switches without loading the page", :aggregate_failures do
      expect(panel).to have_css(".li-title", text: "Learn Elixir")
      expect(evaluate_script("window.poolsLoaded")).to be(true)
      expect(evaluate_script("window.scrollY > 0 && window.scrollY === window.poolsScroll")).to be(true)
    end

    it "opens someday again on reload" do
      refresh

      expect(panel).to have_css(".li-title", text: "Learn Elixir")
    end

    it "returns to someday after pulling from it" do
      panel.find(".li", text: "Learn Elixir").click_button("Pull in")

      expect(page).to have_current_path("/admin?pool=someday")
    end
  end

  describe "switching the pool with scripts off" do
    before do
      page.driver.browser.page.disable_javascript
      visit "/admin"
      switch_to_someday
    end

    after { page.driver.browser.page.command("Emulation.setScriptExecutionDisabled", value: false) }

    it "loads someday from the link", :aggregate_failures do
      expect(page).to have_current_path("/admin?pool=someday")
      expect(panel).to have_css(".li-title", text: "Learn Elixir")
    end
  end
end

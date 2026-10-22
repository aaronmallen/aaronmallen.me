# frozen_string_literal: true

RSpec.describe "Admin menu switcher", type: :feature do
  def expanded
    node = find(".switcher").native.node.description["backendNodeId"]
    tree = page.driver.browser.page.command("Accessibility.getPartialAXTree", backendNodeId: node)
    tree["nodes"].first["properties"].find { it["name"] == "expanded" }&.dig("value", "value")
  end

  def open_switcher
    click_button(class: "switcher")
    find("#nav-switcher:popover-open")
  end

  def top_bar_height = evaluate_script("document.querySelector('.top-bar').getBoundingClientRect().height")

  def wordmark = find("a.wordmark").text.split.join

  before do
    create(:message)
    sign_in_to_admin
  end

  after { page.current_window.resize_to(1280, 800) }

  describe "at 860px" do
    before do
      page.current_window.resize_to(860, 800)
      visit "/admin"
    end

    it "shows the pills and hides the switcher", :aggregate_failures do
      expect(page).to have_css(".pill-nav")
      expect(page).to have_no_css(".switcher")
    end
  end

  describe "below 860px" do
    before do
      page.current_window.resize_to(859, 800)
      visit "/admin/inbox"
    end

    it "shows the switcher in place of the pills on one 4.5rem row", :aggregate_failures do
      expect(page).to have_css(".switcher", text: "Inbox")
      expect(page).to have_no_css(".pill-nav")
      expect(top_bar_height).to eq(72)
    end

    it "names the screen and flags the waiting mail on the button", :aggregate_failures do
      expect(page).to have_css(".switcher[aria-label='Navigate. Current: Inbox, waiting'] .pill-nav-dot")
      expect(page).to have_css(".switcher-screen", text: "waiting")
    end

    it "reports whether the panel is open", :aggregate_failures do
      expect(expanded).to be(false)
      open_switcher
      expect(expanded).to be(true)
    end

    it "closes on Escape" do
      open_switcher
      find("body").send_keys(:escape)

      expect(page).to have_no_css("#nav-switcher:popover-open")
    end

    it "closes on a click outside" do
      open_switcher
      page.driver.browser.mouse.click(x: 10, y: 790)

      expect(page).to have_no_css("#nav-switcher:popover-open")
    end

    it "opens the chosen screen and closes", :aggregate_failures do
      open_switcher
      within("#nav-switcher") { click_link "mail" }

      expect(page).to have_css(".switcher[aria-label='Navigate. Current: Inbox, mail']")
      expect(page).to have_no_css("#nav-switcher:popover-open")
    end

    it "keeps working after a live update redraws the top bar" do
      create(:message, subject: "Hello there")
      find("main", text: "Hello there")
      open_switcher
      within("#nav-switcher") { click_link "mail" }

      expect(page).to have_css(".switcher-screen", text: "mail")
    end
  end

  describe "at 480px" do
    def width(selector) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().width")

    before do
      page.current_window.resize_to(480, 844)
      visit "/admin/inbox"
    end

    it "folds search into a 44px icon button", :aggregate_failures do
      expect(width(".top-bar-search")).to eq(44)
      expect(page).to have_no_css(".top-bar-search-label")
      expect(page).to have_no_css(".top-bar-search-key")
    end

    it "hides the screen label on the switcher", :aggregate_failures do
      expect(page).to have_css(".switcher", text: "Inbox")
      expect(page).to have_no_css(".switcher-screen")
    end

    it "shrinks the wordmark and spells the whole name", :aggregate_failures do
      expect(evaluate_script("getComputedStyle(document.querySelector('a.wordmark')).fontSize")).to eq("15px")
      expect(wordmark).to eq("AARON/ALLEN")
    end
  end

  describe "at 375px" do
    def space_above(heading, link)
      evaluate_script(<<~JS)
        (() => {
          const panel = document.querySelector("#nav-switcher")
          const top = [...panel.querySelectorAll(".switcher-heading")].find(it => it.textContent.trim() === "#{heading}")
          const row = [...panel.querySelectorAll(".switcher-row")].find(it => it.textContent.trim() === "#{link}")
          return top.getBoundingClientRect().top - row.getBoundingClientRect().bottom
        })()
      JS
    end

    before do
      page.current_window.resize_to(375, 800)
      visit "/admin"
      open_switcher
    end

    it "starts Tasks right under today, with the gap between any two groups" do
      expect(space_above("Tasks", "today")).to eq(space_above("Publish", "projects"))
    end
  end

  describe "at 400px" do
    before do
      page.current_window.resize_to(400, 844)
      visit "/admin"
    end

    it "cuts the wordmark to its initials" do
      expect(wordmark).to eq("A/A")
    end
  end

  describe "with scripts off" do
    before do
      page.current_window.resize_to(390, 844)
      page.driver.browser.page.command("Emulation.setScriptExecutionDisabled", value: true)
      visit "/admin"
    end

    after { page.driver.browser.page.command("Emulation.setScriptExecutionDisabled", value: false) }

    it "opens the panel and follows a row" do
      open_switcher
      click_link "tasks"

      expect(page).to have_current_path("/admin/tasks")
    end
  end
end

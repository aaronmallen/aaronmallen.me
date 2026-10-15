# frozen_string_literal: true

RSpec.describe "The public header", type: :feature do
  def boxes
    evaluate_script(<<~JS)
      [...document.querySelectorAll('.site-header a:not(.skip-link), .site-header button')]
        .filter((el) => el.checkVisibility())
        .map((el) => ({ name: el.textContent.trim() || el.getAttribute('aria-label'), height: el.getBoundingClientRect().height }))
    JS
  end

  def nav_width = evaluate_script("document.querySelector('nav.main-nav').getBoundingClientRect().width")

  before { visit "/about" }

  it "fills the current page's pill and no other" do
    expect(all("nav.main-nav a[aria-current='page']").map(&:text)).to eq(%w[about])
  end

  it "shows no menu toggle" do
    expect(page).to have_no_css(".site-header button[aria-controls]:not(.settings-menu-toggle)", visible: :all)
  end

  it "shows one theme icon at a time" do
    expect(page).to have_css("[data-theme-toggle] i", count: 1)
  end

  it "flips the theme from the toggle", :aggregate_failures do
    theme = -> { evaluate_script("document.documentElement.dataset.siteTheme") }

    find("[data-theme-toggle]").click
    first = theme.call
    find("[data-theme-toggle]").click

    expect([first, theme.call]).to contain_exactly("light", "dark")
  end

  it "draws the theme a reader saved in the cookie past the content security policy", :aggregate_failures do
    emulate_color_scheme("light")
    page.driver.set_cookie(Blog::UI::Layouts::Application::THEME_COOKIE, "dark", domain: page.server.host, path: "/")
    visit "/about"

    expect(evaluate_script("document.documentElement.dataset.siteTheme")).to eq("dark")
    expect(evaluate_script("getComputedStyle(document.documentElement).colorScheme")).to eq("dark")
  end

  describe "on a phone" do
    before { page.current_window.resize_to(390, 844) }

    it "wraps the pills to a full-width row" do
      expect(nav_width).to be > 390 - 60
    end

    it "gives every control a 44px target" do
      expect(boxes.select { it["height"] < 44 }).to be_empty
    end
  end
end

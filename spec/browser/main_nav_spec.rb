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

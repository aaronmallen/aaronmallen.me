# frozen_string_literal: true

RSpec.describe "Admin today stat tiles", type: :feature do
  let(:tile_edges) { "[...document.querySelectorAll('.g-4 > .stat')].map(s => s.getBoundingClientRect().right)" }

  before do
    sign_in_to_admin
    visit "/admin"
    page.driver.resize(375, 800)
  end

  it "wraps the row to fit a phone without scrolling the page sideways", :aggregate_failures do
    expect(page).to have_css(".g-4 > .stat", count: 5)
    expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
    expect(evaluate_script(tile_edges)).to all(be <= 375)
  end
end

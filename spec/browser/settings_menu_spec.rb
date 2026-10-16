# frozen_string_literal: true

RSpec.describe "The settings menu", type: :feature do
  def open? = evaluate_script("document.getElementById('settings-menu').matches(':popover-open')")

  def toggle = find(".settings-menu-toggle")

  before do
    sign_in_to_admin
    visit "/about"
    toggle.click
  end

  it "opens from the gear" do
    expect(page).to have_css("#settings-menu", visible: :visible)
  end

  it "closes on Escape and hands focus back to the gear", :aggregate_failures do
    first("#settings-menu button[data-theme-choice]").send_keys(:escape)

    expect(page).to have_no_css("#settings-menu", visible: :visible)
    expect(evaluate_script("document.activeElement.classList.contains('settings-menu-toggle')")).to be(true)
  end

  it "closes on a click outside it" do
    find("main").click

    expect(open?).to be(false)
  end
end

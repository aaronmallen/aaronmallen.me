# frozen_string_literal: true

RSpec.describe "Admin task cadence picker", type: :feature do
  def pick(kind) = select(kind, from: "Repeats")

  def shown = all("main [data-cadence-for]:not([hidden]) :is(input, select):not([disabled])").map { it["name"] }

  before do
    sign_in_to_admin
    page.driver.resize(375, 800)
    visit "/admin/tasks/new"
  end

  it "shows only the fields a weekday each month needs" do
    pick "On a weekday each month"

    expect(shown).to eq(%w[task[recur][week] task[recur][weekday]])
  end

  it "shows only the fields every few weeks needs, under a label in weeks", :aggregate_failures do
    pick "Every few weeks"

    expect(shown).to eq(%w[task[recur][every] task[recur][weekday] task[recur][starts_on]])
    expect(page).to have_css("label[for='new-every']", text: /\Aweeks apart\z/i)
  end

  it "shows no field once it never repeats again" do
    pick "On a date each year"
    pick "Never"

    expect(shown).to be_empty
  end

  it "fits a phone without scrolling sideways" do
    pick "On a date each year"

    expect(evaluate_script("document.documentElement.scrollWidth > window.innerWidth")).to be(false)
  end
end

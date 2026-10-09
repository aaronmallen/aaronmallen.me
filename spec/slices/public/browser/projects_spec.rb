# frozen_string_literal: true

RSpec.describe "Project cards", type: :feature do
  def background(selector) = evaluate_script("getComputedStyle(document.querySelector('#{selector}')).backgroundColor")

  def columns = evaluate_script("getComputedStyle(document.querySelector('.pgrid')).gridTemplateColumns").split.length

  before do
    create(:project, name: "sai", tagline: "Terminal colors")
    create(:project, name: "gest", tagline: "Agent artifacts", url: nil)
  end

  { [390, 844] => 1, [800, 1000] => 2, [1600, 900] => 4 }.each do |(width, height), count|
    it "lays the grid out in #{count} columns at #{width}px" do
      page.current_window.resize_to(width, height)
      visit "/projects"

      expect(columns).to eq(count)
    end
  end

  it "fills an active card and leaves a past one unfilled", :aggregate_failures do
    create(:project, :archived, name: "domainic")
    visit "/projects"

    expect(background(".pc:not(.past)")).not_to eq("rgba(0, 0, 0, 0)")
    expect(background(".pc.past")).to eq("rgba(0, 0, 0, 0)")
  end
end

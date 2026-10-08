# frozen_string_literal: true

RSpec.describe "Admin analytics chart", type: :feature do
  let(:peak) { page.all(".chart-bar")[5] }

  def tips = page.all(".chart-tip", visible: :visible).map(&:text)

  before do
    create(:analytics_rollup, day: today - 1, views: 30, visitors: 20, read_seconds: 600)
    create(:analytics_rollup, day: today, views: 10, visitors: 5, read_seconds: 300)
    sign_in_to_admin
    visit "/admin/analytics?range=7"
  end

  it "hides every tooltip until a bar is hovered" do
    expect(page).to have_no_css(".chart-tip", visible: :visible)
  end

  describe "hovering a bar" do
    before { peak.hover }

    it "shows that day's figures" do
      expect(tips).to eq(["#{(today - 1).strftime('%b %-d')} · 30 views · 20 visitors"])
    end
  end

  describe "choosing a longer range" do
    before { find(".seg-option", text: "30d").click }

    it "submits the range" do
      expect(page).to have_current_path("/admin/analytics?range=30")
    end

    it "draws a bar for every day in it" do
      expect(page).to have_css(".chart-bar", count: 30)
    end
  end
end
